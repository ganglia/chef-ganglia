require 'spec_helper'

describe 'ganglia::default' do
  let(:chef_run) do
    runner = ChefSpec::Runner.new(
      platform: 'ubuntu',
      version: '12.04'
    )
    runner.converge(described_recipe)
  end

  it 'creates the ganglia directory' do
    expect(chef_run).to create_directory('/etc/ganglia')
  end
  it 'installs the ganglia monitor package' do
    expect(chef_run).to install_package('ganglia-monitor')
  end

  it 'starts the ganglia-monitor service' do
    expect(chef_run).to start_service('ganglia-monitor')
  end

  context "multicast mode" do
    let(:chef_run) do
      runner = ChefSpec::Runner.new(
        platform: 'ubuntu',
        version: '12.04'
      )
      runner.converge(described_recipe)
    end
    it 'writes the gmond.conf' do
      expect(chef_run).to create_template('/etc/ganglia/gmond.conf').with(
        variables: {
          :sections=>{
            "globals"=>{"daemonize"=>:yes, "setuid"=>:yes, "user"=>:ganglia, "debug_level"=>0, "max_udp_msg_len"=>1472, "mute"=>:no, "deaf"=>:no, "host_dmax"=>0, "cleanup_threshold"=>300, "gexec"=>:no, "send_metadata_interval"=>0},
            "cluster"=>{"owner"=>"unspecified", "latlong"=>"unspecified", "url"=>"unspecified", "name"=>"default"},
            "host"=>{"location"=>"unspecified"},
            "tcp_accept_channel"=>{"port"=>8649},
            "udp_send_channel#18649"=>{"mcast_join"=>"239.2.11.71", "ttl"=>1, "port"=>18649},
            "udp_recv_channel#18649"=>{"mcast_join"=>"239.2.11.71", "bind"=>"239.2.11.71", "port"=>18649}},
          :ports=>[18649]
        }
      )
    end
  end
  context "multicast mode with non-default cluster" do
    let(:chef_run) do
      runner = ChefSpec::Runner.new(
        platform: 'ubuntu',
        version: '12.04'
      )
      runner.node.set['ganglia']['clusterport']['test'] = 1234
      runner.node.set['ganglia']['host_cluster'] = {
        "default" => 0,
        "test" => 1
      }
      runner.converge(described_recipe)
    end
    it 'writes the gmond.conf' do
      expect(chef_run).to create_template('/etc/ganglia/gmond.conf').with(
        variables: {
          :sections=>{
            "globals"=>{"daemonize"=>:yes, "setuid"=>:yes, "user"=>:ganglia, "debug_level"=>0, "max_udp_msg_len"=>1472, "mute"=>:no, "deaf"=>:no, "host_dmax"=>0, "cleanup_threshold"=>300, "gexec"=>:no, "send_metadata_interval"=>0},
            "cluster"=>{"owner"=>"unspecified", "latlong"=>"unspecified", "url"=>"unspecified", "name"=>"test"},
            "host"=>{"location"=>"unspecified"},
            "tcp_accept_channel"=>{"port"=>8649},
            "udp_send_channel#1234"=>{"mcast_join"=>"239.2.11.71", "ttl"=>1, "port"=>1234},
            "udp_recv_channel#1234"=>{"mcast_join"=>"239.2.11.71", "bind"=>"239.2.11.71", "port"=>1234}
          },
          :ports=>[1234]
        }
      )
    end
  end
  context "unicast mode" do
    let(:chef_run) do
      runner = ChefSpec::Runner.new(
        platform: 'ubuntu',
        version: '12.04'
      )
      runner.node.set['ganglia']['unicast'] = true
      runner.converge(described_recipe)
    end
    let(:ganglia_conf_default_cluster) do
      %Q[cluster {
  owner = "unspecified"
  latlong = "unspecified"
  url = "unspecified"
  name = "default"
}]
    end
    let(:ganglia_conf_two_udp_stanzas) do
      %Q[udp_send_channel {
  ttl = 1
  port = 18649
  host = "127.0.0.1"
}

udp_recv_channel {
  port = 18649
}

udp_send_channel {
  ttl = 1
  port = 8649
  host = "127.0.0.1"
}]
    end

    it 'writes the gmond.conf' do
      expect(chef_run).to create_template('/etc/ganglia/gmond.conf').with(
        variables: {
          :sections=>{
            "globals"=>{"daemonize"=>:yes, "setuid"=>:yes, "user"=>:ganglia, "debug_level"=>0, "max_udp_msg_len"=>1472, "mute"=>:no, "deaf"=>:no, "host_dmax"=>0, "cleanup_threshold"=>300, "gexec"=>:no, "send_metadata_interval"=>0},
            "cluster"=>{"owner"=>"unspecified", "latlong"=>"unspecified", "url"=>"unspecified", "name"=>"default"},
            "host"=>{"location"=>"unspecified"},
            "tcp_accept_channel"=>{"port"=>8649},
            "udp_send_channel#127.0.0.1_18649"=>{"ttl"=>1, "port"=>18649, "host"=>"127.0.0.1"},
            "udp_recv_channel#18649"=>{"port"=>18649},
            "udp_send_channel#localhost_8649"=>{"ttl"=>1, "port"=>8649, "host"=>"127.0.0.1"}
          },
          :ports=>[18649]
        }
      )
    end
    it 'gmond.conf does not spoof hostname' do
      expect(chef_run).to_not render_file('/etc/ganglia/gmond.conf').with_content(%Q[  override_hostname = ])
    end
    it 'gmond.conf has default cluster' do
      expect(chef_run).to render_file('/etc/ganglia/gmond.conf').with_content(ganglia_conf_default_cluster)
    end
    it 'gmond.conf has two udp_send stanzas' do
      expect(chef_run).to render_file('/etc/ganglia/gmond.conf').with_content(ganglia_conf_two_udp_stanzas)
    end
  end
  context "unicast mode with hostname spoofing" do
    let(:chef_run) do
      runner = ChefSpec::Runner.new(
        platform: 'ubuntu',
        version: '12.04'
      )
      runner.node.set['ganglia']['unicast'] = true
      runner.node.set['ganglia']['spoof_hostname'] = true
      runner.converge(described_recipe)
    end
    it 'writes the gmond.conf' do
      expect(chef_run).to create_template('/etc/ganglia/gmond.conf').with(
        variables: {
          :sections=>{
            "globals"=>{"daemonize"=>:yes, "setuid"=>:yes, "user"=>:ganglia, "debug_level"=>0, "max_udp_msg_len"=>1472, "mute"=>:no, "deaf"=>:no, "host_dmax"=>0, "cleanup_threshold"=>300, "gexec"=>:no, "send_metadata_interval"=>0, "override_hostname"=>"Fauxhai"},
            "cluster"=>{"owner"=>"unspecified", "latlong"=>"unspecified", "url"=>"unspecified", "name"=>"default"},
            "host"=>{"location"=>"unspecified"},
            "tcp_accept_channel"=>{"port"=>8649},
            "udp_send_channel#127.0.0.1_18649"=>{"ttl"=>1, "port"=>18649, "host"=>"127.0.0.1"},
            "udp_recv_channel#18649"=>{"port"=>18649},
            "udp_send_channel#localhost_8649"=>{"ttl"=>1, "port"=>8649, "host"=>"127.0.0.1"}
          },
          :ports=>[18649]
        }
      )
    end
    it 'gmond.conf does spoof hostname' do
      expect(chef_run).to render_file('/etc/ganglia/gmond.conf').with_content(%Q[  override_hostname = ])
    end
  end
  context "unicast mode with multiple clusters" do
    let(:chef_run) do
      runner = ChefSpec::Runner.new(
        platform: 'ubuntu',
        version: '12.04'
      )
      runner.node.set['ganglia']['unicast'] = true
      runner.node.set['ganglia']['clusterport']['test'] = 1234
      runner.node.set['ganglia']['host_cluster']['test'] = 1
      runner.converge(described_recipe)
    end
    let(:ganglia_conf_three_udp_stanzas) do
      %Q[udp_send_channel {
  ttl = 1
  port = 18649
  host = "127.0.0.1"
}

udp_recv_channel {
  port = 18649
}

udp_send_channel {
  ttl = 1
  port = 1234
  host = "127.0.0.1"
}

udp_recv_channel {
  port = 1234
}

udp_send_channel {
  ttl = 1
  port = 8649
  host = "127.0.0.1"
}]
    end
    it 'writes the gmond.conf' do
      expect(chef_run).to create_template('/etc/ganglia/gmond.conf').with(
        variables: {
          :sections=>{
            "globals"=>{"daemonize"=>:yes, "setuid"=>:yes, "user"=>:ganglia, "debug_level"=>0, "max_udp_msg_len"=>1472, "mute"=>:no, "deaf"=>:no, "host_dmax"=>0, "cleanup_threshold"=>300, "gexec"=>:no, "send_metadata_interval"=>0},
            "cluster"=>{"owner"=>"unspecified", "latlong"=>"unspecified", "url"=>"unspecified", "name"=>"default"},
            "host"=>{"location"=>"unspecified"},
            "tcp_accept_channel"=>{"port"=>8649},
            "udp_send_channel#127.0.0.1_18649"=>{"ttl"=>1, "port"=>18649, "host"=>"127.0.0.1"},
            "udp_recv_channel#18649"=>{"port"=>18649},
            "udp_send_channel#127.0.0.1_1234"=>{"ttl"=>1, "port"=>1234, "host"=>"127.0.0.1"},
            "udp_recv_channel#1234"=>{"port"=>1234},
            "udp_send_channel#localhost_8649"=>{"ttl"=>1, "port"=>8649, "host"=>"127.0.0.1"}
          },
          :ports=>[18649, 1234]
        }
      )
    end
    it 'gmond.conf has three udp_send stanzas' do
      expect(chef_run).to render_file('/etc/ganglia/gmond.conf').with_content(ganglia_conf_three_udp_stanzas)
    end

  end
  context "unicast mode with specifc server_host and nondefault cluster" do
    let(:chef_run) do
      runner = ChefSpec::Runner.new(
        platform: 'ubuntu',
        version: '12.04'
      )
      runner.node.set['ganglia']['unicast'] = true
      runner.node.set['ganglia']['server_host'] = 'ganglia.example.com'
      runner.node.set['ganglia']['clusterport']['test'] = 1234
      runner.node.set['ganglia']['host_cluster'] = {
        "default" => 0,
        "test" => 1
      }
      runner.converge(described_recipe)
    end
    it 'writes the gmond.conf' do
      expect(chef_run).to create_template('/etc/ganglia/gmond.conf').with(
        variables: {
          :sections=>{
            "globals"=>{"daemonize"=>:yes, "setuid"=>:yes, "user"=>:ganglia, "debug_level"=>0, "max_udp_msg_len"=>1472, "mute"=>:no, "deaf"=>:no, "host_dmax"=>0, "cleanup_threshold"=>300, "gexec"=>:no, "send_metadata_interval"=>0},
            "cluster"=>{"owner"=>"unspecified", "latlong"=>"unspecified", "url"=>"unspecified", "name"=>"test"},
            "host"=>{"location"=>"unspecified"},
            "tcp_accept_channel"=>{"port"=>8649},
            "udp_send_channel#ganglia.example.com_1234"=>{"ttl"=>1, "port"=>1234, "host"=>"ganglia.example.com"},
            "udp_recv_channel#1234"=>{"port"=>1234},
            "udp_send_channel#localhost_8649"=>{"ttl"=>1, "port"=>8649, "host"=>"127.0.0.1"}
          },
          :ports=>[1234]
        }
      )
    end
  end
  context "unicast mode with host_cluster that doesn't exist in clusterport" do
    let(:chef_run) do
      runner = ChefSpec::Runner.new(
        platform: 'ubuntu',
        version: '12.04'
      )
      runner.node.set['ganglia']['unicast'] = true
      runner.node.set['ganglia']['host_cluster'] = {
        "default" => 0,
        "test" => 1
      }
      runner.converge(described_recipe)
    end
    it 'writes the gmond.conf, defaulting to the default cluster' do
      expect(chef_run).to create_template('/etc/ganglia/gmond.conf').with(
        variables: {
          :sections=>{
            "globals"=>{"daemonize"=>:yes, "setuid"=>:yes, "user"=>:ganglia, "debug_level"=>0, "max_udp_msg_len"=>1472, "mute"=>:no, "deaf"=>:no, "host_dmax"=>0, "cleanup_threshold"=>300, "gexec"=>:no, "send_metadata_interval"=>0},
            "cluster"=>{"owner"=>"unspecified", "latlong"=>"unspecified", "url"=>"unspecified", "name"=>"default"},
            "host"=>{"location"=>"unspecified"},
            "tcp_accept_channel"=>{"port"=>8649},
            "udp_send_channel#127.0.0.1_18649"=>{"ttl"=>1, "port"=>18649, "host"=>"127.0.0.1"},
            "udp_recv_channel#18649"=>{"port"=>18649},
            "udp_send_channel#localhost_8649"=>{"ttl"=>1, "port"=>8649, "host"=>"127.0.0.1"}},
          :ports=>[18649]
        }
      )
    end
  end
  context "unicast mode with specifc gmond_collector stub search" do
    let(:chef_run) do
      runner = ChefSpec::Runner.new(
        platform: 'ubuntu',
        version: '12.04',
        #log_level: :debug
      )
      runner.node.set['ganglia']['unicast'] = true
      runner.converge(described_recipe)
    end
    before do
      hosts = []
      ['host1', 'host2'].each do |host|
        n = stub_node(platform: 'ubuntu', version: '12.04') do |node|
          node.run_list(['role[ganglia]'])
          node.name(host)
          node.automatic['ipaddress'] = host
        end
        hosts << n
      end
      stub_search(:node, 'role:ganglia AND chef_environment:_default').and_return(hosts)
    end
    let(:ganglia_conf_three_udp_stanzas) do
      %Q[udp_send_channel {
  ttl = 1
  port = 18649
  host = "host1"
}

udp_send_channel {
  ttl = 1
  port = 18649
  host = "host2"
}

udp_recv_channel {
  port = 18649
}

udp_send_channel {
  ttl = 1
  port = 8649
  host = "127.0.0.1"
}]
    end
    it 'writes the gmond.conf' do
      expect(chef_run).to create_template('/etc/ganglia/gmond.conf').with(
        variables: {
          :sections=>{
            "globals"=>{"daemonize"=>:yes, "setuid"=>:yes, "user"=>:ganglia, "debug_level"=>0, "max_udp_msg_len"=>1472, "mute"=>:no, "deaf"=>:no, "host_dmax"=>0, "cleanup_threshold"=>300, "gexec"=>:no, "send_metadata_interval"=>0},
            "cluster"=>{"owner"=>"unspecified", "latlong"=>"unspecified", "url"=>"unspecified", "name"=>"default"},
            "host"=>{"location"=>"unspecified"},
            "tcp_accept_channel"=>{"port"=>8649},
            "udp_send_channel#host1_18649"=>{"ttl"=>1, "port"=>18649, "host"=>"host1"},
            "udp_send_channel#host2_18649"=>{"ttl"=>1, "port"=>18649, "host"=>"host2"},
            "udp_recv_channel#18649"=>{"port"=>18649},
            "udp_send_channel#localhost_8649"=>{"ttl"=>1, "port"=>8649, "host"=>"127.0.0.1"}},
          :ports=>[18649],
        }
      )
    end
    it 'gmond.conf has three udp_send stanzas' do
      expect(chef_run).to render_file('/etc/ganglia/gmond.conf').with_content(ganglia_conf_three_udp_stanzas)
    end
  end
end
