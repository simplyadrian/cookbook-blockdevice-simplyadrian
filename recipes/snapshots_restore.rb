if (node['blockdevice_nativex']['ec2'] || node['cloud']['provider'] == 'ec2') &&
    node['blockdevice_nativex']['restore'][:take_action]

  aws = Chef::EncryptedDataBagItem.load("credentials", "aws")
  include_recipe 'aws'
  ::Chef::Recipe.send(:include, Nativex::Blockdevice::Helpers)

  original_volume_ids = node['aws']['ebs_volume'].to_s.scan(/vol-[a-zA-Z0-9]+/)

  raid = node['blockdevice_nativex']['ebs']['raid']
  device_to_restore = node['blockdevice_nativex']['restore'][:device_to_restore]
  valid_aws_device_names = []
  snaps = []
  device_ids = []
  device_id = nil
  glob_regex = nil
  final_volume_ids = {}

  # Do I know how to find this device?
  if raid
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

  # Dont run twice for the same device
  File.new('/root/snapshots_restore', 'w+') unless File.exist?('/root/snapshots_restore')
  unless File.readlines('/root/snapshots_restore').grep(/#{device_id}/).size > 0

    # Match volume id to device
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
      final_volume_ids[original_volume_id] =
          get_snapshot_id(aws, original_volume_id, node['blockdevice_nativex']['restore'][:restore_point])[:snapshot_id]
      snaps << get_snapshot_id(aws, original_volume_id, node['blockdevice_nativex']['restore'][:restore_point])
    end

    xfs_filesystem('freeze')

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
    end

    # Restore volume to new device to prevent having to stop the instance
    new_device_id = device_id.next
    block_devices = `lsblk -n`
    while block_devices.include? new_device_id
      new_device_id = new_device_id.next
    end
    new_device_id = device_id

    # Create new ebs volume from snapshot and attach
    volume_size = snaps.first.volume_size
    if raid
      snap_ids = []
      snaps.each do |s|
        snap_ids << s.snapshot_id
      end

      # Creat new RAID
      aws_ebs_raid 'restored_raid_volume' do
        aws_access_key aws['aws_access_key_id']
        aws_secret_access_key aws['aws_secret_access_key']
        disk_size volume_size
        disk_count node['blockdevice_nativex']['ebs']['count']
        level node['blockdevice_nativex']['ebs']['level']
        snapshots snap_ids
      end
    else
      snap_id = snaps.first.snapshot_id

      # Create new volume
      new_volume_precheck = get_volume_id(aws, snap_id)
      aws_ebs_volume 'restored_data_volume' do
        aws_access_key aws['aws_access_key_id']
        aws_secret_access_key aws['aws_secret_access_key']
        size volume_size
        #device new_device_id #device_id
        snapshot_id snap_id
        most_recent_snapshot if node['blockdevice_nativex']['restore'][:restore_point] == :latest
        ignore_failure true
        action :create
        not_if { new_volume_precheck[:status] == 'available' }
      end

      # Attach new volume
      new_volume_id = get_volume_id(aws, snap_id)
      ruby_block 'attach_restored_volume' do
        block do
          attach_volume_lwrp = Chef::Resource::BlockdeviceNativexVolume.new(new_volume_id[:id], run_context)
          attach_volume_lwrp.access_key_id(aws['aws_access_key_id'])
          attach_volume_lwrp.secret_access_key(aws['aws_secret_access_key'])
          attach_volume_lwrp.device(new_device_id) # was device_id
          attach_volume_lwrp.run_action(:attach)
        end
        action :run
        only_if { new_volume_id[:status] == 'available' }
      end
    end

    # Wait for new volume to attach
    ruby_block 'waiting_for_volume_to_attach' do
      block do
        attaching = 0
        until new_volume_id[:status] == 'in-use'
          if attaching > 180
            raise "#{new_volume_id[:id]} has been in the attaching state too long. Something is wrong."
          end
          sleep 5
          new_volume_id = Nativex::Blockdevice::Helpers.get_volume_id(aws, snap_id)
          attaching += 5
        end
      end
      ignore_failure true
    end

    # Mount new volume
    new_volume_id = get_volume_id(aws, snap_id)
    if new_volume_id[:status] == 'in-use'
      lsblk = `lsblk | grep "#{node['blockdevice_nativex']['dir']}"`
      unless lsblk.include?(new_device_id.split('/').last)
        Chef::Log.info("Mounting device=#{device_id} at dir=#{node['blockdevice_nativex']['dir']}")
        mount = `mount #{device_id} #{node['blockdevice_nativex']['dir']} -o noatime`
      end
    end

    xfs_filesystem('unfreeze')

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

    # Keep track of restored volumes
    file '/root/snapshots_restore' do
      content device_id
      action :create
    end
  end
end