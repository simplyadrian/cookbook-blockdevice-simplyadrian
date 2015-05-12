default['blockdevice_simplyadrian']['ec2'] = false
default['blockdevice_simplyadrian']['dir'] = "/mnt/ebs"
default['blockdevice_simplyadrian']['mount_point_group'] = "root"
default['blockdevice_simplyadrian']['recurse_permissions'] = true
default['blockdevice_simplyadrian']['filesystem'] = "ext4"
default['blockdevice_simplyadrian']['max_timeout'] = 180
default['blockdevice_simplyadrian']['snapshots_to_keep'] = 5
default['blockdevice_simplyadrian']['restore'] = {
    :take_action => false,
    :destroy_volumes_after => 0,
    :device_to_restore => '/dev/xvdb',
    :restore_point => :latest,
    :restore_point_offset => 0,
    :restore_to_new_device => false
}
default['blockdevice_simplyadrian']['ebs'] = {
  'raid' => false,
  'count'=> 4,
  'size' => 1024, # size is in GB
  'level' => 10,
  'most_recent_snapshot' => false,
  'hvm' => false
}
