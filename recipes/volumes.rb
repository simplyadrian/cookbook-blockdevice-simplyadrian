directory node['blockdevice_nativex']['dir'] do
  group node['blockdevice_nativex']['mount_point_group']
  mode 775
  recursive true
  action :create
  not_if { ::File.directory?("#{node['blockdevice_nativex']['dir']}") }
end 

if node['blockdevice_nativex']['ec2'] || node['cloud']['provider'] == 'ec2'
  aws = Chef::EncryptedDataBagItem.load("credentials", "aws")
  include_recipe 'aws'

  if node['blockdevice_nativex']['ebs']['raid']
 
    aws_ebs_raid 'data_volume_raid' do
      mount_point node['blockdevice_nativex']['dir']
      mount_point_group node['blockdevice_nativex']['mount_point_group']
      disk_count node['blockdevice_nativex']['ebs']['count']
      disk_size node['blockdevice_nativex']['ebs']['size']
      level node['blockdevice_nativex']['ebs']['level']
      filesystem node['blockdevice_nativex']['filesystem']
      action :auto_attach
    end

  else
 
    # get a device id to use
    devices = Dir.glob('/dev/xvd?')
    devices = ['/dev/xvdf'] if devices.empty?
    devid = devices.sort.last[-1,1].succ
 
    # save the device used for data_volume on this node -- this volume will now always
    # be attached to this device
    node.set_unless['aws']['ebs_volume']['data_volume']['device'] = "/dev/xvd#{devid}"
 
    device_id = node['aws']['ebs_volume']['data_volume']['device']      
 
    # no raid, so just mount and format a single volume
    aws_ebs_volume 'data_volume' do
      aws_access_key aws['aws_access_key_id']
      aws_secret_access_key aws['aws_secret_access_key']
      size node['blockdevice_nativex']['ebs']['size']
      device device_id.gsub('xvd', 'sd') # aws uses sdx instead of xvdx
      most_recent_snapshot node['blockdevice_nativex']['ebs']['most_recent']
      action [:create, :attach]
    end
 
    # wait for the drive to attach, before making a filesystem
    ruby_block "sleeping_data_volume" do
      block do
        timeout = 0
        until File.blockdev?(device_id) || timeout == 1000
          Chef::Log.debug("device #{device_id} not ready - sleeping 10s")
          timeout += 10
          sleep 10
        end
      end
    end
 
    # create a filesystem
    execute 'mkfs' do
      command "mkfs -t #{node['blockdevice_nativex']['filesystem']} #{device_id}"
      not_if "grep #{device_id} /proc/mounts"
    end
 
    mount node['blockdevice_nativex']['dir'] do
      device device_id
      fstype node['blockdevice_nativex']['filesystem']
      options 'noatime'
      action [:mount]
    end
  end
  execute "fixup #{node['blockdevice_nativex']['dir']} group" do
    command "chown -Rf :#{node['blockdevice_nativex']['mount_point_group']} #{node['blockdevice_nativex']['dir']}"
  only_if { Etc.getgrgid(File.stat("#{node['blockdevice_nativex']['dir']}").gid).name != "#{node['blockdevice_nativex']['mount_point_group']}" }
  end
end