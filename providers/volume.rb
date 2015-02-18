include Nativex::Blockdevice::Helpers

def whyrun_supported?
  true
end

action :detach do
  converge_by("detach volume where id=#{new_resource.volume_id}#{new_resource.force ? ' forcefully' : ''}") do
    volume = ec2_auth.volumes[new_resource.volume_id]
    volume.attachments.each do |attachment|
      attachment.delete(:force => new_resource.force)
    end
    sleep 1 until volume.status == :available
  end
end

action :attach do
  instance_id = get_instance_id
  converge_by("attach volume id=#{new_resource.volume_id} to instance id=#{instance_id}") do
    volume = ec2_auth.volumes[new_resource.volume_id]
    attachment = volume.attach_to(ec2_auth.instances[instance_id], new_resource.device)
    sleep 1 until attachment.status != :attaching
  end
end

action :delete do
  converge_by("delete volume where id=#{new_resource.volume_id}") do
    volume = ec2_auth.volumes[new_resource.volume_id]
    if new_resource.retention_check
      tags = volume.tags.to_h
      if tags[:Destroy] && tags[:DestructionTime] < Time
        destroy = true
      elsif tags[:Destroy].nil?
        raise "Retention check is set to true but volume with id=#{new_resource.volume_id} is missing"\
          ' :Destroy and :DestructionTime tags'
      else
        destroy = false
      end
    else
      destroy = true
    end
    destroy ? volume.delete_volume : Chef::Log.info("Volume id=#{device_id} not destroyed because it is not time yet")
  end
end