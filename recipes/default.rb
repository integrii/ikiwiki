#
# Cookbook Name:: ikiwiki
# Recipe:: default
#
#


# Include epel 
include_recipe "yum-epel"

# Install packages
package "gcc" do
  action 'install'
end
package "ikiwiki" do
  action 'install'
end
package "git" do
  action 'install'
end
package "httpd" do
  action 'install'
end
package "fcgi" do
  action 'install'
end
package "spawn-fcgi" do
  action 'install'
end
package "unzip" do
  action 'install'
end
package "perl-Mail-Sendmail" do
  action 'install'
  ignore_failure true
end
package "ImageMagick-perl" do
  action 'install'
end
package "graphviz-perl" do
  action 'install'
end
package "perl-XML-Writer" do
  action 'install'
end

# setup ikiwiki user
user "ikiwiki" do
  home '/home/ikiwiki'
  system true
  action 'create'
  shell '/bin/bash'
end

# setup ikiwiki homedir
directory "/home/ikiwiki" do
  owner 'ikiwiki'
  group 'ikiwiki'
  mode '0775'
  action 'create'
  recursive true
end


# setup ikiwiki
template "/home/ikiwiki/ikiwiki.setup" do
  source "ikiwiki.setup.erb"
  mode '0755'
  owner 'ikiwiki'
  group 'ikiwiki'
  variables({
     'wikiName' => node['ikiwiki']['wikiName'],
     'wikiNameShort' => node['ikiwiki']['wikiNameShort'],
     'adminEmail' => node['ikiwiki']['adminEmail'],
     'siteUrl' => node['ikiwiki']['siteUrl'],
     'adminUser' => node['ikiwiki']['adminUser'],
     'adminPass' => node['ikiwiki']['adminPass']
  })
end

# remove apache welcome.conf file
file "/etc/httpd/conf.d/welcome.conf" do
  action 'delete'
end

# Install httpd config file
template "/etc/httpd/conf/httpd.conf" do
  source "httpd.conf.erb"
  mode '0755'
  owner 'apache'
  group 'apache'
end

# place download theme zip on server
cookbook_file "bootstrap-theme.zip" do
  path "/tmp/bootstrap-theme.zip"
  action 'create'
  mode 0775
  owner 'ikiwiki'
  group 'ikiwiki'
  not_if { node.attribute?("ikiwiki-setup-complete") }
end

# unzip bootstrap theme
execute "install bootstrap 3 theme" do
  command "unzip -o /tmp/bootstrap-theme.zip;mv ikiwiki-bootstrap-theme-master bootstrap-theme"
  action 'run'
  cwd '/home/ikiwiki'
  creates '/home/ikiwiki/bootstrap-theme'
  not_if { node.attribute?("ikiwiki-setup-complete") }
end


# set permissions in /etc/ikiwiki dir to ikiwiki
execute "chown a bunch of stuff to ikiwiki" do
  command "chown -R ikiwiki /etc/ikiwiki; chown -R ikiwiki /var/www; chown -R ikiwiki /home/ikiwiki/bootstrap-theme"
  action :run
  not_if { node.attribute?("ikiwiki-setup-complete") }
end



# Run first time ikiwiki setup
bash "ikiwiki --setup ikiwiki.setup" do
code <<-EOH
ikiwiki --setup ikiwiki.setup << EOF                  
#{node["ikiwiki"]["adminPass"]}
#{node["ikiwiki"]["adminPass"]}

EOF
EOH
  cwd "/home/ikiwiki"
  user "ikiwiki"
  group "ikiwiki"
  #returns 255
  environment 'HOME' => "/home/ikiwiki"
  notifies "create", "ruby_block[ikiwiki-setup]", :immediately
  not_if { node.attribute?("ikiwiki-setup-complete") }
end

# place download theme zip on server
cookbook_file "logo.png" do
  path "/var/www/ikiwiki/logo.png"
  action 'create'
  mode 0775
  owner 'ikiwiki'
  group 'ikiwiki'
  not_if { node.attribute?("ikiwiki-setup-complete") }
end

# flag install as run
ruby_block "ikiwiki-setup" do
  block do
    node.set['ikiwiki-setup-complete'] = true
    node.save
  end
  action :nothing
end

# enable and start httpd
service "httpd" do
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :start ]
end
