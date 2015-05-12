if node['blockdevice_simplyadrian']['ec2'] || node['cloud']['provider'] == 'ec2'
  aws = Chef::EncryptedDataBagItem.load('credentials', 'aws')
  include_recipe 'aws'  

  if node['blockdevice_simplyadrian']['filesystem'] == 'xfs'
    execute 'xfs freeze' do
      command "xfs_freeze -f #{node['blockdevice_simplyadrian']['dir']}"
    end
  end

  device_id = nil
  if node['blockdevice_simplyadrian']['ebs']['raid']
    Dir.glob('/dev/md[0-9]*').each do |dir|
      Chef::Log.error('More than one /dev/mdX found.') unless device_id.nil?
      device_id = dir
      Chef::Log.info("RAID device: #{device_id}")
    end
  else
    device_id = node['aws']['ebs_volume']['data_volume']['device']
  end

  # Wont run on first chef-client run since ohai has not populated the ebs_volume attribute
  unless node['aws']['ebs_volume'].to_s.scan(/vol-[a-zA-Z0-9]+/).empty?
    x = 0
    y = 1
    while x < y
      vol = lambda {
          ids = node['aws']['ebs_volume'].to_s.scan(/vol-[a-zA-Z0-9]+/)
          y = ids.count
          ids[x]
      }
      aws_ebs_volume "#{node.hostname}_#{node.chef_environment}" do
        aws_access_key aws['aws_access_key_id']
        aws_secret_access_key aws['aws_secret_access_key']
        size node['blockdevice_simplyadrian']['ebs']['size']
        device device_id
        action :snapshot
        volume_id vol.call
        description "snapshot of volume attached to #{node.hostname}_#{node.chef_environment}"
        ignore_failure true
      end
      aws_ebs_volume "#{node.hostname}_#{node.chef_environment}" do
        volume_id vol.call
        snapshots_to_keep node['blockdevice_simplyadrian']['snapshots_to_keep']
        action :prune
        ignore_failure true
      end
      x += 1
    end
  end

  if node['blockdevice_simplyadrian']['filesystem'] == 'xfs'
    execute 'xfs unfreeze' do
      command "xfs_freeze -u #{node['blockdevice_simplyadrian']['dir']}"
    end
  end
end