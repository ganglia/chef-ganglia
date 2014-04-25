directory "/etc/ganglia-webfrontend"


if node['ganglia']['from_source']
  include_recipe "ganglia::source"
  include_recipe "ganglia::gmetad"

  if platform?("ubuntu", "debian")
    %w[apache2 libapache2-mod-php5 rrdtool libgd2-xpm].each do |p|
      package p
    end
  elsif platform?("redhat", "centos", "fedora")
    %w[httpd php].each do |p|
      package p
    end
  end

  remote_file "/usr/src/ganglia-web-#{node['ganglia']['webfrontend_version']}.tar.gz" do
    source node['ganglia']['webfrontend_uri']
    checksum node['ganglia']['webfrontend_checksum']
  end

  execute "untar web frontend" do
    action :run
    command "tar zxvf ganglia-web-#{node['ganglia']['webfrontend_version']}.tar.gz"
    cwd "/usr/src"
  end

  execute "install web interface" do
    command "make install"
    creates "/usr/share/ganglia-webfrontend"
    cwd "/usr/src/ganglia-web-#{node['ganglia']['webfrontend_version']}"
    action :run
  end

  execute "copy apache config" do
    command "cp apache.conf /etc/ganglia-webfrontend/"
    creates "/etc/ganglia-webfrontend/apache.conf"
    cwd "/usr/src/ganglia-web-#{node['ganglia']['webfrontend_version']}"
    action :run
  end

else
  package "ganglia-webfrontend"
end

link "/etc/apache2/sites-available/ganglia" do
  to "/etc/ganglia-webfrontend/apache.conf"
end

execute "disable default site" do
  command "a2dissite default"
  action :run
  only_if { File.exists?("/etc/apache2/sites-enabled/000-default") }
  notifies :reload, "service[apache2]"
end

execute "enable ganglia site" do
  command "a2ensite ganglia"
  creates "/etc/apache2/sites-enabled/ganglia"
  action :run
  notifies :reload, "service[apache2]"
end

xml_port = if node['ganglia']['enable_two_gmetads'] then
                node['ganglia']['two_gmetads']['xml_port']
           else
                node['ganglia']['gmetad']['xml_port']
           end

template "/etc/ganglia-webfrontend/conf.php" do
  source "webconf.php.erb"
  mode "0644"
  variables( :xml_port => xml_port )
end

service "apache2" do
  service_name "httpd" if platform?( "redhat", "centos", "fedora" )
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :start ]
end
