#ikiwiki with bootstrap 3 theme


This cookbook deploys ikiwiki _(the best wiki ever!)_ as well as the bootstrap theme.
A user named ikiwiki will be created, apache will be installed and a wiki will be hosted at **/var/www/html** with a git repo at ``/home/ikiwiki/yourwikiname.git``.  If you want to clone that directory, you will need to setup an authorized_keys file at /home/ikiwiki/.ssh/authorized_keys with your public keys in it.


Requirements
------------
Centos 6+
yum-epel

Attributes
----------

['ikiwiki']['wikiName'] = 'ikiWiki'
['ikiwiki']['wikiNameShort'] = 'ikiWiki'
['ikiwiki']['adminEmail'] = 'admin@mysite.com'
['ikiwiki']['siteUrl'] = 'http://wiki.mysite.com'
['ikiwiki']['wikiAdmin'] = 'ikiwiki'
['ikiwiki']['wikiPass'] = 'ikiwiki'

Usage
-----
Make sure to setup all attributes above before running your cookbook or else it will initialize with the wrong values that wont change! 
Add to your run_list 
After execution put your company logo at ``/var/www/html/logo.png`` on the wiki server

Contributing
------------
Contributions are welcomed.  Lets get ikiwiki out there as a more popular wiki!

License and Authors
-------------------
Authors: Eric Greer (ericgreer@gmail.com)
