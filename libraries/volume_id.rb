::Chef::Recipe.send(:include, Opscode::Aws::Ec2)

module NativeX
  module VolumeId
    module Helper
      
      def determine_volume_id
        ec2.describe_instance_attribute(filters: [{name: "instance_id", values: [instance_id] }])
      end
    end
  end
end