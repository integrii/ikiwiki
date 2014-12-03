# name of your wiki - this will also be your get repo name so use spaces with caution
default['ikiwiki']['wikiName'] = "My ikiWiki"

# short name of your wiki - used for folder and config creation
default['ikiwiki']['wikiNameShort'] = "ikiwiki"

# admin email address
default['ikiwiki']['adminEmail'] = if node["fqdn"] then "admin@#{node["fqdn"]}" else "root@localhost" end

# this is the first admin user to be created
default['ikiwiki']['adminUser'] = "ikiwiki"

# this is the first admin password that will be set
default['ikiwiki']['adminPass'] = "ikiwiki"

# this is the url the wiki will be hosted at
default['ikiwiki']['siteUrl'] = if node["fqdn"] then "http://#{node["fqdn"]}" else "http://#{node["name"]}" end

# switch to true to enable local authenticaton (does not allow system users)
default['ikiwiki']['passworded'] = false
