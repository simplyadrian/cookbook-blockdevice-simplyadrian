::Chef::Recipe.send(:include, Nativex::Blockdevice::Helpers)

# Support whyrun
def whyrun_supported?
  true
end

action :detach do
  converge_by("Detaching volume where id=#{new_resource.volume_id}#{new_resource.force ? ' forcefully' : ''}") do
    volume = ec2_auth.volumes[new_resource.volume_id]
    volume.attachments.each do |attachment|
      attachment.delete(:force => new_resource.force)
    end
    sleep 1 until volume.status == :available
  end
end

action :attach do
  converge_by("Attaching volume where id=#{new_resource.volume_id} to instance id=#{new_resource.instance_id}") do
    volume = ec2_auth.volumes[new_resource.volume_id]
    attachment = volume.attach_to(ec2_auth.instances[new_resource.instance_id], new_resource.device)
    sleep 1 until attachment.status != :attaching
  end
end

action :delete do
  converge_by("Deleting volume where id=#{new_resource.volume_id}") do
    volume = ec2_auth.volumes[new_resource.volume_id]
    destroy = false
    if new_resource.retention_check
        # Delete volumes tag for deletion older then x hours or delete right away if y = true
        if :Destroy && :DestructionTime < Time
          # Destroy volume(s)
          ## Maybe the could be put in the default recipe since restore_from_snapshot might not always be assigned. Further thinking,
          ## maybe make this a resource that this recipe and the default recipe can access.
          destroy = true
        end
    else
      destroy = true
    end
    destroy ? volume.delete_volume : Chef::Log.info("I did not destroy volume id=#{device_id} because it is not time yet")
  end
end