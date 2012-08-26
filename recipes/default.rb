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

case node[:platform]
when "ubuntu", "debian"
  package "ganglia-monitor"
when "redhat", "centos", "fedora"
  include_recipe "ganglia::source"

  execute "copy ganglia-monitor init script" do
    command "cp " +
      "/usr/src/ganglia-#{node[:ganglia][:version]}/gmond/gmond.init " +
      "/etc/init.d/ganglia-monitor"
    not_if "test -f /etc/init.d/ganglia-monitor"
  end

  user "ganglia"
end

directory "/etc/ganglia"

case node[:ganglia][:unicast]
when true
  server_hosts = node[:ganglia][:server_addresses] || search(:node, "role:#{node['ganglia']['server_role']} AND chef_environment:#{node.chef_environment}").map {|node| node.ipaddress}
  if server_hosts.empty? 
     server_hosts = [ "127.0.0.1" ]
  end
  template "/etc/ganglia/gmond.conf" do
    source "gmond_unicast.conf.erb"
    variables( :cluster_name => node[:ganglia][:cluster_name],
               :server_hosts => server_hosts )
    notifies :restart, "service[ganglia-monitor]"
  end
when false
  template "/etc/ganglia/gmond.conf" do
    source "gmond.conf.erb"
    variables( :cluster_name => node[:ganglia][:cluster_name] )
    notifies :restart, "service[ganglia-monitor]"
  end
end

service "ganglia-monitor" do
  pattern "gmond"
  supports :restart => true
  action [ :enable, :start ]
end
