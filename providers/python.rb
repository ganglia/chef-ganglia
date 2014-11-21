

action :enable do

  #python module
  if new_resource.github
    githuburl = "https://raw.githubusercontent.com/ganglia/gmond_python_modules/master/#{new_resource.module_name}/python_modules/#{new_resource.module_name}.py"
    remote_file "/usr/lib/ganglia/python_modules/#{new_resource.module_name}.py" do
      source githuburl
      mode 00644
      action :create_if_missing
    end
  else
    template "/usr/lib/ganglia/python_modules/#{new_resource.module_name}.py" do
      source "ganglia/#{new_resource.module_name}.py.erb"
      owner "root"
      group "root"
      mode "644"
      variables :options => new_resource.options
      notifies :restart, "service[ganglia-monitor]"
    end
  end

  #configuration
  template "/etc/ganglia/conf.d/#{new_resource.module_name}.pyconf" do
    source "ganglia/#{new_resource.module_name}.pyconf.erb"
    owner "root"
    group "root"
    mode "644"
    variables :options => new_resource.options
    notifies :restart, "service[ganglia-monitor]"
  end

end

action :disable do

  file "/usr/lib/ganglia/python_modules/#{new_resource.module_name}.py" do
    action :delete
    notifies :restart, "service[ganglia-monitor]"
  end

  file "/etc/ganglia/conf.d/#{new_resource.module_name}.pyconf" do
    action :delete
    notifies :restart, "service[ganglia-monitor]"
  end

end