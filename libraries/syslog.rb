require 'rexml/document'

module Syslog
  def syslog_file_included?(name, node)
    Chef::Log.debug "Checking to see if this syslog file exists: '#{ name }'"
    file = ::File.new("#{node['opennms']['conf']['home']}/etc/syslogd-configuration.xml", "r")
    doc = REXML::Document.new file
    !doc.elements["/syslogd-configuration/import-file[text() == 'syslog/#{name}' and not(text()[2])]"].nil?
  end

  def syslog_file_exists?(name, node)
    ::File.exist?("#{node['opennms']['conf']['home']}/etc/syslog/#{name}")
  end

  def syslog_file_included?(name, node)
    Chef::Log.debug "Checking to see if this syslog file exists: '#{ name }'"
    file = ::File.new("#{node['opennms']['conf']['home']}/etc/syslogd-configuration.xml", "r")
    doc = REXML::Document.new file
    !doc.elements["/syslogd-configuration/import-file[text() == 'syslog/#{name}' and not(text()[2])]"].nil?
  end

  def add_file_to_syslog(file, position, node)
    if file =~ /^syslog\/(.*)$/ 
      file = $1
    end
    f = ::File.new("#{node['opennms']['conf']['home']}/etc/syslogd-configuration.xml")
    contents = f.read
    doc = REXML::Document.new(contents, { :respect_whitespace => :all })
    doc.context[:attribute_quote] = :quote
    f.close

    root_el = doc.root
    config_el = doc.root.elements["/syslogd-configuration/configuration"]
    ueilist_el = doc.root.elements["/syslogd-configuration/ueiList"]
    hide_el = doc.root.elements["/syslogd-configuration/hideMessage"]

    import_file_el = REXML::Element.new('import-file')
    import_file_el.add_text(REXML::CData.new("syslog/#{file}"))

    if position == 'top'
        root_el.insert_after(config_el, import_file_el)
    else
      last_import_el = root_el.elements["import-file[last()]"]
      if last_import_el.nil?
        if hide_el.nil? && ueilist_el.nil?
          root_el.insert_after(config_el, import_file_el)
        elsif hide_el.nil?
          root_el.insert_after(ueilist_el, import_file_el)
        else
          root_el.insert_after(hide_el, import_file_el)
        end
      else
        root_el.insert_after(last_import_el, import_file_el)
      end
    end
    out = ""
    formatter = REXML::Formatters::Pretty.new(2)
    formatter.compact = true
    formatter.write(doc, out)
    ::File.open("#{node['opennms']['conf']['home']}/etc/syslogd-configuration.xml", "w"){ |f| f.puts(out) }
  end
end
