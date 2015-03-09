default['blockdevice_nativex']['ec2'] = false
default['blockdevice_nativex']['dir'] = "/mnt/ebs"
default['blockdevice_nativex']['mount_point_group'] = "root"
default['blockdevice_nativex']['recurse_permissions'] = true
default['blockdevice_nativex']['filesystem'] = "ext4"
default['blockdevice_nativex']['max_timeout'] = 180
default['blockdevice_nativex']['snapshots_to_keep'] = 5
default['blockdevice_nativex']['restore'] = {
    :take_action => true,
    :destroy_volumes_after => 0,
    :device_to_restore => '/dev/xvdb',
    :restore_point => :latest,
    :restore_point_offset => 0
    # Restore date, pick closest snapshot to restore date?
}
default['blockdevice_nativex']['ebs'] = {
  'raid' => false,
  'count'=> 4,
  'size' => 1024, # size is in GB
  'level' => 10,
  'most_recent_snapshot' => false,
  'hvm' => false
}