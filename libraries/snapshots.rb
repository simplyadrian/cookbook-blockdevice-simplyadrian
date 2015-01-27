module Nativex
  module Blockdevice
    module Instance

      def ec2_auth(id, secret)
        begin
          require 'aws-sdk'
        rescue LoadError
          Chef::Log.error("Missing gem 'aws-sdk'. Use the default recipe to install it first.")
        end
        AWS.config(:access_key_id => id, :secret_access_key => secret)
        @ec2 = AWS::EC2.new
      end

      def get_instance_id
        instance_id = open('http://169.254.169.254/latest/meta-data/instance-id',options = {:proxy => false}){|f| f.gets}
        raise 'Cannot find instance id.' unless instance_id
        instance_id
      end

    end
    module Snapshots

      def get_snapshot_id(volume_id = '', restore_point = :latest, *offset)
        if restore_point == :latest
          snapshot = nil
          @ec2.snapshots.filter('volume-id', volume_id).each do |snap|
            snapshot = snap if snapshot.nil? || snap.start_time > snapshot.start_time
          end
          snapshot = snapshot.id.to_s.scan(/snap-[a-zA-Z0-9]+/)
          snapshot.first
        else
          snapshots = @ec2.snapshots.filter('volume-id', volume_id).filter('tag:restore_point', restore_point)
          snapshots = snapshots.sort_by(&:start_time)
          snapshot = snapshots[offset.abs]
          snapshot = snapshot.id.to_s.scan(/snap-[a-zA-Z0-9]+/)
          snapshot.first
        end
      end

      def destroy_volumes(volume_id = '')
        # Delete volumes tag for deletion older then x hours or delete right away if y = true
        if :Destroy && :DestructionTime < Time
          # Destroy volume(s)
          ## Maybe the could be put in the default recipe since restore_from_snapshot might not always be assigned. Further thinking,
          ## maybe make this a resource that this recipe and the default recipe can access.
        end
      end

      def xfs_filesystem(action)
        if node['blockdevice_nativex']['filesystem'] == 'xfs'
          execute 'xfs freeze' do
            command "xfs_freeze -#{action[0,1]} #{node['blockdevice_nativex']['dir']}"
          end
        end
      end

    end

    module Volumes
      def detach_volume(volume_id = '', force = false)
        #converge_by("Detaching volume where id=#{volume_id}#{force ? ' forcefully' : ''}") do
          volume = @ec2.volumes[volume_id]
          volume.attachments.each do |attachment|
            attachment.delete(:force => force)
          end
          sleep 1 until volume.status == :available
        #end
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