
##
## start multiple copies of gmond, one for each cluster.
##

directory 'ganglia configuration file' do
  path '/etc/ganglia'
end

node['ganglia']['clusterport'].each do |clust,port|

  sections = node['ganglia']['gmond'].to_hash
  sections = DeepMerge.merge(sections, node['ganglia']['gmond_collector'])
  sections['cluster']['name'] = clust
  sections['udp_recv_channel'] ||= {}
  sections['udp_recv_channel']['port'] = port
  sections['tcp_accept_channel'] ||= {}
  sections['tcp_accept_channel']['port'] = port

  template "/etc/ganglia/gmond_collector_#{clust}.conf" do
    source "gmond_collector.conf.erb"
    variables( :sections => sections )
    notifies :restart, "service[ganglia-monitor-#{clust}]"
  end
  template "/etc/init.d/ganglia-monitor-#{clust}" do
    source "gmond_collector-startscript.erb"
    variables( :cluster_name => clust)
    mode 0755
    notifies :restart, "service[ganglia-monitor-#{clust}]"
  end
  service "ganglia-monitor-#{clust}" do
    pattern "gmond_collector_#{clust}.conf"
    supports :restart => true
    action [ :enable, :start ]
  end
end

# we need all the packgages installed and so on.  also, this node should have
# its own ganglia client.
include_recipe "ganglia::default"

