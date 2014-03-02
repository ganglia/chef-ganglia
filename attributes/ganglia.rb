default[:ganglia][:version] = "3.1.7"
default[:ganglia][:uri] = "http://sourceforge.net/projects/ganglia/files/ganglia%20monitoring%20core/3.1.7/ganglia-3.1.7.tar.gz/download"
default[:ganglia][:checksum] = "bb1a4953"
default[:ganglia][:cluster_name] = "default"
default[:ganglia][:unicast] = false
default[:ganglia][:server_role] = "ganglia"
default[:ganglia][:user] = "nobody"

# attributes relevant to rrdcached
default[:ganglia][:enable_rrdcached] = true
# what user should rrdcached run as?
# this should be the same as the user running gmetad
default[:ganglia][:rrdcached][:user] = node[:ganglia][:user]
# use this socket for gmetad
default[:ganglia][:rrdcached][:main_socket] = "/tmp/rrdcached.sock"
# use this socket for the web ui
default[:ganglia][:rrdcached][:limited_socket] = "/tmp/rrdacached_limited.sock"
# where do the ganglia rrds live
default[:ganglia][:rrdcached][:ganglia_rrds] = "/var/lib/ganglia/rrds"

# attributes for web configuration
# whether to use authentication: options 'disabled', 'readonly', and 'enabled'
default[:ganglia][:web][:auth_system] = 'disabled'