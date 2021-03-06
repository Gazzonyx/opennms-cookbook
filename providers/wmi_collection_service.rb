def whyrun_supported?
    true
end

use_inline_resources

action :create do
  if @current_resource.exists
    Chef::Log.info "#{ @new_resource } already exists - checking if changed."
    if @current_resource.changed
      Chef::Log.info "#{ @new_resource } has changed - updating."
      converge_by("Update #{ @new_resource }") do
        update_wmi_collection_service
        new_resource.updated_by_last_action(true)
      end
    end
  else
    converge_by("Create #{ @new_resource }") do
      create_wmi_collection_service
      new_resource.updated_by_last_action(true)
    end
  end
end

def load_current_resource
  @current_resource = Chef::Resource::OpennmsWmiCollectionService.new(@new_resource.name)
  @current_resource.name(@new_resource.name)
  @current_resource.service_name(@new_resource.service_name)
  @current_resource.package_name(@new_resource.package_name)
  @current_resource.collection(@new_resource.collection)
  @current_resource.interval(@new_resource.interval)
  @current_resource.user_defined(@new_resource.user_defined)
  @current_resource.status(@new_resource.status)
  @current_resource.timeout(@new_resource.timeout)
  @current_resource.retry_count(@new_resource.retry_count)
  @current_resource.port(@new_resource.port) unless @new_resource.port.nil?
  @current_resource.thresholding_enabled(@new_resource.thresholding_enabled)

  if service_exists?(@current_resource.package_name,
                     @current_resource.collection,
                     @current_resource.name)
     @current_resource.exists = true
     if service_changed?(@current_resource.service_name,
                         @current_resource.package_name,
                         @current_resource.collection,
                         @current_resource.interval,
                         @current_resource.user_defined,
                         @current_resource.status,
                         @current_resource.timeout,
                         @current_resource.retry_count,
                         @current_resource.port,
                         @current_resource.thresholding_enabled)
       @current_resource.changed = true
     end
  end
end


private

def service_exists?(package_name, collection, service_name)
  Chef::Log.debug "Checking to see if this wmi collection service exists: '#{ service_name }'"
  file = ::File.new("#{node['opennms']['conf']['home']}/etc/collectd-configuration.xml", "r")
  doc = REXML::Document.new file
  !doc.elements["/collectd-configuration/package[@name='#{package_name}']/service[@name='#{service_name}']/parameter[@key='collection' and @value='#{collection}']"].nil?
end

# assumes exists
def service_changed?(service_name, package_name, collection, interval,
                    user_defined, status, timeout, retry_count, port,
                    thresholding_enabled)
  Chef::Log.debug "Checking to see if this wmi collection service has changed: '#{ service_name }'"
  file = ::File.new("#{node['opennms']['conf']['home']}/etc/collectd-configuration.xml", "r")
  doc = REXML::Document.new file
  service_el = doc.elements["/collectd-configuration/package[@name='#{package_name}']/service[@name='#{service_name}' and parameter[@key='collection' and @value='#{collection}']]"]
  old_interval = service_el.attributes['interval']
  Chef::Log.debug "checking interval: #{old_interval} != #{interval} ?"
  return true if "#{old_interval}" != "#{interval}"
  old_user_defined = service_el.attributes['user-defined']
  Chef::Log.debug "checking user-defined"
  return true if "#{old_user_defined}" != "#{user_defined}"
  old_status = service_el.attributes['status']
  Chef::Log.debug "checking status"
  return true if "#{old_status}" != "#{status}"
  old_timeout = service_el.elements["parameter[@key='timeout']"]
  unless old_timeout.nil?
    old_timeout = old_timeout.attributes['value']
  end
  Chef::Log.debug "checking timeout"
  return true if "#{old_timeout}" != "#{timeout}"
  old_retry_count = service_el.elements["parameter[@key='retry']"]
  unless old_retry_count.nil?
    old_retry_count = old_retry_count.attributes['value']
  end
  Chef::Log.debug "checking retry"
  return true if "#{old_retry_count}" != "#{retry_count}"
  old_port = service_el.elements["parameter[@key='port']"]
  unless old_port.nil?
    old_port = old_port.attributes['value']
  end
  Chef::Log.debug "checking port"
  return true if "#{old_port}" != "#{port}"
  old_te = service_el.elements["parameter[@key='thresholding-enabled']"]
  unless old_te.nil?
    old_te = old_te.attributes['value']
  end
  Chef::Log.debug "checking thresholding-enabled"
  return true if "#{old_te}" != "#{thresholding_enabled}"
  Chef::Log.debug "not changed!"
  false
end

def update_wmi_collection_service
  Chef::Log.debug "Updating wmi collection service: '#{ new_resource.service_name }'"
  file = ::File.new("#{node['opennms']['conf']['home']}/etc/collectd-configuration.xml")
  contents = file.read
  doc = REXML::Document.new(contents, { :respect_whitespace => :all })
  file.close

  service_el = doc.elements["/collectd-configuration/package[@name='#{new_resource.package_name}']/service[@name='#{new_resource.service_name}' and parameter[@key='collection' and @value='#{new_resource.collection}']]"]
  service_el.attributes['status'] = new_resource.status
  service_el.attributes['interval'] = new_resource.interval
  if new_resource.user_defined.nil? && !service_el.attributes['user-defined'].nil?
    service_el.attributes.delete('user-defined')
  elsif !new_resource.user_defined.nil?
    service_el.attributes['user-defined'] = new_resource.user_defined # adds or changes
  end

  port_el = service_el.elements["parameter[@key='port']"]
  if new_resource.port.nil? && !port_el.nil?
    service_el.delete port_el
  elsif !new_resource.port.nil?
    if port_el.nil?
      service_el.add_element 'parameter', { 'key' => 'port', 'value' => new_resource.port }
    else
      port_el.attributes['value'] = new_resource.port
    end
  end

  timeout_el = service_el.elements["parameter[@key='timeout']"]
  if new_resource.timeout.nil? && !timeout_el.nil?
    service_el.delete timeout_el
  elsif !new_resource.timeout.nil?
    if timeout_el.nil?
      service_el.add_element 'parameter', { 'key' => 'timeout', 'value' => new_resource.timeout }
    else
      timeout_el.attributes['value'] = new_resource.timeout
    end
  end

  retry_el = service_el.elements["parameter[@key='retry']"]
  if new_resource.retry_count.nil? && !retry_el.nil?
    service_el.delete retry_el
  elsif !new_resource.retry_count.nil?
    if retry_el.nil?
      service_el.add_element 'parameter', { 'key' => 'retry', 'value' => new_resource.retry_count }
    else
      retry_el.attributes['value'] = new_resource.retry_count
    end
  end

  thresholding_enabled_el = service_el.elements["parameter[@key='thresholding-enabled']"]
  if new_resource.thresholding_enabled.nil? && !thresholding_enabled_el.nil?
    service_el.delete thresholding_enabled_el
  elsif !new_resource.thresholding_enabled.nil?
    if thresholding_enabled_el.nil?
      service_el.add_element 'parameter', { 'key' => 'thresholding-enabled', 'value' => new_resource.thresholding_enabled }
    else
      thresholding_enabled_el.attributes['value'] = new_resource.thresholding_enabled
    end
  end

  out = ""
  formatter = REXML::Formatters::Pretty.new(2)
  formatter.compact = true
  formatter.write(doc, out)
  ::File.open("#{node['opennms']['conf']['home']}/etc/collectd-configuration.xml", "w"){ |file| file.puts(out) }
end

def create_wmi_collection_service
  Chef::Log.debug "Adding wmi collection package: '#{ new_resource.service_name }'"
  file = ::File.new("#{node['opennms']['conf']['home']}/etc/collectd-configuration.xml")
  contents = file.read
  doc = REXML::Document.new(contents, { :respect_whitespace => :all })
  file.close

  package_el = doc.elements["/collectd-configuration/package[@name='#{new_resource.package_name}']"]
  service_el = package_el.add_element 'service', { 'name' => new_resource.service_name, 'status' => new_resource.status, 'interval' => new_resource.interval }
  if !new_resource.user_defined.nil?
    service_el.add_attribute('user-defined' => new_resource.user_defined)
  end
  collection_param_el = service_el.add_element 'parameter', { 'key' => 'collection', 'value' => new_resource.collection }
  if new_resource.port
    port_el = service_el.add_element 'parameter', { 'key' => 'port', 'value' => new_resource.port }
  end
  if new_resource.timeout
    timeout_el = service_el.add_element 'parameter', { 'key' => 'timeout', 'value' => new_resource.timeout }
  end
  if new_resource.retry_count
    retries_el = service_el.add_element 'parameter', { 'key' => 'retry', 'value' => new_resource.retry_count }
  end
  if !new_resource.thresholding_enabled.nil?
    thresh_enabled_el = service_el.add_element 'parameter', { 'key' => 'thresholding-enabled', 'value' => new_resource.thresholding_enabled }
  end

  # make sure we've got a service definition at the end of the file
  if !doc.elements["/collectd-configuration/collector[@service='#{new_resource.service_name}']"]
    doc.elements["/collectd-configuration"].add_element 'collector', { 'service' => new_resource.service_name, 'class-name' => 'org.opennms.netmgt.collectd.WmiCollector' }
  end
  out = ""
  formatter = REXML::Formatters::Pretty.new(2)
  formatter.compact = true
  formatter.write(doc, out)
  ::File.open("#{node['opennms']['conf']['home']}/etc/collectd-configuration.xml", "w"){ |file| file.puts(out) }
end
