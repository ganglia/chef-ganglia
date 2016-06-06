#
# Cookbook Name:: ganglia
# Recipe:: default
#
# Copyright 2011, Heavy Water Software Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

case node['platform']
when "ubuntu", "debian"
  package "ganglia-monitor"
when "redhat", "centos", "fedora"
  user "ganglia"
  case node['ganglia']['install_method']
  when 'package'
    include_recipe 'yum-epel'
    package 'ganglia-gmond'
  when 'source'
    # Migrate the ganglia-monitor service to gmond for old installs
    old_init_script = '/etc/init.d/ganglia-monitor'
    execute "#{old_init_script} stop" do
      only_if { ::File.exist? old_init_script }
    end

    file old_init_script do
      action :delete
    end

    include_recipe "ganglia::source"

    execute "copy ganglia-monitor init script" do
      command "cp " +
        "/usr/src/ganglia-#{node['ganglia']['version']}/gmond/gmond.init " +
      "/etc/init.d/gmond"
      creates "/etc/init.d/gmond"
    end
  else
    fail "Unknown ganglia install method for #{node['platform']}: #{node['ganglia']['install_method']}"
  end
end

directory "/etc/ganglia"

# figure out which cluster(s) we should join
# this section assumes you can send to multiple ports.
ports=[]
clusternames = []
node['ganglia']['host_cluster'].each do |k,v|
  if (v == 1 and node['ganglia']['clusterport'].has_key?(k))
    ports.push(node['ganglia']['clusterport'][k])
    clusternames.push(k)
  end
end
if ports.empty?
  ports.push(node['ganglia']['clusterport']['default'])
  clusternames.push('default')
end


execute 'copy gmond.conf' do
  command 'cp /etc/ganglia/gmond.conf /etc/ganglia/gmond-example.conf'
  creates '/etc/ganglia/gmond-example.conf'
end

if node['ganglia']['unicast']
  # fill in the gmond collectors by attribute if it exists, search if you find anything, or localhost.
  gmond_collectors = []
  if node['ganglia']['server_host']
    gmond_collectors = [node['ganglia']['server_host']]
  elsif gmond_collectors.empty?
    if Chef::Config[:solo]
      Chef::Log.warn('This recipe uses search. Chef Solo does not support search.')
      Chef::Log.warn('Defaulting to localhost collector.')
      gmond_collectors = ["127.0.0.1"]
    else
      gmond_collectors = search(:node, "role:#{node['ganglia']['server_role']} AND chef_environment:#{node.chef_environment}").map {|node| node['ipaddress']}.compact
    end
  end rescue NoMethodError
  if not gmond_collectors.any?
     gmond_collectors = ["127.0.0.1"]
  end

  ports.each do |port|
    gmond_collectors.each do |collector|
      send_conf = node['ganglia']['gmond_default']['unicast_udp_send_channel'].to_hash
      send_conf.merge!({port: port, host: collector})
      node.default['ganglia']['gmond']["udp_send_channel##{collector}_#{port}"] = send_conf
    end
    recv_conf = { port: port}
    node.default['ganglia']['gmond']["udp_recv_channel##{port}"] = recv_conf
  end

  # always connect to localhost
  node.default['ganglia']['gmond']['udp_send_channel#localhost_8649'] = { ttl: 1, port: 8649, host: '127.0.0.1' }

else # multicast

  ports.each do |port|
    send_conf = node['ganglia']['gmond_default']['multicast_udp_send_channel'].to_hash
    send_conf.merge!(port: port)
    node.default['ganglia']['gmond']["udp_send_channel##{port}"] = send_conf
    recv_conf = node['ganglia']['gmond_default']['multicast_udp_recv_channel'].to_hash
    recv_conf.merge!(port: port)
    node.default['ganglia']['gmond']["udp_recv_channel##{port}"] = recv_conf
  end
end

node.default['ganglia']['gmond']['cluster']['name'] = clusternames.first

if node['ganglia']['spoof_hostname']
  node.default['ganglia']['gmond']['globals']['override_hostname'] = node['hostname']
end

common_vars = {
  sections: node['ganglia']['gmond'].to_hash,
  ports: ports,
}

template "/etc/ganglia/gmond.conf" do
  source "gmond.conf.erb"
  variables common_vars
  notifies :restart, "service[ganglia-monitor]"
end

service "ganglia-monitor" do
  if platform_family?('rhel')
    service_name 'gmond'
  else
    pattern 'gmond'
    provider Chef::Provider::Service::Upstart if (platform?('ubuntu') && node.platform_version.include?('14'))
  end
  supports :restart => true
  action [ :enable, :start ]
end
