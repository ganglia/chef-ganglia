require 'spec_helper'

describe 'ganglia::gmetad' do
  let(:chef_run) do
    runner = ChefSpec::Runner.new(
      platform: 'ubuntu',
      version: '12.04'
    )
    runner.converge(described_recipe)
  end
  before do
    hosts = []
    ['host1', 'host2'].each do |host|
      n = stub_node(platform: 'ubuntu', version: '12.04') do |node|
        node.name(host)
        node.automatic['ipaddress'] = host
      end
      hosts << n
    end
    stub_search(:node, 'ganglia_host_cluster_default:1').and_return(hosts)
  end

  it 'installs the gmetad package' do
    expect(chef_run).to install_package('gmetad')
  end
  it 'creates the rrd dir' do
    expect(chef_run).to create_directory('/var/lib/ganglia/rrds').with(
      owner: 'nobody'
      )
  end
  context "default config" do
    it 'installs rrdcached' do
      expect(chef_run).to install_package('rrdcached')
    end
    it 'includes runit' do
      expect(chef_run).to include_recipe('runit')
    end
    # it 'creates rrdacched runit service' do
    #   # commented out until I figure out how to stub runit_service
    #   expect(chef_run).to create_runit_service('rrdcached')
    # end
    it 'installs socat package' do
      expect(chef_run).to install_package('socat')
    end
    it 'creates gmetad.conf' do
      expect(chef_run).to create_template("/etc/ganglia/gmetad.conf").with(
        variables: {
          :clusters => {"default" => ["host1:18649", "host2:18649"]},
          :grid_name => "default",
          :rrd_rootdir=>"/var/lib/ganglia/rrds",
          :params => {
            "xml_port"         => 8651,
            "interactive_port" => 8652,
          },
        }
      )
      expect(chef_run).to render_file("/etc/ganglia/gmetad.conf").with_content(
        %Q[data_source "default" host2:18649 host1:18649])
    end
  end
  context 'unicast with search' do
    let(:chef_run) do
      runner = ChefSpec::Runner.new(
        platform: 'ubuntu',
        version: '12.04'
      )
      runner.node.set['ganglia']['unicast'] = true
      runner.converge(described_recipe)
    end
    before do
      hosts = []
      ['host1', 'host2'].each do |host|
        n = stub_node(platform: 'ubuntu', version: '12.04') do |node|
          node.name(host)
          node.automatic['ipaddress'] = host
        end
        hosts << n
      end
      stub_search(:node, 'role:ganglia AND chef_environment:_default').and_return(hosts)
    end
    it 'creates gmetad.conf template' do
      expect(chef_run).to create_template('/etc/ganglia/gmetad.conf').with(
        :variables => {
          :clusters => { "default" => ["host1:18649", "host2:18649"] },
          :params => {
            "xml_port"         => 8651,
            "interactive_port" => 8652,
          },
          :rrd_rootdir => '/var/lib/ganglia/rrds',
          :grid_name => 'default',
          })
    end
    it 'gmetad.conf notifies gmetad to restart' do
      gmetad_conf = chef_run.template('/etc/ganglia/gmetad.conf')
      expect(gmetad_conf).to notify('service[gmetad]').to(:restart)
    end
    it 'does not include iptables' do
      expect(chef_run).to_not include_recipe('ganglia::iptables')

    end
  end
  context 'unicast with two gmetads and empty search' do
    let(:chef_run) do
      runner = ChefSpec::Runner.new(
        platform: 'ubuntu',
        version: '12.04'
      )
      runner.node.set['ganglia']['unicast'] = true
      runner.node.set['ganglia']['enable_two_gmetads'] = true
      runner.converge(described_recipe)
    end
    before do
      stub_search(:node, 'role:ganglia AND chef_environment:_default').and_return([])
    end
    it 'creates gmetad.conf template' do
      expect(chef_run).to create_template('/etc/ganglia/gmetad.conf').with(
        :variables => {
          :clusters=> { "default" => ["127.0.0.1:18649"] },
          :params => {
            "xml_port"         => 8651,
            "interactive_port" => 8652,
          },
          :rrd_rootdir => '/var/lib/ganglia/rrds',
          :grid_name => 'default',
          })
    end
    it 'creates gmetad-norrds.conf template' do
      expect(chef_run).to create_template('/etc/ganglia/gmetad-norrds.conf').with(
        :variables => {
          :clusters=> { "default" => ["127.0.0.1:18649"] },
          :params => {
            :xml_port         => 8661,
            :interactive_port => 8662,
            :write_rrds       => "off",
          },
          :rrd_rootdir => '/var/lib/ganglia/empty-rrds-dir',
          :grid_name => 'default',
          })
    end
  end
  context 'two gmetad config' do
    let(:chef_run) do
      runner = ChefSpec::Runner.new(
        platform: 'ubuntu',
        version: '12.04'
      )
      runner.node.set['ganglia']['enable_two_gmetads'] = true
      runner.converge(described_recipe)
    end
    it 'creates an empty rrddir' do
      expect(chef_run).to create_directory('/var/lib/ganglia/empty-rrds-dir').with(
        :owner => 'nobody',
        )
    end
    it 'creates second gmetad init script' do
      expect(chef_run).to create_template('/etc/init.d/gmetad-norrds').with(
        variables: {
          :gmetad_name => 'gmetad-norrds'
          })
      expect(chef_run).to render_file('/etc/init.d/gmetad-norrds').with_content(
        %Q[NAME=gmetad-norrds])
    end
    it 'second init script notifies second gmetad to restart' do
      gmetad_initscript = chef_run.template('/etc/init.d/gmetad-norrds')
      expect(gmetad_initscript).to notify('service[gmetad-norrds]').to(:restart)
    end
    it 'starts second gmetad process' do
      expect(chef_run).to start_service('gmetad-norrds')
    end
  end

  it 'does not set graphite options by default' do
    expect(chef_run).to create_template("/etc/ganglia/gmetad.conf")
    expect(chef_run).to_not render_file("/etc/ganglia/gmetad.conf").with_content(/carbon_server/)
    expect(chef_run).to_not render_file("/etc/ganglia/gmetad.conf").with_content(/carbon_port/)
    expect(chef_run).to_not render_file("/etc/ganglia/gmetad.conf").with_content(/graphite_prefix/)
  end

  context 'set graphite config in gmetad' do
    let(:chef_run) do
      runner = ChefSpec::Runner.new(
        platform: 'ubuntu',
        version: '12.04'
      )
      runner.node.set['ganglia']['gmetad']['carbon_server'] = '127.0.0.1'
      runner.node.set['ganglia']['gmetad']['carbon_port'] = 8125
      runner.node.set['ganglia']['gmetad']['graphite_prefix'] = 'ganglia'
      runner.converge(described_recipe)
    end
    it 'does set graphite options by default' do
      expect(chef_run).to create_template("/etc/ganglia/gmetad.conf")
      expect(chef_run).to render_file("/etc/ganglia/gmetad.conf").with_content(/carbon_server "127.0.0.1"/)
      expect(chef_run).to render_file("/etc/ganglia/gmetad.conf").with_content(/carbon_port 8125/)
      expect(chef_run).to render_file("/etc/ganglia/gmetad.conf").with_content(/graphite_prefix "ganglia"/)
    end
  end
end
