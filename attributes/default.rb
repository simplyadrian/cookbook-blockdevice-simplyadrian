default['blockdevice_nativex']['ec2'] = false
default['blockdevice_nativex']['dir'] = "/mnt/ebs"
default['blockdevice_nativex']['mount_point_group'] = "root"
default['blockdevice_nativex']['recurse_permissions'] = true
default['blockdevice_nativex']['filesystem'] = "ext4"
default['blockdevice_nativex']['snapshots_to_keep'] = 5
# default['blockdevice_nativex']['snapshots_to_keep'] = {
#     :hourly => 8,
#     :daily => 7,
#     :weekly => 4,
#     :monthly => 3
# }
default['blockdevice_nativex']['restore'] = {
    :destroy_volumes_after => 0, # hours, set to 0 for immediate destruction
    :device_to_restore => '', # id of device to restore
    :restore_point => :daily # valid options :hourly :daily :weekly :monthly
}
default['blockdevice_nativex']['ebs'] = {
  'raid' => false,
  'count'=> 4,
  'size' => 1024, # size is in GB
  'level' => 10,
  'most_recent_snapshot' => false,
  'hvm' => false
}