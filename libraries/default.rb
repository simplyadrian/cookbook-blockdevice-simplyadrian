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

      def get_virtualization_type(creds, instance_id)
        ec2 = ec2_auth(creds['aws_access_key_id'], creds['aws_secret_access_key'])
        ec2.instances[instance_id].virtualization_type
      end

      def get_snapshot_id(creds, volume_id = '', restore_point = :latest, *offset)
        ec2 = ec2_auth(creds['aws_access_key_id'], creds['aws_secret_access_key'])
        snapshot = nil
        if restore_point == :latest
          ec2.client.describe_snapshots(filters: [{name: 'volume-id', values: [volume_id] }]).snapshot_set.each do |snap|
            snapshot = snap if snapshot.nil? || snap.start_time > snapshot.start_time
          end
        else
          x = 0
          ec2.client.describe_snapshots(filters: [{name: 'volume-id', values: [volume_id] }, {name: 'tag', values: ["RestorePoint=#{restore_point}"] }]).snapshot_set.each do |snap|
            snapshot = snap
            if offset > 0 && x == offset
              break
            elsif offset == 0
              break
            end
            x += 1
          end
        end
        #raise "output: #{snapshot.snapshot_id.nil?}" if true # <-- this works correctly
        #raise 'Cannot find valid snapshot id.' unless snapshot.snapshot_id.nil? # <-- this does not work correctly
        snapshot
      end

      def volume_exists(creds, volume_id)
        ec2 = ec2_auth(creds['aws_access_key_id'], creds['aws_secret_access_key'])
        ec2.volumes[volume_id].exists?
      end

      def get_volume_id(creds, snapshot_id) # Returns hash with volume_id and state based off provided snapshot_id
        ec2 = ec2_auth(creds['aws_access_key_id'], creds['aws_secret_access_key'])
        ebs_volume_id = Hash.new
        ec2.client.describe_volumes(filters: [{name: 'snapshot-id', values: [snapshot_id] }]).volume_set.each do |vol|
          ebs_volume_id = { :id => vol.volume_id, :status => vol.status }
        end
        ebs_volume_id
      end

      def get_volume_device(creds, volume_id) # Returns aws device name of volume, returns nil if volume does not exist
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

      def get_volume_tags(creds, volume_id)
        ec2 = ec2_auth(creds['aws_access_key_id'], creds['aws_secret_access_key'])
        volume = ec2.volumes[volume_id]
        volume.tags.to_h
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

        device_offset = 0
        if local_device_iterators.first == aws_device_iterators.first
          Chef::Log.info('No offset detected.')
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
