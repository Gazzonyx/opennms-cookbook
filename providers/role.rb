include Rbac
def whyrun_supported?
    true
end

use_inline_resources

action :create do
  Chef::Application.fatal!("Missing group  #{@current_resource.membership_group}.") if !@current_resource.group_exists
  Chef::Application.fatal!("Missing user  #{@current_resource.supervisor}.") if !@current_resource.supervisor_exists
  if @current_resource.exists
    Chef::Log.info "#{ @new_resource } already exists - nothing to do."
  else
    converge_by("Create #{ @new_resource }") do
      create_role
      new_resource.updated_by_last_action(true)
    end
  end
end

def load_current_resource
  @current_resource = Chef::Resource::OpennmsRole.new(@new_resource.name)
  @current_resource.name(@new_resource.name)
  @current_resource.membership_group(@new_resource.membership_group)
  @current_resource.supervisor(@new_resource.supervisor)

  if role_exists?(@current_resource.name, node)
    @current_resource.exists = true
  end
  if group_exists?(@current_resource.membership_group, node)
    @current_resource.group_exists = true
  end
  if user_exists?(@current_resource.supervisor, node)
    @current_resource.supervisor_exists = true
  end
end

private


def create_role
  add_role(new_resource, node)
end
