default['blockdevice_nativex']['ec2'] = false
default['blockdevice_nativex']['dir'] = "/mnt/ebs"
default['blockdevice_nativex']['mount_point_group'] = "root"
default['blockdevice_nativex']['recurse_permissions'] = true
default['blockdevice_nativex']['filesystem'] = "ext4"
default['blockdevice_nativex']['max_timeout'] = 180 # seconds, max timeout for volume operations
default['blockdevice_nativex']['snapshots_to_keep'] = 5
#default['blockdevice_nativex']['volumes_attribute'] = node[aws][ebs_volume] # indicate in help what sub structure should look like
# default['blockdevice_nativex']['snapshots_to_keep'] = {
#     :hourly => 8,
#     :daily => 7,
#     :weekly => 4,
#     :monthly => 3
# }
default['blockdevice_nativex']['restore'] = {
    :take_action => true, # wheter or not to take action during chef run
    :destroy_volumes_after => 0, # hours, set to 0 for immediate destruction
    :device_to_restore => '/dev/xvdf', # id of device to restore, if blank it will restore the first device found
    :restore_point => :latest, # valid options :latest :hourly :daily :weekly :monthly
    :restore_point_offset => 0 # # Example: if restore_point is set to daily and restore_point is set to -1 it will restore to :latest daily -1. Set to 0 to choose the latest
    # restore date, pick closest snapshot?
}
default['blockdevice_nativex']['ebs'] = {
  'raid' => false,
  'count'=> 4,
  'size' => 1024, # size is in GB
  'level' => 10,
  'most_recent_snapshot' => false,
  'hvm' => false
}