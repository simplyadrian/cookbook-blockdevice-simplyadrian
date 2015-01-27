::Chef::Recipe.send(:include, Nativex::Blockdevice::Instance)

# Support whyrun
def whyrun_supported?
  true
end

action :detach do
  converge_by("Detaching volume where id=#{new_resource.volume_id}#{new_resource.force ? ' forcefully' : ''}") do
    volume = @ec2.volumes[new_resource.volume_id]
    volume.attachments.each do |attachment|
      attachment.delete(:force => new_resource.force)
    end
    sleep 1 until volume.status == :available
  end
end

action :attach do
  converge_by("Attaching volume where id=#{new_resource.volume_id} to instance id=#{instance_id}") do
    volume = @ec2.volumes[new_resource.volume_id]
    attachment = volume.attach_to(ec2.instances[new_resource.instance_id], new_resource.device)
    sleep 1 until attachment.status != :attaching
  end
end

action :delete do
  # TODO: Delete volume logic
end