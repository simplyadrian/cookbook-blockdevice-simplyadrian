include Simplyadrian::Blockdevice::Helpers

def whyrun_supported?
  true
end

action :detach do
  converge_by("detach volume_id=#{new_resource.volume_id}#{new_resource.force ? ' forcefully' : ''}") do
    volume = ec2_auth.volumes[new_resource.volume_id]
    volume.attachments.each do |attachment|
      attachment.delete(:force => new_resource.force)
    end
    sleep 1 until volume.status == :available
  end
end

action :attach do
  instance_id = get_instance_id
  converge_by("attach volume_id=#{new_resource.volume_id} to instance_id=#{instance_id}") do
    volume = ec2_auth.volumes[new_resource.volume_id]
    attachment = volume.attach_to(ec2_auth.instances[instance_id], new_resource.device)
    sleep 1 until attachment.status != :attaching
  end
end

action :delete do
  converge_by("delete volume_id=#{new_resource.volume_id}") do
    volume = ec2_auth.volumes[new_resource.volume_id]
    if new_resource.retention_check
      tags = volume.tags.to_h
      if tags[:Destroy] && tags[:DestructionTime] < Time
        destroy = true
      elsif tags[:Destroy].nil?
        raise "Retention check is set to true but volume_id=#{new_resource.volume_id} is missing"\
          ' :Destroy and :DestructionTime tags'
      else
        destroy = false
      end
    else
      destroy = true
    end
    destroy ? volume.delete_volume : Chef::Log.info("volume_id=#{device_id} not destroyed because it is not time yet")
  end
end

action :wait do
  converge_by("waiting for volume_id=#{new_resource.volume_id} to #{new_resource.wait_for}") do
    aws = { :access_key_id => new_resource.access_key_id, :secret_access_key => new_resource.secret_access_key }
    new_volume_id = get_volume_status(aws, new_resource.volume_id)
    creating = 0
    until new_volume_id[:status] == (new_resource.wait_for == 'create' ? 'available' : 'in-use')
      if creating > new_resource.timeout
        Chef::Log.error("volume_id=#{new_volume_id[:id]} has been in the #{new_resource.wait_for}ing state too long.")
        break
      end
      sleep 5
      new_volume_id = get_volume_status(aws, new_resource.volume_id)
      creating += 5
    end
  end
end
