directory "/etc/ganglia-webfrontend"

case node['platform']
when "ubuntu", "debian"
  package "ganglia-webfrontend"

  link "/etc/apache2/sites-enabled/001-ganglia.conf" do
    to "/etc/ganglia-webfrontend/apache.conf"
    notifies :restart, "service[apache2]"
  end

when "redhat", "centos", "fedora"
  case node['ganglia']['install_method']
  when 'package'
    include_recipe 'yum-epel'
    package 'ganglia-web'
  when 'source'
    package "httpd"
    package "php"
    include_recipe "ganglia::source"
    include_recipe "ganglia::gmetad"

    execute "copy web directory" do
      command "cp -r web /var/www/html/ganglia"
      creates "/var/www/html/ganglia"
      cwd "/usr/src/ganglia-#{node['ganglia']['version']}"
  end
  else
    fail "Unknown ganglia install method for #{node['platform']}: #{node['ganglia']['install_method']}"
  end
end

if node['ganglia']['web']['auth_system'] == "enabled"
  if Chef::Config[:solo]
    if node['ganglia']['ganglia_secret'].nil?
      Chef::Application.fatal! "You must set node['ganglia']['ganglia_secret'] in chef-solo mode." 
    end
  else
    require 'digest'
    node.set_unless['ganglia']['ganglia_secret'] = Digest::SHA1.hexdigest(srand().to_s)
    node.save
  end
  template '/etc/ganglia-webfrontend/ganglia-auth.conf' do
    source 'ganglia_auth.conf.erb'
    mode 0644
  end

  link "/etc/apache2/sites-enabled/ganglia-auth.conf" do
    to "/etc/ganglia-webfrontend/ganglia-auth.conf"
    notifies :restart, "service[apache2]"
  end

  users = search(:users, "ganglia:* AND password:*")

  template "#{node['ganglia']['web']['htpasswd_path']}htpasswd.users" do
    source "htpasswd.users.erb"
    mode 0644
    variables(:users => users)
    notifies :restart, "service[apache2]"
  end
end

interactive_port = if node['ganglia']['enable_two_gmetads'] then
                node['ganglia']['two_gmetads']['interactive_port']
           else
                node['ganglia']['gmetad']['interactive_port']
           end
template "/etc/ganglia-webfrontend/conf.php" do
  source "webconf.php.erb"
  mode "0644"
  variables( :interactive_port => interactive_port, :users => users.nil? ? '' : users )
end

service "apache2" do
  service_name "httpd" if platform?( "redhat", "centos", "fedora" )
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :start ]
end
