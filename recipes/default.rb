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
package "mod_auth_pam" do
  action 'install'
end
package "mod_auth_shadow" do
  action 'install'
end
package "mod_authnz_external" do
  action 'install'
end
package "pwauth" do
  action 'install'
end
package "perl-DBD-SQLite2" do
  action 'install'
end
package "perl-DBD-SQLite" do
  action 'install'
end
package "perl-Digest-SHA1" do
  action 'install'
end
package "perl-Digest-SHA" do
  action 'install'
end


# setup ikiwiki user
user "ikiwiki" do
  home '/home/ikiwiki'
  system true
  action 'create'
  shell '/bin/bash'
end

# setup ikiwiki group
group "ikiwiki" do
  action 'create'
  members "ikiwiki"
  append true
end

# setup ikiwiki homedir
directory "/home/ikiwiki" do
  owner 'ikiwiki'
  group 'ikiwiki'
  mode '0775'
  action 'create'
  recursive true
end

# filetypes config fix for highlight
cookbook_file "sqlite_search.pm" do
  path "/usr/share/perl5/vendor_perl/IkiWiki/Plugin/sqlite_search.pm"
  action 'create'
  mode 0775
  owner 'root'
  group 'ikiwiki'
  not_if { node.attribute?("ikiwiki-setup-complete") }
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

# setup dir for third party plugin inclusion
directory "/home/ikiwiki/.ikiwiki/plugins" do
  owner 'ikiwiki'
  group 'ikiwiki'
  mode '0775'
  action 'create'
  recursive true
end

# create a plugin for sqllite to get the setup to run initially without removing the plugin from the enabled plugins list
cookbook_file "sqlite_search.pm" do
  path "/home/ikiwiki/.ikiwiki/plugins/sqlite_search"
  action 'create'
  mode 0775
  owner 'ikiwiki'
  group 'ikiwiki'
end

# setup dir for highlight filetypes config
directory "/etc/highlight" do
  owner 'root'
  group 'ikiwiki'
  mode '0775'
  action 'create'
  recursive true
end

# filetypes config fix for highlight
cookbook_file "filetypes.conf" do
  path "/etc/highlight/filetypes.conf"
  action 'create'
  mode 0775
  owner 'root'
  group 'ikiwiki'
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

# place modified search pages for sqlite_search plugin
cookbook_file "search-result-form.tmpl" do
  path "/home/ikiwiki/bootstrap-theme/search-result-form.tmpl"
  action 'create'
  mode 0644
  owner 'root'
  group 'root'
  not_if { node.attribute?("ikiwiki-setup-complete") }
end

cookbook_file "search-result.tmpl" do
  path "/home/ikiwiki/bootstrap-theme/search-result.tmpl"
  action 'create'
  mode 0644
  owner 'root'
  group 'root'
  not_if { node.attribute?("ikiwiki-setup-complete") }
end

# place fixed page template (search form shows now!)
cookbook_file "page.tmpl" do
  path "/home/ikiwiki/bootstrap-theme/page.tmpl"
  action 'create'
  mode 0644
  owner 'root'
  group 'root'
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
  # This returns 255 because the sqllite_plugin fails to load
  # The plugin has to fail to load in order for it to stay enabled in the .settings config that is generated
  returns [0, 255]
  environment 'HOME' => "/home/ikiwiki"
  notifies "create", "ruby_block[ikiwiki-setup]"
  not_if { node.attribute?("ikiwiki-setup-complete") }
end


# remove sqlite_search.pm file used in shim to get search working
file "/home/ikiwiki/.ikiwiki/plugins/sqlite_search" do
  action 'delete'
end

# Run ikiwiki --setup again for clean build. run against built setup file this time
bash "ikiwiki --setup ikiwiki.settings" do
code <<-EOH
ikiwiki --setup ikiwiki.settings
EOH
  cwd "/home/ikiwiki"
  user "ikiwiki"
  group "ikiwiki"
  # This returns 255 because the sqllite_plugin fails to load
  # The plugin has to fail to load in order for it to stay enabled in the .settings config that is generated
  returns [0, 255]
  environment 'HOME' => "/home/ikiwiki"
  not_if { node.attribute?("ikiwiki-setup-complete") }
end

# place default logo in webroot
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
