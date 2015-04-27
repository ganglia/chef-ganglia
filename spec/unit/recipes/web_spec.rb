require 'spec_helper'

describe 'ganglia::web' do
  let(:chef_run) do
    runner = ChefSpec::Runner.new(
      platform: 'ubuntu',
      version: '12.04'
    )
    runner.converge(described_recipe)
  end

  it 'creates the ganglia-webfrontend directory' do
  	expect(chef_run).to create_directory('/etc/ganglia-webfrontend')
  end

  it 'installs the ganglia-webfrontend package' do
    expect(chef_run).to install_package('ganglia-webfrontend')
  end

  it 'creates a link to the apache conf' do
  	link = chef_run.link('/etc/apache2/sites-enabled/001-ganglia.conf')
  	expect(link).to link_to('/etc/ganglia-webfrontend/apache.conf')
  end

  it 'link notifies apache service' do
  	link = chef_run.link('/etc/apache2/sites-enabled/001-ganglia.conf')
  	expect(link).to notify('service[apache2]').to(:restart)
  end

  it 'creates config.php' do
  	expect(chef_run).to create_template('/etc/ganglia-webfrontend/conf.php')
  end

  context 'web auth_system enabled' do
  	let(:chef_run) do
      runner = ChefSpec::Runner.new(
        platform: 'ubuntu',
        version: '12.04'
      ) do |node|
        node.set['ganglia']['web']['auth_system'] = 'enabled'
        node.set['ganglia']['ganglia_secret'] = '12345'
      end
      runner.converge(described_recipe)
    end

    before do
      	stub_search(:users, 'ganglia:* AND password:*').and_return({ id: 'admin', ganglia: 'ADMIN', password: 'password'})
    end

    it 'creates ganglia-auth.conf' do
    	expect(chef_run).to create_template('/etc/ganglia-webfrontend/ganglia-auth.conf')
    end

	it 'creates a link to the apache auth conf' do
      expect(chef_run).
        to create_link('/etc/apache2/sites-enabled/ganglia-auth.conf').
        with(to: '/etc/ganglia-webfrontend/ganglia-auth.conf')
	end

    it 'link notifies apache service' do
      link = chef_run.link('/etc/apache2/sites-enabled/ganglia-auth.conf')
      expect(link).to notify('service[apache2]').to(:restart)
  	end

  	it 'creates htpasswd.users' do
    	expect(chef_run).to create_template('/etc/ganglia-webfrontend/htpasswd.users')
    end

    it 'creates conf.php' do
    	expect(chef_run).to create_template('/etc/ganglia-webfrontend/conf.php')
    end
  end
end
