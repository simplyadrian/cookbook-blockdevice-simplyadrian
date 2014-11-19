aws = Chef::EncryptedDataBagItem.load("credentials", "aws")

include_recipe 'aws'

if node['blockdevice_nativex']['ebs']['raid']
  devices = node['aws']['ebs_volume'].values.to_s.scan(/vol-[a-zA-Z0-9]+/)
else
  devices = node['aws']['ebs_volume']['data_volume']['volume_id'].to_s.scan(/vol-[a-zA-Z0-9]+/)
end

aws_resource_tag 'tag_data_volumes' do
  aws_access_key aws['aws_access_key_id']
  aws_secret_access_key aws['aws_secret_access_key']
  resource_id devices
  tags({"Name" => node.hostname,
        "Environment" => node.chef_environment})
  action [:add, :update]
 end