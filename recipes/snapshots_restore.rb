if node['blockdevice_nativex']['ec2'] || node['cloud']['provider'] == 'ec2'

  aws = Chef::EncryptedDataBagItem.load("credentials", "aws")
  include_recipe 'aws'
  require 'right_aws'
  #extend Opscode::Aws::Ec2
  include NativeX::Aws::Snapshots

  original_volume_ids = node['aws']['ebs_volume'].to_s.scan(/vol-[a-zA-Z0-9]+/)
  snap_ids = device_id = nil

  # Find volume based on attribute otherwise take the first ebs volume
  if node['blockdevice_nativex']['ebs']['raid']
    device_to_restore = node['blockdevice_nativex']['restore']['device_to_restore']
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
  end

  original_volume_ids.each do |vol|
    snap_ids << retrieve_snapshot_id(vol, true)
  end

  # Detach old volume
  aws_ebs_volume "db_ebs_volume" do
    aws_access_key aws['aws_access_key_id']
    aws_secret_access_key aws['aws_secret_access_key']
    device device_id
    action [ :detach ]
  end

  # Create new ebs volume from snapshot and attach
  aws_ebs_volume "db_ebs_volume_from_snapshot" do
    aws_access_key aws['aws_access_key_id']
    aws_secret_access_key aws['aws_secret_access_key']
    # size 20
    device device_id
    snapshot_id snap_ids
    action [ :create, :attach ]
  end

  # Tag old volume for deletion
  aws_resource_tag 'tag_data_volumes' do
    aws_access_key aws['aws_access_key_id']
    aws_secret_access_key aws['aws_secret_access_key']
    resource_id old_volume_id #can be a array
    tags({:Destroy => true,
          :DestructionDateTime => (DateTime + node['blockdevice_nativex']['restore']['destroy_volumes_after'].hours).to_datetime})
    action [:add, :update]
  end

  # Delete volumes tag for deletion older then x hours or delete right away if y = true
  if :Destroy && :DestructionDateTime < DateTime
    # Destroy volume(s)
    ## Maybe the could be put in the default recipe since restore_from_snapshot might not always be assigned. Further thinking,
    ## maybe make this a resource that this recipe and the default recipe can access.
  end
end