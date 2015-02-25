module Nativex
  module Blockdevice
    module Helpers

      def ec2_auth(id = new_resource.access_key_id, secret = new_resource.secret_access_key)
        begin
          require 'aws-sdk-v1'
        rescue LoadError
          Chef::Log.error("Missing gem 'aws-sdk-v1'. Use the default recipe to install it first.")
        end
        @ec2_auth ||= AWS::EC2.new(:access_key_id => id, :secret_access_key => secret)#, :region => get_region)
      end

      def get_instance_id
        instance_id = open('http://169.254.169.254/latest/meta-data/instance-id',options = {:proxy => false}){|f| f.gets}
        raise 'Cannot find instance id.' unless instance_id
        instance_id
      end

      def get_region
        region = open('http://169.254.169.254/latest/meta-data/placement/availability-zone/', options = {:proxy => false}){|f| f.gets}
        raise 'Cannot find region.' unless region
        region
      end

      def get_snapshot_id(creds, volume_id = '', restore_point = :latest, *offset)
        ec2 = ec2_auth(creds['aws_access_key_id'], creds['aws_secret_access_key'])
        snapshot = nil
        if restore_point == :latest
          ec2.client.describe_snapshots(filters: [{name: 'volume-id', values: [volume_id] }]).snapshot_set.each do |snap|
            snapshot = snap if snapshot.nil? || snap.start_time > snapshot.start_time
          end
        else
          #TODO: if not :latest
          # snapshots = ec2.snapshots.filter('volume-id', volume_id).filter('tag:restore_point', restore_point)
          # snapshots = snapshots.sort_by(&:start_time)
          # snapshot = snapshots[offset.abs]
        end
        #raise "output: #{snapshot.snapshot_id.nil?}" if true # <-- this works correctly
        #raise 'Cannot find valid snapshot id.' unless snapshot.snapshot_id.nil? # <-- this does not work correctly
        snapshot
      end

      def volume_exists(creds, volume_id)
        ec2 = ec2_auth(creds['aws_access_key_id'], creds['aws_secret_access_key'])
        ec2.volumes[volume_id].exists?
        # volume_status = ec2.client.describe_volume_status(volume_ids: [volume_id])
        # raise "#{volume_status[:status]}" if true
        # if volume_status[:status] == 'ok'
        #   return_value = true
        # elsif volume_status[:status] == 'insufficient-data'
        #   raise "Volume exists but insufficient data received when querying volume id=#{volume_id}. Retry request."
        # elsif volume_status[:status] == 'impaired' || volume_status[:status] == 'warning'
        #   raise "Volume exists but volume_status=#{volume_status[:status]}. Details: #{volume_status[:details][:name]}, #{volume_status[:details][:status]}"
        # else
        #   return_value = false
        # end
        # raise "#{return_value}" if true
      end

      # Returns hash with volume_id and state based off provided snapshot_id
      def get_volume_id(creds, snapshot_id)
        ec2 = ec2_auth(creds['aws_access_key_id'], creds['aws_secret_access_key'])
        ebs_volume_id = Hash.new
        ec2.client.describe_volumes(filters: [{name: 'snapshot-id', values: [snapshot_id] }]).volume_set.each do |vol|
          ebs_volume_id = { :id => vol.volume_id, :status => vol.status }
        end
        ebs_volume_id
      end

      def get_volume_device(creds, volume_id) # returns aws device name of volume, returns nil if volume does not exist
        ec2 = ec2_auth(creds['aws_access_key_id'], creds['aws_secret_access_key'])
        device = ''
        ec2.client.describe_volumes(filters: [{name: 'volume-id', values: [volume_id] }]).volume_set.each do |vol|
          vol.attachment_set.each do |attachment|
            next unless attachment.instance_id == get_instance_id
            device = attachment.device
          end
        end
        device
      end

      def get_volume_status(creds, volume_id)
        ec2 = ec2_auth(creds['aws_access_key_id'], creds['aws_secret_access_key'])
        ebs_volume_id = Hash.new
        ec2.client.describe_volumes(filters: [{name: 'volume-id', values: [volume_id] }]).volume_set.each do |vol|
          ebs_volume_id = { :id => vol.volume_id, :status => vol.status }
        end
        ebs_volume_id
      end

      def xfs_filesystem(action)
        if node['blockdevice_nativex']['filesystem'] == 'xfs'
          execute 'xfs freeze' do
            command "xfs_freeze -#{action[0,1]} #{node['blockdevice_nativex']['dir']}"
          end
        end
      end

      def device_offset(creds, volume_ids, device_ids)
        @device_offset ||= find_device_offset(creds, volume_ids, device_ids)
      end

      def find_device_offset(creds, volume_ids, device_ids)
        aws_device_iterators = local_device_iterators = []
        device_ids.each do |id|
          local_device_iterators << id.to_s[-1,1]
        end
        local_device_iterators.sort!

        volume_ids.each do |volume|
          next unless volume_exists(creds, volume)
          device_name = get_volume_device(creds, volume)
          aws_device_iterators << device_name[-1,1] unless device_name.empty?
        end
        aws_device_iterators.delete('>')
        aws_device_iterators.sort!

        #Check for the offset
        device_offset = 0
        if local_device_iterators.first == aws_device_iterators.first
          # No offset
        elsif local_device_iterators.first < aws_device_iterators.first
          (local_device_iterators.first ... aws_device_iterators.first).each do device_offset += 1 end
        elsif local_device_iterators.first > aws_device_iterators.first
          (aws_device_iterators.first ... local_device_iterators.first).each do device_offset -= 1 end
        else
          Chef::Log.error('Invalid device specified.')
        end
        device_offset
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