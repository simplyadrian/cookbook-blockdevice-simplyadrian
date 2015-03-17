if (node['blockdevice_nativex']['ec2'] || node['cloud']['provider'] == 'ec2') &&
    node['blockdevice_nativex']['restore'][:take_action]

  aws = Chef::EncryptedDataBagItem.load("credentials", "aws")
  include_recipe 'aws'
  ::Chef::Recipe.send(:include, Nativex::Blockdevice::Helpers)

  original_volume_ids = node['aws']['ebs_volume'].to_s.scan(/vol-[a-zA-Z0-9]+/)
  volume_timeout = node['blockdevice_nativex']['max_timeout']
  raid = node['blockdevice_nativex']['ebs']['raid']
  new_device = node['blockdevice_nativex']['restore'][:restore_to_new_device]
  device_to_restore = node['blockdevice_nativex']['restore'][:device_to_restore]
  node.set['blockdevice_nativex']['restore_session'] ||= {} unless
      node['blockdevice_nativex'].attribute?('restore_session')
  node.set['blockdevice_nativex']['restore_session'][:restored_devices] ||= [] unless
      node['blockdevice_nativex']['restore_session'].attribute?(:restored_devices)
  session_in_progress = false
  session_in_progress = node['blockdevice_nativex']['restore_session'][:in_progress] if
      node['blockdevice_nativex']['restore_session'].attribute?(:in_progress)
  device_ids = []
  device_id = nil
  glob_regex = nil
  snaps = {}
  final_volume_ids = {}

  # Do I know how to find this device?
  if raid
    raise 'Raid is unsupported in this release.' if true
    if device_to_restore =~ %r'/dev/md[0-9]*' || device_to_restore.blank?
      glob_regex = '/dev/md[0-9]*'
    else
      Chef::Log.error(
          'Invalid device specified. raid=true but you provided: '\
          "(#{device_to_restore}). I am looking for: '/dev/md[0-9]*'"
      )
    end
  elsif device_to_restore =~ %r'/dev/xvd[b-r]' || device_to_restore.blank?
    glob_regex = '/dev/xvd[b-r]'
  elsif device_to_restore =~ %r'/dev/sd[b-r]'
    glob_regex = '/dev/sd[b-r]'
  else
    Chef::Log.error(
        "I dont know about that device name or the device name is invalid. device_to_restore=#{device_to_restore}"\
        'I will still try to find it.'\
    )
    glob_regex = device_to_restore
  end

  # Find mounted devices
  Dir.glob(glob_regex).each do |dir| device_ids << dir end

  if device_ids.length == 1 || (device_ids.count > 1 && device_to_restore.blank?)
    device_id = device_ids[0]
    new_device = false if session_in_progress
  elsif device_ids.count > 1
    begin
      device_id = device_ids.index(device_to_restore)
    rescue
      Chef::Log.error("Invalid device specified (#{device_to_restore}). Found: #{device_ids.inspect}")
    end
  else
    Chef::Log.error("Device specified but no device found. You specified: #{device_to_restore}")
    device_id = device_to_restore
  end

  # Dont restore more than once for the same device, remove the deivce from restored_devices to restore it again
  unless node['blockdevice_nativex']['restore_session'].attribute?(:restored_devices) &&
      node['blockdevice_nativex']['restore_session'][:restored_devices].include?(device_id)

    # Match volume id to device
    if node['blockdevice_nativex']['restore_session'].attribute?(:in_progress) &&
        node['blockdevice_nativex']['restore_session'][:in_progress]
      snaps = node['blockdevice_nativex']['restore_session'][:snaps]
      final_volume_ids = node['blockdevice_nativex']['restore_session'][:final_volume_ids]
    else
      volume_attributes = node['aws']['ebs_volume']
      original_volume_ids.each do |original_volume_id|
        unless volume_exists(aws, original_volume_id)
          Chef::Log.info("volume_id=#{original_volume_id} does not exist. Please consider removing its node attribute.")
          next
        end
        if original_volume_ids.length > 1 || device_ids.length > 1
          possible_match = ''
          volume_attributes.each do |label,hash|
            if hash['volume_id'] == original_volume_id
              possible_match = hash['device']
              break
            end
          end
          if possible_match =~ /\/dev\/\w\w\w\w?/
            unless possible_match =~ /#{device_id}/
              Chef::Log.info("volume_id=#{original_volume_id} does not match device to restore.")
              next
            end
          else
            offset = device_offset(aws, original_volume_ids, device_ids)
            aws_device_name = get_volume_device(aws, original_volume_id)
            letter = aws_device_name[-1,1]
            letters = ('a'..'z').to_a
            offset.abs.times do
              offset > 0 ? letter.next! : letter = letters[letters.index(letter)-1]
            end
            unless letter == device_id[-1,1]
              Chef::Log.info("volume_id=#{original_volume_id} does not match device to restore.")
              next
            end
          end
        end
        snapshot_details =
            get_snapshot_id(aws, original_volume_id, node['blockdevice_nativex']['restore'][:restore_point])
        final_volume_ids[original_volume_id] = snapshot_details[:snapshot_id]
        snaps[snapshot_details[:snapshot_id]] = snapshot_details[:volume_size]
      end
      node.set['blockdevice_nativex']['restore_session'][:in_progress] = true
      node.set['blockdevice_nativex']['restore_session'][:snaps] = snaps
      node.set['blockdevice_nativex']['restore_session'][:final_volume_ids] = final_volume_ids
      node.save unless Chef::Config[:solo]
    end

    mount node['blockdevice_nativex']['dir'] do
      device device_id
      action :umount
    end

    # Detach old volume(s)
    final_volume_ids.each do |volume_id,snapshot_id|
      status = get_volume_status(aws, volume_id)
      blockdevice_nativex_volume volume_id do
        access_key_id aws['aws_access_key_id']
        secret_access_key aws['aws_secret_access_key']
        force true
        action :detach
        only_if { status[:status] == 'in-use' }
      end

      # Ensure volume does not remount on next run of blockdevice-nativex cookbook
      aws_resource_tag 'tag_data_volumes' do
        aws_access_key aws['aws_access_key_id']
        aws_secret_access_key aws['aws_secret_access_key']
        resource_id volume_id
        tags({:Remount => false})
        action [:add, :update]
      end
    end

    # Restore volume to new device to prevent having to stop the instance
    new_device_id = device_id
    if new_device
      new_device_id = device_id.next
      block_devices = `lsblk -n`
      while block_devices.include? new_device_id
        new_device_id = new_device_id.next
      end
    end

    # Create new ebs volume from snapshot and attach
    volume_size = snaps.values.first
    if raid
      snap_ids = []
      snaps.each do |id, size|
        snap_ids << id
      end

      # Create new RAID
      aws_ebs_raid 'restored_raid_volume' do
        aws_access_key aws['aws_access_key_id']
        aws_secret_access_key aws['aws_secret_access_key']
        disk_size volume_size
        disk_count node['blockdevice_nativex']['ebs']['count']
        level node['blockdevice_nativex']['ebs']['level']
        snapshots snap_ids
      end
    else
      snap_id = snaps.keys.first

      # Create new volume
      new_volume_precheck = get_volume_id(aws, snap_id)
      aws_ebs_volume 'restored_data_volume' do
        aws_access_key aws['aws_access_key_id']
        aws_secret_access_key aws['aws_secret_access_key']
        size volume_size
        snapshot_id snap_id
        most_recent_snapshot if node['blockdevice_nativex']['restore'][:restore_point] == :latest
        action :create
        not_if { new_volume_precheck[:status] == 'available' }
      end

      # Wait for new volume to create
      new_volume_id = get_volume_id(aws, snap_id)
      until new_volume_id[:id] != ''
        sleep 30
        new_volume_id = get_volume_id(aws, snap_id)
      end
      ruby_block 'waiting_for_volume_to_create' do
        block do
          wait_volume_lwrp = Chef::Resource::BlockdeviceNativexVolume.new(new_volume_id[:id], run_context)
          wait_volume_lwrp.access_key_id(aws['aws_access_key_id'])
          wait_volume_lwrp.secret_access_key(aws['aws_secret_access_key'])
          wait_volume_lwrp.wait_for('create')
          wait_volume_lwrp.timeout(volume_timeout)
          wait_volume_lwrp.run_action(:wait)
        end
        action :run
        not_if { new_volume_id[:status] == 'in-use' }
      end

      # Attach new volume
      new_volume_id = get_volume_id(aws, snap_id)
      ruby_block 'attach_restored_volume' do
        block do
          attach_volume_lwrp = Chef::Resource::BlockdeviceNativexVolume.new(new_volume_id[:id], run_context)
          attach_volume_lwrp.access_key_id(aws['aws_access_key_id'])
          attach_volume_lwrp.secret_access_key(aws['aws_secret_access_key'])
          attach_volume_lwrp.device(new_device_id)
          attach_volume_lwrp.run_action(:attach)
        end
        action :run
        only_if { new_volume_id[:status] == 'available' }
      end
    end

    # Wait for new volume to attach
    new_volume_id = get_volume_id(aws, snap_id)
    ruby_block 'waiting_for_volume_to_attach' do
      block do
        wait_volume_lwrp = Chef::Resource::BlockdeviceNativexVolume.new(new_volume_id[:id], run_context)
        wait_volume_lwrp.access_key_id(aws['aws_access_key_id'])
        wait_volume_lwrp.secret_access_key(aws['aws_secret_access_key'])
        wait_volume_lwrp.wait_for('attach')
        wait_volume_lwrp.timeout(volume_timeout)
        wait_volume_lwrp.run_action(:wait)
      end
      action :run
      not_if { new_volume_id[:status] == 'in-use' }
    end

    # Mount new volume
    mount node['blockdevice_nativex']['dir'] do
      device new_device_id
      options 'noatime'
      action :mount
    end

    # Clean up
    new_volume_id = get_volume_id(aws, snap_id)
    lsblk = `lsblk | grep "#{node['blockdevice_nativex']['dir']}"`
    if new_volume_id[:status] == 'in-use' && lsblk.include?(new_device_id.split('/').last)
      # Keep track of restored volumes
      node.set['aws']['ebs_volume']['data_volume']['volume_id'] = new_volume_id[:id]
      node.set['blockdevice_nativex']['restore_session'][:restored_devices] = device_id
      node.set['blockdevice_nativex']['restore_session'][:in_progress] = false
      node.save unless Chef::Config[:solo]

      # Tag old volume for deletion
      time = Time.now + (node['blockdevice_nativex']['restore'][:destroy_volumes_after]*60*60)
      aws_resource_tag 'tag_data_volumes' do
        aws_access_key aws['aws_access_key_id']
        aws_secret_access_key aws['aws_secret_access_key']
        resource_id original_volume_ids #can be a array
        tags({:Destroy => true,
              :DestructionTime => time.inspect})
        action [:add, :update]
      end

      # Delete old volumes if they are ready for deletion
      original_volume_ids.each do |original_volume_id|
        blockdevice_nativex_volume original_volume_id do
          access_key_id aws['aws_access_key_id']
          secret_access_key aws['aws_secret_access_key']
          retention_check true
          action :delete
        end
      end
    end
  end
end
