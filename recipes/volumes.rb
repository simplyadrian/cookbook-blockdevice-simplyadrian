directory node['blockdevice_simplyadrian']['dir'] do
  group node['blockdevice_simplyadrian']['mount_point_group']
  mode 775
  recursive true
  action :create
  not_if { ::File.directory?("#{node['blockdevice_simplyadrian']['dir']}") }
end

if node['blockdevice_simplyadrian']['ec2'] || node['cloud']['provider'] == 'ec2'
  aws = Chef::EncryptedDataBagItem.load("credentials", "aws")
  include_recipe 'aws'
  ::Chef::Recipe.send(:include, Simplyadrian::Blockdevice::Helpers)

  # Determine if this is a HVM or Paravirtual instance
  instance_id = get_instance_id
  virtualization_type = get_virtualization_type(aws, instance_id)
  if virtualization_type == :hvm
    hvm = true
  elsif virtualization_type == :paravirtual
    hvm = false
  else
    hvm = node['blockdevice_simplyadrian']['ebs']['hvm']
  end

  if node['blockdevice_simplyadrian']['ebs']['raid']

    aws_ebs_raid 'data_volume_raid' do
      mount_point node['blockdevice_simplyadrian']['dir']
      mount_point_group node['blockdevice_simplyadrian']['mount_point_group']
      disk_count node['blockdevice_simplyadrian']['ebs']['count']
      disk_size node['blockdevice_simplyadrian']['ebs']['size']
      hvm hvm
      level node['blockdevice_simplyadrian']['ebs']['level']
      filesystem node['blockdevice_simplyadrian']['filesystem']
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

    remount = true
    if node['aws']['ebs_volume']['data_volume'].attribute?('volume_id')
      existing_volume_id = node['aws']['ebs_volume']['data_volume']['volume_id']
      tags = get_volume_tags(aws, existing_volume_id)
      remount = false unless tags[:Remount]
      #raise "remount=#{remount}, tags=#{tags.inspect}, #{existing_volume_id}" if true
    end

    if remount
      # no raid, so just mount and format a single volume
      aws_ebs_volume 'data_volume' do
        aws_access_key aws['aws_access_key_id']
        aws_secret_access_key aws['aws_secret_access_key']
        size node['blockdevice_simplyadrian']['ebs']['size']
        device (hvm ? device_id : device_id.gsub('xvd', 'sd')) # aws uses sdx instead of xvdx
        most_recent_snapshot node['blockdevice_simplyadrian']['ebs']['most_recent']
        action [:create, :attach]
      end
 
      # wait for the drive to attach, before making a filesystem
      ruby_block "sleeping_data_volume" do
        block do
          timeout = 0
          until File.blockdev?(device_id) || timeout >= node['blockdevice_simplyadrian']['max_timeout']
            Chef::Log.debug("device #{device_id} not ready - sleeping 10s")
            timeout += 10
            sleep 10
          end
        end
      end

      # create a filesystem
      execute 'mkfs' do
        command "mkfs -t #{node['blockdevice_simplyadrian']['filesystem']} #{device_id}"

        # Note the escaped quotes for bash
        # blkid works on CentOS and hopefully elsewhere. See: http://unix.stackexchange.com/a/53552/55079
        # TYPE=\\\"#{node['blockdevice_simplyadrian']['filesystem']}\\\" seems to work for 'xfs' . If it doesn't work for something else, we might want a mapping of mkfs -t arguments to blkid outputs.
        not_if "blkid #{device_id} | grep \" TYPE=\\\"#{node['blockdevice_simplyadrian']['filesystem']}\\\"\""
      end

      mount node['blockdevice_simplyadrian']['dir'] do
        device device_id
        fstype node['blockdevice_simplyadrian']['filesystem']
        options 'noatime'
        action [:mount]
      end
    end
  end

  permission_recurse_switch = 'R'

  permission_recurse_switch = '' unless node['blockdevice_simplyadrian']['recurse_permissions']

  execute "fixup #{node['blockdevice_simplyadrian']['dir']} group" do
    command "chown -#{permission_recurse_switch}f :#{node['blockdevice_simplyadrian']['mount_point_group']} #{node['blockdevice_simplyadrian']['dir']}"
    only_if { Etc.getgrgid(File.stat("#{node['blockdevice_simplyadrian']['dir']}").gid).name != "#{node['blockdevice_simplyadrian']['mount_point_group']}" }
    ignore_failure true
  end

  execute "fixup #{node['blockdevice_simplyadrian']['dir']} permissions" do
    command "chmod -#{permission_recurse_switch}f 775 #{node['blockdevice_simplyadrian']['dir']}"
  end
end