![ikiwiki chef cookbook](https://raw.githubusercontent.com/integrii/ikiwiki/master/ikiwiki-chef.png)


#ikiwiki with bootstrap 3 theme

This cookbook deploys [ikiwiki](https://ikiwiki.info) _(the best wiki ever!)_ as well as the bootstrap 3 theme based on [Twitter's bootstrap CSS framework](http://getbootstrap.com/).  Ikiwiki is a wiki backed by a git repository that updates on commits and uses markdown!  Ikiwiki also comes with a clean web interface based on Twitter's Bootstrap 3 for graphical administration and editing.  This cookbook deploys ikiwiki in a way that is very similar to the Github wiki but with more features.


Requirements
------------
- Centos 6+
- yum-epel

Attributes
----------


```
['ikiwiki']['wikiName'] = 'ikiWiki'
['ikiwiki']['wikiNameShort'] = 'ikiWiki'
['ikiwiki']['adminEmail'] = 'admin@mysite.com'
['ikiwiki']['siteUrl'] = 'http://wiki.mysite.com'
['ikiwiki']['wikiAdmin'] = 'ikiwiki'
['ikiwiki']['wikiPass'] = 'ikiwiki'
```

Usage
-----
- Make sure to setup all attributes above before running your cookbook or else it will initialize with the wrong values that wont change! 
- Add to your run_list 
- After execution put your company logo at ``/var/www/html/logo.png`` on the wiki server

A user named ikiwiki will be created, apache will be installed and a wiki will be hosted at **/var/www/ikiwiki** with a git repo at ``/home/ikiwiki/yourwikiname.git``.  If you want to clone that directory, you will need to setup an authorized_keys file at /home/ikiwiki/.ssh/authorized_keys with your public keys in it.  You will then do your ``git clone`` as ``git clone ikiwiki@ikiwikiServer:wikiNameShort.git``.

Ikiwiki has lots of [plugins](https://ikiwiki.info/plugins/) that you can install.  Simply edit your ``/home/ikiwiki/setup.settings`` file to enable them and then run ``ikiwiki --setup /home/ikiwiki/ikiwiki.settings`` to run a rebuild on the wiki.

These plugins are enabled by this cookbook but can be disabled easily via the web UI settings page:
- color
- attachment
- addtag
- hilight
- img
- newpage
- notifyemail
- linkmap
- relativedate
- remove
- heading anchors

Thanks
------
Thanks to the author of [ikiwiki bootstrap 3](https://github.com/ramseydsilva/ikiwiki-bootstrap-theme) and of course [ikiwiki](https://ikiwiki.info/)!

Contributing
------------
Contributions are welcomed.  Lets get ikiwiki out there as a more popular wiki!

License and Authors
-------------------
Authors: Eric Greer (ericgreer@gmail.com)
