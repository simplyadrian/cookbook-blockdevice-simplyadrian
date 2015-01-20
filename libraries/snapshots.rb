module NativeX
  module Aws
    module Snapshots
      def retrieve_snapshot_id(volume_id="", find_most_recent=false)
        snapshot_id = nil
        snapshots = if find_most_recent
                      ec2.describe_snapshots.sort { |a,b| a[:aws_started_at] <=> b[:aws_started_at] }
                    else
                      ec2.describe_snapshots.sort { |a,b| b[:aws_started_at] <=> a[:aws_started_at] }
                    end
        snapshots.each do |snapshot|
          if snapshot[:aws_volume_id] == volume_id
            snapshot_id = snapshot[:aws_id]
          end
        end
        raise "Cannot find snapshot id!" unless snapshot_id
        Chef::Log.debug("Snapshot ID is #{snapshot_id}")
        snapshot_id
      end
    end
  end
end