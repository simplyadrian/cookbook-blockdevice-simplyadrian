aws = Chef::EncryptedDataBagItem.load("credentials", "aws")

include_recipe 'aws'

aws_resource_tag 'tag_data_volumes' do
  aws_access_key aws['aws_access_key_id']
  aws_secret_access_key aws['aws_secret_access_key']
  resource_id lazy {node['aws']['ebs_volume'].values.to_s.scan(/vol-[a-zA-Z0-9]+/)}
  tags({"Name" => node.hostname,
        "Environment" => node.chef_environment})
  action [:add, :update]
 end