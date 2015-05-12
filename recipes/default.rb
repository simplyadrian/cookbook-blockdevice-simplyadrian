#
# Cookbook Name:: blockdevice-simplyadrian
# Recipe:: default
#
# Copyright 2014, simplyadrian
#
# All rights reserved - Do Not Redistribute
#

gem_package "aws-sdk-v1" do
  action :install
end

include_recipe "xfs::default" if node['blockdevice_simplyadrian']['filesystem'] == "xfs"
include_recipe "blockdevice-simplyadrian::volumes"
