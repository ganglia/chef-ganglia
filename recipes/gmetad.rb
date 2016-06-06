case node['platform']
when "ubuntu", "debian"
  package "gmetad"
when "redhat", "centos", "fedora"
  case node['ganglia']['install_method']
  when 'package'
    include_recipe 'yum-epel'
    package 'ganglia-gmetad'
  when 'source'
    include_recipe "ganglia::source"
    execute "copy gmetad init script" do
      command "cp " +
        "/usr/src/ganglia-#{node['ganglia']['version']}/gmetad/gmetad.init " +
      "/etc/init.d/gmetad"
      not_if "test -f /etc/init.d/gmetad"
    end
  else
    fail "Unknown ganglia install method for #{node['platform']}: #{node['ganglia']['install_method']}"
  end
end

execute 'copy gmetad.conf' do
  command 'cp /etc/ganglia/gmetad.conf /etc/ganglia/gmetad-example.conf'
  creates '/etc/ganglia/gmetad-example.conf'
end

directory "/var/lib/ganglia/rrds" do
  owner node['ganglia']['user']
  recursive true
end
if node['ganglia']['enable_two_gmetads']
  directory node['ganglia']['two_gmetads']['empty_rrd_rootdir'] do
    owner node['ganglia']['user']
    recursive true
  end
end

# if we should use rrdcached, set it up here.
if node['ganglia']['enable_rrdcached'] == true
  package "rrdcached" do
    action :install
  end
  include_recipe "runit"
  runit_service "rrdcached" do
    template_name "rrdcached"
    options({
      :user => node['ganglia']['rrdcached']['user'],
      :main_socket => node['ganglia']['rrdcached']['main_socket'],
      :limited_socket => node['ganglia']['rrdcached']['limited_socket'],
      :ganglia_rrds => node['ganglia']['rrdcached']['ganglia_rrds'],
      :timeout => node['ganglia']['rrdcached']['timeout'],
      :delay => node['ganglia']['rrdcached']['delay'],
      }
    )
  end
  # install socat to make it easy to talk to rrdcached for diagnostics.
  package "socat" do
    action :install
  end
end

case node['ganglia']['unicast']
when true
  if Chef::Config[:solo]
    Chef::Log.warn('This recipe uses search. Chef Solo does not support search.')
    Chef::Log.warn('Defaulting to localhost collector.')
    gmond_collectors = ['127.0.0.1']
  else
    gmond_collectors = search(:node, "role:#{node['ganglia']['server_role']} AND chef_environment:#{node.chef_environment}").map {|node| node['ipaddress']}
  end
  if gmond_collectors.empty?
    gmond_collectors = ['127.0.0.1']
  end

  clusters = node['ganglia']['clusterport'].to_hash.map do |cluster,port|
    [cluster, gmond_collectors.map { |n| "#{n}:#{port}" }]
  end
  clusters = Hash[clusters]

  template "/etc/ganglia/gmetad.conf" do
    source "gmetad.conf.erb"
    variables( :clusters => clusters,
               :grid_name => node['ganglia']['grid_name'],
               :params => node['ganglia']['gmetad'].to_hash.reject {|k,v| v.nil? },
               :rrd_rootdir => node['ganglia']['rrd_rootdir'],
             )
    notifies :restart, "service[gmetad]"
  end
  if node['ganglia']['enable_two_gmetads']
    template "/etc/ganglia/gmetad-norrds.conf" do
      source "gmetad.conf.erb"
      variables( :clusters => clusters,
                 :params => {
                   :xml_port => node['ganglia']['two_gmetads']['xml_port'],
                   :interactive_port => node['ganglia']['two_gmetads']['interactive_port'],
                   :write_rrds => "off",
                 },
                 :rrd_rootdir => node['ganglia']['two_gmetads']['empty_rrd_rootdir'],
                 :grid_name => node['ganglia']['grid_name'])
      notifies :restart, "service[gmetad-norrds]"
    end
  end
  if node['recipes'].include? "iptables"
    include_recipe "ganglia::iptables"
  end
when false
  if Chef::Config[:solo]
    Chef::Log.warn('This recipe uses search. Chef Solo does not support search.')
    raise 'ganglia clustering requires search.'
  end
  clusters = node['ganglia']['clusterport'].to_hash.map do |cluster,port|
    ips = search(:node, "ganglia_host_cluster_#{cluster}:1").map do |node|
      "#{node['ipaddress']}:#{port}"
    end
    [cluster, ips]
  end
  clusters = Hash[clusters]

  template "/etc/ganglia/gmetad.conf" do
    source "gmetad.conf.erb"
    variables( :clusters => clusters,
               :params => node['ganglia']['gmetad'].to_hash.reject {|k,v| v.nil? },
               :grid_name => node['ganglia']['grid_name'],
               :rrd_rootdir => node['ganglia']['rrd_rootdir'],
             )
    notifies :restart, "service[gmetad]"
  end
end

# drop in our own gmetad init script to enable rrdcached if appropriate
if node['ganglia']['enable_rrdcached'] == true
  template "/etc/init.d/gmetad" do
    source "gmetad-startscript.erb"
     mode "0755"
     variables( :gmetad_name => "gmetad" )
     notifies :restart, "service[gmetad]"
  end
end

service "gmetad" do
  supports :restart => true
  action [ :enable, :start ]
end

if node['ganglia']['enable_two_gmetads']
  template "/etc/init.d/gmetad-norrds" do
    source "gmetad-startscript.erb"
    mode "0755"
    variables( :gmetad_name => "gmetad-norrds" )
    notifies :restart, "service[gmetad-norrds]"
  end
  service "gmetad-norrds" do
    supports :restart => true
    action [ :enable, :start ]
  end
end
