blockdevice-nativex Cookbook
============================
This cookbook provides recipes that create, tag, and snapshot EBS volumes.

Requirements
------------
The instance must be launched using knife-ec2 or the aws::ec2_hints recipe must be assigned.

Depends on aws community cookbook. When launching HVM instances, NativeX fork of aws cookbook is required.
Depends on xfs community cookbook if filesystem will be xfs.

An Amazon Web Services account is required. The Access Key and Secret Access Key are used to authenticate with EC2.

Recipes
-------
#### default.rb
Calls xfs::default if the filesystem will be xfs
also calls blockdevice-nativex::volumes

#### snapshots_take.rb
Snapshots the instance EBS volume on each chef client run and prunes old snapshots automatically. Number of snapshots
to maintain can be specified in a cookbook attribute. Handles freezing/unfreezing EBS volume.

Note: Currently the snapshots recipe will not snapshot an instance on the first chef-client run because ohai ebs
attributes are on available. It will work on subsequent runs.

#### snapshots_restore.rb
Restores an EBS volume from snapshot.

#### tags.rb
Tags EBS volumes with their volume IDs.

#### volumes.rb
Handles creating and attaching EBS volumes to instances based on the supplied attributes leveraging the aws community
cookbook. If a RAID volume is specified it will create multiple volumes, mount the volumes in the instance, and create
a software RAID across the volumes.

Attributes
----------
#### blockdevice-nativex::default
<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['blockdevice_nativex']['ec2']</tt></td>
    <td>Boolean</td>
    <td>Must be set to true if knife-ec2 is not used to launch the instance and aws::ec2_hints is not assigned.</td>
    <td><tt>false</tt></td>
  </tr>
  <tr>
    <td><tt>['blockdevice_nativex']['dir']</tt></td>
    <td>String</td>
    <td>Mount point for EBS volume.</td>
    <td><tt>"/mnt/ebs"</tt></td>
  </tr>
  <tr>
    <td><tt>['blockdevice_nativex']['mount_point_group']</tt></td>
    <td>String</td>
    <td>Group to mount EBS volume as.</td>
    <td><tt>"root"</tt></td>
  </tr>
  <tr>
    <td><tt>['blockdevice_nativex']['recurse_permissions']</tt></td>
    <td>Boolean</td>
    <td>Whether to use recursion when assigning permissions.</td>
    <td><tt>true</tt></td>
  </tr>
  <tr>
    <td><tt>['blockdevice_nativex']['filesystem']</tt></td>
    <td>String</td>
    <td>File system to format the EBS volume as.</td>
    <td><tt>"ext4"</tt></td>
  </tr>
  <tr>
    <td><tt>['blockdevice_nativex']['ebs']</tt></td>
    <td>Hash</td>
    <td>Override attributes for aws_ebs_volume provider from aws cookbook.</td>
    <td><tt>See aws_ebs_volume. Example usage below.</tt></td>
  </tr>
</table>

#### blockdevice-nativex::snapshots
<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['blockdevice_nativex']['snapshots_to_keep']</tt></td>
    <td>Int</td>
    <td>Number of snapshots to retain during pruning operation. Oldest snapshots will be pruned first.</td>
    <td><tt>5</tt></td>
  </tr>
</table>

Resources and Providers
-----

## volume.rb
Actions:
* `attach` - attaches a specified volume to specified instance
* `detach` - detaches a volume from all instances
* `delete` - deletes a volume

Attribute Parameters:
* `access_key_id`, secret_access_key - passed to Nativex::Blockdevice::Helpers to authenticate to AWS
* `volume_id` - Default parameter. ID of EBS volume
* `force` - Works with action :detach to force the operation
* `device` - Local block device where volume is attached/needs to be attached
* `instance_id` - ID of instance can be grabbed using Nativex::Blockdevice::Helpers get_instance_id
* `retention_check` - Used when deleting volumes to check that resource tag :Destroy is set to true and :DestructionTime has
lapsed

See usage examples in snapshots_restore.rb

Usage
-----
Include `blockdevice-nativex` in your node's `run_list`:

```json
{
  "name":"my_node",
  "run_list": [
    "recipe[blockdevice-nativex]"
  ]
}
```

Configure `blockdevice-nativex` in a role:

```json
"blockdevice_nativex": {
  "dir": "/mnt/ebs",
  "mount_point_group": "predictive_analytics",
  "recurse_permissions": false,
  "filesystem": "xfs",
  "ebs": {
    "raid": true,
    "count": 4,
    "size": 500,
    "level": 10,
    "most_recent_snapshot": false,
    "hvm": false
  }
},
```

Note: Size is in GB

HVM override attribute is specific to the NativeX fork of aws cookbook and is required to be set to 'true' when
provisioning EBS volumes on HVM instances.

License and Authors
-------------------
Authors: Adrian Herrera, Jesse Hauf, Brett Stime

Copyright 2014-2015, NativeX Holdings LLC.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
