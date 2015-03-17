blockdevice-nativex CHANGELOG
=============================

This file is used to list changes made in each version of the blockdevice-nativex cookbook.

0.3.0
-----
- [Jesse Hauf] - Renamed snapshots to snapshots_take
- [Jesse Hauf] - Created snapshots_restore recipe and added support for restoring snapshots
- [Jesse Hauf] - Added lwrps to support independent create and attach operations, deleting volumes, and force
detaching volumes.
- [Jesse Hauf] - Added lwrp to wait for attach and create operations
- [Jesse Hauf] - Add libraries to support aws-sdk-v1 Ruby operations
- [Jesse Hauf] - Added timeout attribute support to volume recipe
- [Jesse Hauf] - Added support for auto-detecting HVM instances

0.2.0
-----
- [Jesse Hauf] - Added support for HVM instances
- [Jesse Hauf] - Optimized permission_recurse_switch flow control statement
- [Jesse Hauf] - Added support for snapshotting RAID volumes
- [Jesse Hauf] - Added support for pruning RAID volumes
- [Jesse Hauf] - Search for device_id on RAID volumes rather than a hardcoded value
- [Brett Stime] - Fixed bug with mkfs where file system is not created on new deployments

0.1.0
-----
- [Adrian Herrera] - Initial release of blockdevice-nativex

- - -
Check the [Markdown Syntax Guide](http://daringfireball.net/projects/markdown/syntax) for help with Markdown.

The [Github Flavored Markdown page](http://github.github.com/github-flavored-markdown/) describes the differences between markdown on github and standard markdown.
