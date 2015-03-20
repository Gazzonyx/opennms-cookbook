def whyrun_supported?
      true
end

use_inline_resources

action :run do
  converge_by("Run #{ @new_resource }") do
    send_event
    new_resource.updated_by_last_action(true)
  end
end

#action :nothing do
#  new_resource.updated_by_last_action(false)
#end

def load_current_resource
  @current_resource = Chef::Resource::OpennmsSendEvent.new(@new_resource.name)
  @current_resource.name(@new_resource.name)
  @current_resource.uei(@new_resource.uei)
  @current_resource.parameters(@new_resource.parameters)
end

def send_event
  onms_home = node['opennms']['conf']['home']
  send_event = "#{onms_home}/bin/send-event.pl"
  cmd = "#{send_event}"
  unless new_resource.parameters.nil?
    new_resource.parameters.each do |p|
      cmd = "#{cmd} -p '#{p}'"
    end
  end
  cmd = "#{cmd} #{new_resource.uei}"
  bash "send_event_#{new_resource.name}" do
    code cmd
    user 'root'
    cwd onms_home
  end
end
