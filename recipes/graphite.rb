template "/usr/local/sbin/ganglia_graphite.rb" do
  source "ganglia_graphite.rb.erb"
end

cron "ganglia_graphite" do
  command "/usr/local/sbin/ganglia_graphite.rb"
end
