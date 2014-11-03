if node[:blockdevice_nativex][:ec2] || node[:cloud][:provider] == 'ec2'
  aws = Chef::EncryptedDataBagItem.load("credentials", "aws")
  include_recipe 'aws'

  #execute 'xfs freeze' do
  #  command "xfs_freeze -f #{node.db_snapshot.ebs_vol_dev}"
  #end
  
  devices = node['aws']['ebs_volume'].values.to_s.scan(/vol-[a-zA-Z0-9]+/)

  devices.each do |values|
    aws_ebs_volume "#{node.hostname}_#{node.chef_environment}" do
      aws_access_key aws['aws_access_key_id']
      aws_secret_access_key aws['aws_secret_access_key']  
      size node[:blockdevice_nativex][:ebs][:size]
      device "/dev/md0"
      snapshots_to_keep node[:blockdevice_nativex][:snapshots_to_keep]
      action :snapshot
      volume_id values
      description "snapshot of volume attached to #{node.hostname}_#{node.chef_environment}"
      ignore_failure true # if this fails, continue to unfreeze and unlock
    end
  end

  #execute 'xfs unfreeze' do
  #  command "xfs_freeze -u #{node.db_snapshot.ebs_vol_dev}"
  #end

  aws_ebs_volume "#{node.hostname}_#{node.chef_environment}" do
    action :prune
  end
end

aws_resource_tag 'tag_snapshots' do
  aws_access_key aws['aws_access_key_id']
  aws_secret_access_key aws['aws_secret_access_key']
  resource_id devices
  tags({"Name" => node.hostname,
        "Environment" => node.chef_environment})
  action [:add, :update]
end
