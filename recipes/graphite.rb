include_recipe "xml"
package "libxslt-dev"
gem_package "nokogiri"

if graphite_role = node['graphite']['server_role']
  graphite_host = search(:node, "role:#{graphite_role} AND chef_environment:#{node.chef_environment}").map {|node| node.ipaddress}
end
if graphite_host.nil? or graphite_host.empty?
  graphite_host = "localhost"
end

template "/usr/local/sbin/ganglia_graphite.rb" do
  source "ganglia_graphite.rb.erb"
  mode "744"
  variables :graphite_host => graphite_host
end

cron "ganglia_graphite" do
  command "/usr/local/sbin/ganglia_graphite.rb"
end

