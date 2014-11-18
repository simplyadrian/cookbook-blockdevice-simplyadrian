::Chef::Provider.send(:include, Aws::ebs_volume)

if node['blockdevice_nativex']['ec2'] || node['cloud']['provider'] == 'ec2'
  aws = Chef::EncryptedDataBagItem.load("credentials", "aws")
  include_recipe 'aws'  

  if node['blockdevice_nativex']['filesystem'] == "xfs"
    execute 'xfs freeze' do
      command "xfs_freeze -f #{node['blockdevice_nativex']['dir']}"
    end
  end

  if node['blockdevice_nativex']['ebs']['raid']
    device_id = "/dev/md0"
  else
    device_id = node['aws']['ebs_volume']['data_volume']['device']
  end

  if node['blockdevice_nativex']['ebs']['raid']
    devices = volume_by_id
  else
    devices = node['aws']['ebs_volume']['data_volume']['volume_id'].to_s.scan(/vol-[a-zA-Z0-9]+/)
  end

  devices.each do |values|
    aws_ebs_volume "#{node.hostname}_#{node.chef_environment}" do
      aws_access_key aws['aws_access_key_id']
      aws_secret_access_key aws['aws_secret_access_key']  
      size node['blockdevice_nativex']['ebs']['size']
      device device_id
      action :snapshot
      volume_id values
      description "snapshot of volume attached to #{node.hostname}_#{node.chef_environment}"
      ignore_failure true # if this fails, continue to unfreeze and unlock
    end
  end

  if node['blockdevice_nativex']['filesystem'] == 'xfs'
    execute 'xfs unfreeze' do
      command "xfs_freeze -u #{node['blockdevice_nativex']['dir']}"
    end
  end

  aws_ebs_volume "#{node.hostname}_#{node.chef_environment}" do
    snapshots_to_keep node['blockdevice_nativex']['snapshots_to_keep']
    action :prune
  end
end
