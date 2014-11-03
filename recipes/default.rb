#
# Cookbook Name:: blockdevice-nativex
# Recipe:: default
#
# Copyright 2014, NativeX
#
# All rights reserved - Do Not Redistribute
#

# xfsdump is not an Amazon Linux package at this moment.
case node[:platform]
when 'debian','ubuntu'
  package 'xfsprogs'
  package 'xfslibs-dev'
  package 'xfsdump'
when 'redhat','centos','fedora','amazon'
  package 'xfsprogs'
  package 'xfsprogs-devel'
  package 'xfsdump'
end

include_recipe "blockdevice-nativex::volumes"
include_recipe "blockdevice-nativex::snapshots"
