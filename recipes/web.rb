directory "/etc/ganglia-webfrontend"

include_recipe "apache2"

if node[:ganglia][:server_auth_method] == "openid"
then
  include_recipe "apache2::mod_auth_openid"
end

case node[:platform]
when "ubuntu", "debian"
  package "ganglia-webfrontend"
  conf_file = "/etc/apache2/sites-enabled/ganglia"
  content_location = "/usr/share/ganglia-webfrontend"

when "redhat", "centos", "fedora"
  package "httpd"
  package "php"
  include_recipe "ganglia::source"
  include_recipe "ganglia::gmetad"

  execute "copy web directory" do
    command "cp -r web /var/www/html/ganglia"
    creates "/var/www/html/ganglia"
    cwd "/usr/src/ganglia-#{node[:ganglia][:version]}"
  end
  conf_file = "/etc/httpd/sites-enabled/ganglia"
  content_location = "/var/www/html/ganglia"
end

template "/etc/ganglia-webfrontend/apache.conf" do
  source "apache.conf.erb"
  mode 00644
  variables(
    :content_location => content_location
  )
  notifies :reload, "service[apache2]"
end

link conf_file do
  to "/etc/ganglia-webfrontend/apache.conf"
  notifies :restart, "service[apache2]"
end

service "apache2" do
  service_name "httpd" if platform?( "redhat", "centos", "fedora" )
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :start ]
end
