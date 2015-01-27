#
# Cookbook Name:: blockdevice-nativex
# Recipe:: default
#
# Copyright 2014, NativeX
#
# All rights reserved - Do Not Redistribute
#

gem_package "aws-sdk" do
  action :install
end

include_recipe "xfs::default" if node['blockdevice_nativex']['filesystem'] == "xfs"
include_recipe "blockdevice-nativex::volumes"
