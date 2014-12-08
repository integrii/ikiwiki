package IkiWiki::Plugin::sqlite_search;

# Author: Baldur Kristinsson (https://github.com/bk/)
# This is free software; it is under the same dual GPL/Artistic license as Perl.
# For documentation (such as it is), see the accompanying README.md file,
# as well as the POD at the bottom of this file.

use warnings;
use strict;
use IkiWiki 3.00;
use Encode qw/encode decode/;

my $fts = SQLiteFTS->new(db=>"$config{srcdir}/.ikiwiki/fts.sqlite");

sub import {
	hook(type => "getsetup", id => "search", call => \&getsetup);
	hook(type => "checkconfig", id => "search", call => \&checkconfig);
	hook(type => "pagetemplate", id => "search", call => \&pagetemplate);
	hook(type => "indexhtml", id => "search", call => \&indexhtml);
	hook(type => "delete", id => "search", call => \&delete);
	hook(type => "cgi", id => "search", call => \&cgi);
	hook(type => "disable", id => "search", call => \&disable);
}

sub getsetup () {
	return
		plugin => {
			safe => 1,
			rebuild => 1,
			section => "web",
		};
}

sub checkconfig () {
    # The sqlite_search plugin uses the same template as the
    # "official" search plugin (which is based on xapian omega).
    # 
	# This is a mass dependency, so if the search form template
	# changes, every page is rebuilt.
	add_depends("", "templates/searchform.tmpl");
}

my $form;
sub pagetemplate (@) {
	my %params = @_;
	my $page=$params{page};
	my $template=$params{template};

	# Add search box to page header.
	if ($template->query(name => "searchform")) {
		if (! defined $form) {
			my $searchform = template("searchform.tmpl", blind_cache => 1);
			$searchform->param(searchaction => IkiWiki::cgiurl());
			$searchform->param(html5 => $config{html5});
			$form=$searchform->output;
		}

		$template->param(searchform => $form);
	}
}

sub indexhtml (@) {
	my %params = @_;

    my $title = pagetitle($params{page});
	if (exists $pagestate{$params{page}}{meta} &&
		exists $pagestate{$params{page}}{meta}{title}) {
		$title=$pagestate{$params{page}}{meta}{title};
	}
    my $text = $params{content};
    my $url=urlto($params{destpage}, "", 1);
	if (defined $pagestate{$params{page}}{meta}{permalink}) {
		$url=$pagestate{$params{page}}{meta}{permalink}
	}
    return if $url =~ m{/recentchanges/};
    $fts->index(title=>$title, url=>$url, text=>$text);
}

sub delete (@) {
    my @pages = @_;
    my $url = '';
    foreach my $page (@pages) {
        my $url=urlto($page, "", 1);
	    if (defined $pagestate{$page}{meta}{permalink}) {
		    $url=$pagestate{$page}{meta}{permalink}
        }
	}
    return unless $url;
    #warn "deleting $url\n";
    $fts->delete(url=>$url);
}

sub cgi ($) {
	my $cgi=shift;
	if (defined $cgi->param('P')) {
        my $query = $cgi->param('P');
        utf8::upgrade($query);
        if ($query =~ /[ÃÂ]/) {
            # almost certainly doubly encoded Latin-1...
            $query = decode('utf-8', encode('latin1', $query));
        }
        my $res = $fts->search($query);
        print $cgi->header('text/html; charset=utf-8');
        print render_result($cgi, $query, $res);
        exit;
	}
}

sub render_result {
    my ($cgi, $query, $res) = @_;
    my $tpl = Renderer->new(cgi=>$cgi);
    # The result-form and result templates are different from the
    # built-in xapian search, and must be placed in an appropriate location.
    my $form = $tpl->render_fragment('search-result-form', query=>$query);
    my $formatted_results = $tpl->render_fragment('search-result', result=>$res);
    my $content = $form . $formatted_results;
    # TODO: how about pagination?
    return $tpl->render_page("Search: $query", $content);
}

sub disable () {
    my $fn = "$config{wikistatedir}/fts.sqlite";
    unlink $fn if -f $fn;
}


### BACKEND PACKAGES: SQLiteFTS + Renderer.

package SQLiteFTS;

use strict;
use DBI;
use DBD::SQLite; # For the version
use Digest::SHA qw/sha1_hex/;
use Encode qw/encode decode/;
use locale;
use utf8;

sub new {
    my ($pk, %opt) = @_;
    my $class = ref($pk) || $pk;
    my $self = \%opt;
    bless($self, $class);
    $self->_init();
    return $self;
}

sub _init {
    my $self = shift;
    $self->{db} ||= "/tmp/fts.$$.sqlite";
    my $create = -f $self->{db} ? 0 : 1;
    my @dsn = (
        "dbi:SQLite:dbname=$self->{db}", undef, undef,
        {RaiseError=>1, AutoCommit=>1, sqlite_unicode=>1});
    $self->{dbh} = DBI->connect(@dsn) or die "Could not open database";
    $self->{dbh}->do('pragma encoding = "UTF-8"');
    unless ($create) {
        eval {
            die "table not found" unless $self->{dbh}->selectrow_array(
                "select 1 from sqlite_master WHERE type='table' AND name='page'");
        };
        $create = 1 if $@;
    }
    if ($create) {
        eval { $self->_create_schema };
        warn "WARNING: Could not create schema: $@\n" if $@;
    }
}

sub _create_schema {
    my $self = shift;
    my $dbh = $self->{dbh};
    my $fts_v = $DBD::SQLite::VERSION >= 1.36 ? 'fts4' : 'fts3';
    my @sql = (
        "create table page (
          page_id integer primary key,
          page_url text,
          page_title text,
          page_summary text,
          page_sha1 text,
          unique (page_url),
          unique (page_sha1))",
        "create virtual table fts_page
          using $fts_v (
            page_name,
            page_start,
            page_all)",
    );
    $dbh->begin_work;
    foreach my $sql (@sql) {
        $dbh->do($sql);
    }
    $dbh->commit;
}

sub index {
    my $self = shift;
    my $dbh = $self->{dbh};
    my %rec = @_;
    die "need url, title and text for indexing"
        unless $rec{url} && $rec{title} && defined($rec{text});
    my $url = $rec{url};
    utf8::upgrade($url);
    my $title = $rec{title};
    utf8::upgrade($title);
    my $fts_name = my_lc($title);
    my $text = $rec{text} || '';
    utf8::upgrade($text);
    # Only changes affecting the search object matter, so don't use $text directly
    my ($intro, $fts_start, $fts_rest) = $self->_munge_text($text);
    $title = encode('utf-8', $title, Encode::FB_CROAK);
    $fts_start = encode('utf-8', $fts_start, Encode::FB_CROAK);
    $fts_rest = encode('utf-8', $fts_rest, Encode::FB_CROAK);
    # Note that the SHA1 sum must be created while we're still dealing with
    # octets, rather than characters
    my $sha1 = sha1_hex(join(':', $url, $title, $fts_start, $fts_rest));
    # Try to avoid doubly encoded content
    for ($url, $title, $fts_start, $fts_rest) {
        $_ = decode('utf-8', encode('latin1', $_)) if /[ÃÂ]/;
    }
    my ($page_id, $prev_sha1) = $dbh->selectrow_array(
        "select page_id, page_sha1 from page where page_url = ?",
        {}, $url);
    $prev_sha1 ||= '';
    return if $sha1 eq $prev_sha1;
    $dbh->begin_work;
    if ($page_id) {
        #warn "updating $page_id\n";
        $dbh->do(
            "update page set page_title = ?, page_summary = ?, page_sha1 = ? where page_id = ?",
            {}, $title, $intro, $sha1, $page_id);
        $dbh->do(
            "update fts_page set page_name = ?, page_start = ?, page_all = ? where rowid = ?",
            {}, $fts_name, $fts_start, $fts_start.' '.$fts_rest, $page_id); 
    }
    else {
        #warn "inserting for $url\n";
        $dbh->do(
            "insert into page (page_url, page_title, page_summary, page_sha1) values (?, ?, ?, ?)",
            {}, $url, $title, $intro, $sha1);
        $page_id = $dbh->last_insert_id("","","","");
        $dbh->do(
            "insert into fts_page (rowid, page_name, page_start, page_all) values (?, ?, ?, ?)",
            {}, $page_id, $fts_name, $fts_start, $fts_start.' '.$fts_rest);
    }
    $dbh->commit;
}

sub delete {
    my $self = shift;
    my %parm = @_;
    my $dbh = $self->{dbh};
    die "need either id or url" unless $parm{id} || $parm{url};
    if ($parm{url} && !$parm{id}) {
        $parm{id} = $dbh->selectrow_array(
            "select page_id from page where page_url = ?",
            {}, $parm{url});
        return 0 unless $parm{id};
    }
    my $ret = $dbh->do("delete from page where page_id = ?", {}, $parm{id});
    $dbh->do("delete from fts_page where rowid = ?", {}, $parm{id});
    return int($ret);
}

sub search {
    my ($self, $query) = @_;
    utf8::upgrade($query);
    my $lquery = $self->_prepare_query($query); # mainly lowercasing
    my $sql = qq[
      select
        a.page_id as id,
        a.page_title as title,
        a.page_url as url,
        a.page_summary as summary,
        snippet(fts_page) as snippet,
        offsets(fts_page) as offsets
      from page a join fts_page b
        on a.page_id = b.rowid
      where fts_page match ?
      order by 6
    ];
    my $dbh = $self->{dbh};
    return $dbh->selectall_arrayref($sql, {Columns=>{}}, $lquery);
}

sub _prepare_query {
    # "standard" FTS syntax, not "enhanced"
    my ($self, $query) = @_;
    return my_lc($query) unless $query =~ / (?:OR|AND) /;
    my $lquery = '';
    while ($query) {
        if ($query =~ s/^(OR|AND)\s+//) {
            # keep OR, omit AND
            $lquery .= "$1 " unless $1 eq 'AND';
        }
        elsif ($query =~ s/\s*(\S+)\s+//) {
            $lquery .= my_lc($1)." ";
        }
        else {
            $lquery .= $query;
            last;
        }
    }
    $lquery =~ s/ $//;
    #warn "returning query='$lquery'\n";
    return $lquery;
}

sub my_lc {
    # TODO: Detect which lower casing method is appropriate
    # given the current environment.
    #
    # This REQUIRES use utf8 and use locale in a UTF-8 environment:
    my $s = shift;
    return lc($s);
    # This is not appropriate with 'use utf8' and 'use locale':
    #$s =~ tr/A-ZÁÉÍÓÚÝÞÆÖÐØÅ/a-záéíóúýþæöðøå/;
    #return $s;
}

sub _munge_text {
    my ($self, $txt) = @_;
    $txt =~ s{<script.*</script>}{}sg;
    $txt =~ s{<style.*</style>}{}sg;
    $txt =~ s{<[^>]*>}{ }g;
    $txt =~ s{\s+}{ }g;
    $txt =~ s{^ }{};
    $txt =~ s{ $}{};
    $txt =~ s{\&(\d+);}{chr($1)}ge;
    $txt =~ s{\&x([a-fA-F0-9]+);}{chr(hex($1))}ge;
    my $intro = substr($txt, 0, 256, '');
    my $fragment = '';
    $fragment = $1 if $intro =~ s/ (\S*)$//;
    my $start = my_lc($intro);
    $txt = $fragment . $txt if $fragment;
    my $rest = '';
    if ($txt) {
        $rest = my_lc($txt);
    }
    return ($intro, $start, $rest);
}

##########

package Renderer;
use IkiWiki;
use IkiWiki::CGI;
use HTML::Template;
use Encode qw/decode_utf8/;

sub new {
    my ($pk, %opt) = @_;
    my $class = ref($pk) || $pk;
    my $self = \%opt;
    bless($self, $class);
    $self->_init();
    return $self;
}

sub _init {
    my $self = shift;
    die "need CGI object" unless $self->{cgi};
    # at least filename must be added to this
    my %ht_opts = (
		filter => sub {
			my $text_ref = shift;
			${$text_ref} = decode_utf8(${$text_ref});
		},
		loop_context_vars => 1,
		die_on_bad_params => 0,
		parent_global_vars => 1,
    );
    $self->{ht_opts} = \%ht_opts;
    IkiWiki::loadindex();
}

sub render_fragment {
    my ($self, $tplname, %context) = @_;
    my $templatefile = IkiWiki::template_file("$tplname.tmpl");	
    die "Template file $tplname.tmpl not found" unless $templatefile;
    my %opts = %{ $self->{ht_opts} };
    $opts{filename} = $templatefile;
    my $template = HTML::Template->new(%opts);
	$template->param(
		title => 'search',
		wikiname => $config{wikiname},
		html5 => $config{html5},
        %context,
	);
    return $template->output;
}

sub render_page {
    my ($self, $title, $content, %params) = @_;
    my $cgi = $self->{cgi};
    return IkiWiki::cgitemplate($cgi, $title, $content, %params);
}

1;

__END__

=pod

=head1 NAME

IkiWiki::Plugin::sqlite_search - search backend for IkiWiki based on SQLite FTS

=head1 SYNOPSIS

This is a full text search module for IkiWiki which uses SQLite as a backend.
It requires the DBD::SQLite Perl module, but otherwise has very few
dependencies.

IkiWiki has an official search module based on Xapian, which is very fast and
efficient but may not be available on your system. Installing Xapian, along
with the omega CGI program, may be impractical because of the platform on
which your site is hosted, or perhaps because your control over the web server
is too limited. In such cases, the sqlite_search plugin is an acceptable
substitute.

=head1 INSTALLATION

=over

=item 1.

B<Install the library.> Normally it goes into F<~/.ikiwiki/IkiWiki/Plugin/>,
but you may prefer some other location in your Perl path.

=item 2.

B<Configure IkiWiki.> This involves editing your F<*.setup> file. Under the
key C<add_plugins:>, add a list item: C<- sqlite_search>. (If there is a line
that reads C<- search>, comment it out -- the official search plugin and
sqlite_search cannot both be active at the same time).

=item 3.

B<Install templates.> The templates F<search-result-form.tmpl> and
F<search-result.tmpl> must be copied to an appropriate location. This is
normally in the F<templates/> folder of your project. The templates may of
course be modified if you like.

=item 4.

B<Run ikiwiki -setup> on your F<*.setup> file. This creates the text index
if needed and refreshes it otherwise.

=back

=head1 CAVEATS

=over

=item *

Pagination has not been implemented yet. The whole set of results is displayed
on one page.

=item *

Although UTF-8 encoding is used by the backend, the summary and snippet
extraction features pretty much assume a language using a Latin alphabet,
although Cyrillic and Greek might be all right. Asian languages almost
certainly will not work well.

=item *

On a related note, the locale under which the F<ikiwiki.cgi> program runs
should use the UTF-8 character set -- at least if you have any non-ascii
content which you want to be searcheable.

=item *

This module is not suitable for big sites. A few hundred pages is fine, but a
few thousand may be a problem.

=back

=head1 AUTHOR AND VERSION

Baldur Kristinsson, L<http://github.com/bk>.

This is version 0.2, December 2014.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2014 by Baldur Kristinsson.

This is free software with a dual Artistic/GPL license. The terms for using,
copying, distributing and modifying it are the same as for Perl 5.

=cut
