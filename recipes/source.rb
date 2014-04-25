if platform?( "redhat", "centos", "fedora" )
  %w[apr-devel libconfuse-devel expat-devel rrdtool-devel].each do |p|
    package p
  end
elsif platform?("ubuntu", "debian")
  %w[build-essential libconfuse-dev librrd-dev libexpat1-dev libapr1-dev].each do |p|
    package p
  end
end

remote_file "/usr/src/ganglia-#{node['ganglia']['version']}.tar.gz" do
  source node['ganglia']['uri']
  checksum node['ganglia']['checksum']
end

src_path = "/usr/src/ganglia-#{node['ganglia']['version']}"

execute "untar ganglia" do
  command "tar xzf ganglia-#{node['ganglia']['version']}.tar.gz"
  creates src_path
  cwd "/usr/src"
end

execute "configure ganglia build" do
  command "./configure --with-gmetad --with-libpcre=no --sysconfdir=/etc/ganglia --prefix=/usr"
  creates "#{src_path}/config.log"
  cwd src_path
end

execute "build ganglia" do
  command "make"
  creates "#{src_path}/gmond/gmond"
  cwd src_path
end

execute "install ganglia" do
  command "make install"
  creates "/usr/sbin/gmond"
  cwd src_path
end

link "/usr/lib/ganglia" do
  to "/usr/lib64/ganglia"
  only_if do
    node['kernel']['machine'] == "x86_64" and
      platform?( "redhat", "centos", "fedora" )
  end
end
