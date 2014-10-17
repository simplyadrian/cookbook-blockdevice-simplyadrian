default[:nativex_blockdevice][:ec2] = false
default[:nativex_blockdevice][:ebs] = {
  :raid => true,
  :size => 512 # size is in GB
}
