module Nativex
  module Blockdevice
    module Helpers

      def ec2_auth(id = new_resource.access_key_id, secret = new_resource.secret_access_key)
        begin
          require 'aws-sdk'
        rescue LoadError
          Chef::Log.error("Missing gem 'aws-sdk'. Use the default recipe to install it first.")
        end
        AWS::EC2.new(:access_key_id => id, :secret_access_key => secret) #, :region => get_region (this dint work) TODO: Restrict to region
      end

      def get_instance_id
        instance_id = open('http://169.254.169.254/latest/meta-data/instance-id',options = {:proxy => false}){|f| f.gets}
        raise 'Cannot find instance id.' unless instance_id
        instance_id
      end

      def get_region
        region = open('http://169.254.169.254/latest/meta-data/placement/availability-zone/', options = {:proxy => false}){|f| f.gets}
        raise "Cannot find region." unless region
        region
      end

      def get_snapshot_id(creds, volume_id = '', restore_point = :latest, *offset)
        ec2 = ec2_auth(creds['aws_access_key_id'], creds['aws_secret_access_key'])
        snapshot = nil
        if restore_point == :latest
          ec2.client.describe_snapshots(filters: [{name: 'volume-id', values: [volume_id] }]).snapshot_set.each do |snap|
            snapshot = snap if snapshot.nil? || snap.start_time > snapshot.start_time
          end
          # snapshots = ec2.client.describe_snapshots#(filters: [{name: 'volume-id', values: [volume_id] }]).each do |snap|
          # #ec2.snapshots.filter('volume-id', volume_id).each do |snap|
          # snapshots.each do |snap|
          #   next unless snap[:volume_id] == volume_id
          #   snapshot = snap if snapshot.nil? || snap[:start_time] > snapshot[:start_time]
          # end
        else
          #TODO: if not :latest
          # snapshots = ec2.snapshots.filter('volume-id', volume_id).filter('tag:restore_point', restore_point)
          # snapshots = snapshots.sort_by(&:start_time)
          # snapshot = snapshots[offset.abs]
        end
        #raise "output: #{snapshot.snapshot_id.nil?}" if true # <-- this works correctly
        #raise 'Cannot find valid snapshot id.' unless snapshot.snapshot_id.nil? # <-- this does not work correctly
        snapshot #= snapshot.id.to_s.scan(/snap-[a-zA-Z0-9]+/)
        #snapshot.first
      end

      def volume_exists(creds, volume_id)
        ec2 = ec2_auth(creds['aws_access_key_id'], creds['aws_secret_access_key'])
        ec2.volumes[volume_id].exists?
      end

      def xfs_filesystem(action)
        if node['blockdevice_nativex']['filesystem'] == 'xfs'
          execute 'xfs freeze' do
            command "xfs_freeze -#{action[0,1]} #{node['blockdevice_nativex']['dir']}"
          end
        end
      end

    end
  end
end


# def find_snapshot_id(volume_id="", find_most_recent=false)
#   snapshot_id = nil
#   snapshots = if find_most_recent
#                 ec2.describe_snapshots.sort { |a,b| a[:aws_started_at] <=> b[:aws_started_at] }
#               else
#                 ec2.describe_snapshots.sort { |a,b| b[:aws_started_at] <=> a[:aws_started_at] }
#               end
#   snapshots.each do |snapshot|
#     if snapshot[:aws_volume_id] == volume_id
#       snapshot_id = snapshot[:aws_id]
#     end
#   end
#   raise "Cannot find snapshot id!" unless snapshot_id
#   Chef::Log.debug("Snapshot ID is #{snapshot_id}")
#   snapshot_id
# end