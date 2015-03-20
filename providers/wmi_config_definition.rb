def whyrun_supported?
    true
end

use_inline_resources

action :create do
  if @current_resource.exists
    Chef::Log.info "#{ @new_resource } already exists - does it need updating?."
    if @current_resource.different
      converge_by("Update #{@new_resource}") do
        update_wmi_config_definition
        new_resource.updated_by_last_action(true)
      end
    else
        Chef::Log.info "#{@new_resource} hasn't changed - nothing to do."
    end
  else
    converge_by("Create #{ @new_resource }") do
      create_wmi_config_definition
      new_resource.updated_by_last_action(true)
    end
  end
end

action :create_if_missing do
  if @current_resource.exists
    Chef::Log.info "#{ @new_resource } already exists - nothing to do."
  else
    converge_by("Create #{ @new_resource }") do
      create_wmi_config_definition
      new_resource.updated_by_last_action(true)
    end
  end
end

action :delete do
  if !@current_resource.exists
    Chef::Log.info "#{ @new_resource } doesn't exist - nothing to do."
  else
    converge_by("Delete #{ @new_resource }") do
      delete_wmi_config_definition
      new_resource.updated_by_last_action(true)
    end
  end
end

def load_current_resource
  @current_resource = Chef::Resource::OpennmsWmiConfigDefinition.new(@new_resource.name)
  @current_resource.name(@new_resource.name)
  @current_resource.retry_count(@new_resource.retry_count)
  @current_resource.timeout(@new_resource.timeout)
  @current_resource.username(@new_resource.username)
  @current_resource.domain(@new_resource.domain)
  @current_resource.password(@new_resource.password)

  @current_resource.ranges(@new_resource.ranges)
  @current_resource.specifics(@new_resource.specifics)
  @current_resource.ip_matches(@new_resource.ip_matches)

  file = ::File.new("#{node['opennms']['conf']['home']}/etc/wmi-config.xml", "r")
  contents = file.read
  file.close

  doc = REXML::Document.new(contents, { :respect_whitespace => :all })
  doc.context[:attribute_quote] = :quote 
  def_el = matching_def(doc, @current_resource.retry_count,
                        @current_resource.timeout, 
                        @current_resource.username, 
                        @current_resource.domain, 
                        @current_resource.password)
   if !def_el.nil?
     @current_resource.exists = true
     if ranges_equal?(def_el, @current_resource.ranges)\
     && specifics_equal?(def_el, @current_resource.specifics)\
     && ip_matches_equal?(def_el, @current_resource.ip_matches)
       @current_resource.different = false
     else
       @current_resource.different = true
     end
  else
     @current_resource.different = true
  end
end


private

def matching_def(doc, retry_count, timeout, username, domain, password)

  definition = nil
  doc.elements.each("/wmi-config/definition") do |def_el|
    if "#{def_el.attributes['retry']}" == "#{retry_count}"\
    && "#{def_el.attributes['timeout']}" == "#{timeout}"\
    && "#{def_el.attributes['username']}" == "#{username}"\
    && "#{def_el.attributes['domain']}" == "#{domain}"\
    && "#{def_el.attributes['password']}"== "#{password}"
      definition =  def_el
      break
    end
  end
  definition
end

def ranges_equal?(def_el, ranges)
  return true if def_el.elements["range"].nil? && (ranges.nil? || ranges.length == 0)
  curr_ranges = {}
  def_el.elements.each('range') do |r_el|
    curr_ranges[r_el.attributes['begin']] = r_el.attributes['end']
  end
  return curr_ranges == ranges
end

def specifics_equal?(def_el, specifics)
  Chef::Log.debug("Check for no specifics: #{def_el.elements["specific"].nil?} && #{specifics}")
  return true if def_el.elements["specific"].nil? && (specifics.nil? || specifics.length == 0)
  curr_specifics = []
  def_el.elements.each("specific") do |specific|
    curr_specifics.push specific.text
  end
  curr_specifics.sort!
  Chef::Log.debug("specifics equal? #{curr_specifics} == #{specifics}")
  sorted_specifics = nil
  sorted_specifics = specifics.sort unless specifics.nil?
  return curr_specifics == sorted_specifics
end

def ip_matches_equal?(def_el, ip_matches)
  Chef::Log.debug("Check for no ip_matches: #{def_el.elements["ip-match"].nil?} && #{ip_matches.nil?}")
  return true if def_el.elements["ip-match"].nil? && (ip_matches.nil? || ip_matches.length == 0)
  curr_ipm = []
  def_el.elements.each("ip-match") do |ipm|
    curr_ipm.push ipm.text
  end
  curr_ipm.sort!
  Chef::Log.debug("ip matches equal? #{curr_ipm} == #{ip_matches}")
  sorted_ipm = nil
  sorted_ipm = ip_matches.sort unless ip_matches.nil?
  return curr_ipm == sorted_ipm
end

def create_wmi_config_definition
  Chef::Log.debug "Creating wmi config definition : '#{ new_resource.name }'"
  file = ::File.new("#{node['opennms']['conf']['home']}/etc/wmi-config.xml", "r")
  contents = file.read
  file.close
  doc = REXML::Document.new(contents, { :respect_whitespace => :all })
  doc.context[:attribute_quote] = :quote 

  definition_el = nil
  if new_resource.position == "bottom"
    definition_el = doc.root.add_element 'definition'
  else
    first_def = doc.elements["/wmi-config/definition[1]"]
    if first_def.nil?
      definition_el = doc.root.add_element 'definition'
    else
      definition_el = REXML::Element.new 'definition'
      doc.root.insert_before(first_def, definition_el)
    end
  end
  definition_el.attributes['retry'] = new_resource.retry_count if !new_resource.retry_count.nil?
  definition_el.attributes['timeout'] = new_resource.timeout if !new_resource.timeout.nil?
  definition_el.attributes['username'] = new_resource.username if !new_resource.username.nil?
  definition_el.attributes['domain'] = new_resource.domain if !new_resource.domain.nil?
  definition_el.attributes['password'] = new_resource.password if !new_resource.password.nil?
  if !new_resource.ranges.nil?
    new_resource.ranges.each do |r_begin, r_end|
      definition_el.add_element 'range', {'begin' => r_begin, 'end' => r_end}
    end
  end
  if !new_resource.specifics.nil?
    new_resource.specifics.each do |specific|
      sel = definition_el.add_element 'specific'
      sel.add_text(specific)
    end
  end
  if !new_resource.ip_matches.nil?
    new_resource.ip_matches.each do |ip_match|
      ipm_el = definition_el.add_element 'ip-match'
      ipm_el.add_text(ip_match)
    end
  end
  out = ""
  formatter = REXML::Formatters::Pretty.new(2)
  formatter.compact = true
  formatter.write(doc, out)
  ::File.open("#{node['opennms']['conf']['home']}/etc/wmi-config.xml", "w"){ |file| file.puts(out) }
end

def update_wmi_config_definition
  Chef::Log.debug "Updating wmi config definition : '#{ new_resource.name }'"
  file = ::File.new("#{node['opennms']['conf']['home']}/etc/wmi-config.xml", "r")
  contents = file.read
  file.close
  doc = REXML::Document.new(contents, { :respect_whitespace => :all })
  doc.context[:attribute_quote] = :quote 

  def_el = matching_def(doc, new_resource.retry_count,
                        new_resource.timeout,
                        new_resource.username,
                        new_resource.domain,
                        new_resource.password)

  # put the new ones in
  if !new_resource.ranges.nil?
    new_resource.ranges.each do |r_begin, r_end|
      if !def_el.nil? && def_el.elements["range[@begin = '#{r_begin}' and @end = '#{r_end}']"].nil?
        def_el.add_element 'range', {'begin' => r_begin, 'end' => r_end}
      end
    end
  end
  if !new_resource.specifics.nil?
    new_resource.specifics.each do |specific|
      if def_el.elements["specific[text() = '#{specific}']"].nil?
        sel = def_el.add_element 'specific'
        sel.add_text(specific)
      end
    end
  end
  if !new_resource.ip_matches.nil?
    new_resource.ip_matches.each do |ip_match|
      if def_el.elements["ip-match[text() = '#{ip_match}']"].nil?
        ipm_el = def_el.add_element 'ip-match'
        ipm_el.add_text(ip_match)
      end
    end
  end

  out = ""
  formatter = REXML::Formatters::Pretty.new(2)
  formatter.compact = true
  formatter.write(doc, out)
  ::File.open("#{node['opennms']['conf']['home']}/etc/wmi-config.xml", "w"){ |file| file.puts(out) }
end

def delete_wmi_config_definition
  Chef::Log.info "Deleting wmi config definition : '#{ new_resource.name }'"
  file = ::File.new("#{node['opennms']['conf']['home']}/etc/wmi-config.xml", "r")
  contents = file.read
  file.close
  doc = REXML::Document.new(contents, { :respect_whitespace => :all })
  doc.context[:attribute_quote] = :quote 

  def_el = matching_def(doc, new_resource.retry_count,
                        new_resource.timeout,
                        new_resource.username,
                        new_resource.domain,
                        new_resource.password)

  doc.root.delete(def_el)

  out = ""
  formatter = REXML::Formatters::Pretty.new(2)
  formatter.compact = true
  formatter.write(doc, out)
  ::File.open("#{node['opennms']['conf']['home']}/etc/wmi-config.xml", "w"){ |file| file.puts(out) }
end
