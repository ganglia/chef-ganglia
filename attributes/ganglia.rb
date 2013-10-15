default[:ganglia][:version] = "3.1.7"
default[:ganglia][:uri] = "http://sourceforge.net/projects/ganglia/files/ganglia%20monitoring%20core/#{node[:ganglia][:version]}/ganglia-#{node[:ganglia][:version]}.tar.gz/download"
default[:ganglia][:checksum] = "bb1a4953"
default[:ganglia][:cluster_name] = "default"
default[:ganglia][:unicast] = false
default[:ganglia][:server_role] = "ganglia"
