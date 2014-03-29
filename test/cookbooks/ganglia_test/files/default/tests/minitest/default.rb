require File.expand_path('../support/helpers', __FILE__)
describe "ganglia_test::default" do
  include Helpers::GangliaTest
  it 'creates the gmond configuration' do
    file('/etc/ganglia/gmond.conf').must_exist
  end
end
