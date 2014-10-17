# The database recipe should be included by any server running a DB. It creates
# a /data directory and, if on EC2, will mount an EBS volume here
 
directory '/mnt/ebs' do
  mode '0755'
end

if node[:nativex_blockdevice][:ec2] || node[:cloud][:provider] == 'ec2'
  aws = Chef::EncryptedDataBagItem.load("credentials", "aws")
  include_recipe 'aws'
 
  if node[:nativex_blockdevice][:ebs][:raid]
 
    aws_ebs_raid 'data_volume_raid' do
      mount_point '/mnt/ebs'
      disk_count 4
      disk_size node[:nativex_blockdevice][:ebs][:size]
      level 10
      filesystem 'ext4'
      action :auto_attach
    end
 
  else
 
    # get a device id to use
    devices = Dir.glob('/dev/xvd?')
    devices = ['/dev/xvdf'] if devices.empty?
    devid = devices.sort.last[-1,1].succ
 
    # save the device used for data_volume on this node -- this volume will now always
    # be attached to this device
    node.set_unless[:aws][:ebs_volume][:data_volume][:device] = "/dev/xvd#{devid}"
 
    device_id = node[:aws][:ebs_volume][:data_volume][:device]
 
    # no raid, so just mount and format a single volume
    aws_ebs_volume 'data_volume' do
      aws_access_key aws['aws_access_key_id']
      aws_secret_access_key aws['aws_secret_access_key']
      size node[:nativex_blockdevice][:ebs][:size]
      device device_id.gsub('xvd', 'sd') # aws uses sdx instead of xvdx
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
      command "mkfs -t ext4 #{device_id}"
    end
 
    mount '/mnt/ebs' do
      device device_id
      fstype 'ext4'
      options 'noatime,nobootwait'
      action [:mount]
    end
  end
end
