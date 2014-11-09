aws = Chef::EncryptedDataBagItem.load("credentials", "aws")

include_recipe 'aws'

#volumes = node['aws']['ebs_volume'].values.to_s
#volumeids = volumes.scan(/vol-[a-zA-Z0-9]+/).to_a

volume_ids = node['aws']['ebs_volume']['volume_id']

aws_resource_tag 'tag_data_volumes' do
  aws_access_key aws['aws_access_key_id']
  aws_secret_access_key aws['aws_secret_access_key']
  resource_id volumeids
  tags({"Name" => node.hostname,
        "Environment" => node.chef_environment})
  action [:add, :update]
 end