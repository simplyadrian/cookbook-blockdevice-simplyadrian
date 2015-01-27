if (node['blockdevice_nativex']['ec2'] || node['cloud']['provider'] == 'ec2') &&
    node['blockdevice_nativex']['restore'][:take_action]

  aws = Chef::EncryptedDataBagItem.load("credentials", "aws")
  include_recipe 'aws'
  ::Chef::Recipe.send(:include, Nativex::Blockdevice::Instance)
  ::Chef::Recipe.send(:include, Nativex::Blockdevice::Snapshots)
  ::Chef::Recipe.send(:include, Nativex::Blockdevice::Volumes)

  original_volume_ids = node['aws']['ebs_volume'].to_s.scan(/vol-[a-zA-Z0-9]+/) # add logic to match device, maybe move in loop below
  device_id = nil
  sizes = snap_ids = []

  raid = node['blockdevice_nativex']['ebs']['raid']

  # Find volume based on attribute otherwise take the first ebs volume
  if raid
    device_to_restore = node['blockdevice_nativex']['restore'][:device_to_restore]
    device_ids = nil
    Dir.glob('/dev/md[0-9]*').each do |dir| device_ids << dir end
    if device_ids.length == 1 || (device_ids > 1 && device_to_restore.blank?)
      device_id = device_ids[0]
    elsif device_ids > 1
      if device_to_restore =~ '/dev/md[0-9]*'
        begin
          device_id = device_ids.index(device_to_restore)
        rescue
          Chef::Log.error("Invalid device specified (#{device_to_restore}). Found: #{device_ids.inspect}")
        end
      else
        Chef::Log.error("Invalid device specified (#{device_to_restore}). Found: #{device_ids.inspect}")
      end
    else
      Chef::Log.error('RAID specified but no RAID device found.')
    end
  else
    device_id = node['aws']['ebs_volume']['data_volume']['device']
    # Add logic to match device to :device_to_restore
    # Also add logic if there is no match
  end

  ec2_auth(aws['aws_access_key_id'], aws['aws_secret_access_key'])
  @instance_id = get_instance_id

  original_volume_ids.each do |vol|
    snap_ids << get_snapshot_id(vol, node['blockdevice_nativex']['restore'][:restore_point])
    #sizes << @ec2.volumes[vol].size
  end

  xfs_filesystem('freeze')
  mount node['blockdevice_nativex']['dir'] do
    device device_id
    action [:umount, :disable]
  end

  if node['blockdevice_nativex']['ebs']['raid']
  else
    # Detach old volume
    blockdevice_nativex_volume volume_id do
      force true
      action :detach
    end
    # original_volume_ids.each do |volume_id|
    #   detach_volume(volume_id, true)
    # end

    # Create new ebs volume from snapshot and attach
    if raid
      aws_ebs_raid 'db_ebs_raid_from_snapshot' do
        aws_access_key aws['aws_access_key_id']
        aws_secret_access_key aws['aws_secret_access_key']
        disk_size 20 # cant hardcode this value
        disk_count 3
        level 5
        snapshots snap_ids
      end
    else
      snap_id = snap_ids.first
      new_volume_id = aws_ebs_volume 'db_ebs_volume_from_snapshot' do
        aws_access_key aws['aws_access_key_id']
        aws_secret_access_key aws['aws_secret_access_key']
        size 20 # cant hardcode this value
        device device_id
        snapshot_id snap_id
        most_recent_snapshot if node['blockdevice_nativex']['restore'][:restore_point] == :latest
        ignore_failure true
        action [ :create ] # was , :attach
      end
      blockdevice_nativex_volume new_volume_id do
        instance_id @instance_id
        device device_id
        action :attach
      end
    end

    mount node['blockdevice_nativex']['dir'] do
      device device_id
      fstype node['blockdevice_nativex']['filesystem']
      options 'noatime'
      action [:mount]
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
  end

  destroy_volumes
end