case node[:platform]
when "ubuntu", "debian"
  package "ganglia-webfrontend"

  link "/etc/apache2/sites-enabled/ganglia" do
    to "/etc/ganglia-webfrontend/apache.conf"
    notifies :restart, "service[apache2]"
  end
  
when "redhat", "centos", "fedora"
  package "httpd"
  package "php"
  include_recipe "ganglia::source"

  execute "copy gmetad init script" do
    command "cp " +
      "/usr/src/ganglia-#{node[:ganglia][:version]}/gmetad/gmetad.init " +
      "/etc/init.d/gmetad"
    not_if "test -f /etc/init.d/gmetad"
  end

  execute "copy web directory" do
    command "cp -r web /var/www/html/ganglia"
    creates "/var/www/html/ganglia"
    cwd "/usr/src/ganglia-#{node[:ganglia][:version]}"
  end

  directory "/var/lib/ganglia/rrds" do
    owner "nobody"
    group "nobody"
    recursive true
  end
end

directory "/etc/ganglia-webfrontend"

ips = search(:node, "recipes:ganglia").map {|node| node.ipaddress}

template "/etc/ganglia/gmetad.conf" do
  source "gmetad.conf.erb"
  variables( :hosts => ips.join(" ") )
  notifies :restart, "service[gmetad]"
end

service "gmetad" do
  supports :restart => true
  action [ :enable, :start ]
end

service "apache2" do
  service_name "httpd" if platform?( "redhat", "centos", "fedora" )
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :start ]
end
