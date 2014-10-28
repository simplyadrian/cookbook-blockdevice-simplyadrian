default[:blockdevice_nativex][:ec2] = false
default[:blockdevice_nativex][:dir] = '/mnt/ebs'
default[:blockdevice_nativex][:filesystem] = 'xfs'
default[:blockdevice_nativex][:ebs] = {
  :raid => true,
  :count=> 4,
  :size => 1024, # size is in GB
  :level => 10
}
