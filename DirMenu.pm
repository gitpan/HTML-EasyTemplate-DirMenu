package HTML::EasyTemplate::DirMenu;
use HTML::EasyTemplate;
use HTML::TokeParser;
use strict;
use Cwd;
use warnings;

our $VERSION = 0.61;		# 10/05/2001

=head1 NAME

HTML::EasyTemplate::DirMenu - HTML menus of directories.

=head1 DESCRIPTION

Provide an easy means of creating from a directory a representative block of HTML suitable for use as a substitution item in an HTML::Easytemplate, or as freestanding mark-up.

=head1 SYNOPSIS

Print a simple menu of HTML files in current working directory:

	use HTML::EasyTemplate;
	my $m = new HTML::EasyTemplate::DirMenu (
		'START'			=> 'E:/www/leegoddard_com',
		'URL_ROOT'		=> 'http://leegoddard_com',
		'MODE'			=> 'files',
		'TITLE_FROM'	=> 'title',
		'LIST_START'	=> '<DIV class="menu-layer">',
		'LIST_END'		=> '</DIV>',
		'ARTICLE_START'	=> '<DIV class="menu-item">',
		'ARTICLE_END'	=> '</DIV>',
		'DIR_START'		=> '<DIV class="dir-name>',
		'DIR_END'		=> '</DIV>',
	);
	print $m->{HTML};

Add the following lines to the above for a menu in an HTML::EasyTemplate, as C<TEMPLATEITEM name='menu1'> (based on the example provided in C<HTML::EasyTemplate>):

	use HTML::EasyTemplate::DirMenu;
	my %items = (
		'articleTitle'=> 'An Example Article',
		'articleText' => 'This is boring sample text: hello world...',
		'menu'		  => $m->{HTML},
	);
	my $TEMPLATE = new HTML::EasyTemplate('E:/WWW/leegoddard_com/FL/_templates/Template_Blank.html') or die "Couldn't make template!";
	$TEMPLATE->title("Latka Lover");
	$TEMPLATE -> process('fill',\%items);
	$TEMPLATE -> save( 'E:/WWW/leegoddard_com/FL/','new2.html');
	print "Saved the new document as <$TEMPLATE->{ARTICLE_PATH}>\n";
	__END__


=head1 DEPENDENCIES and PRAGMA

	EasyTemplate;
	cwd;
	HTML::TokeParser;
	strict;

=head1 Constructor method (new)

The method expects a package/class referemnce as it's first parameter.  Following that, arguments should be passed in the form of an anonymous hash or as name/value pairs:

	my $m = new HTML::EasyTemplate::DirMenu (
			'arg1'=>'val1','arg2'=>'val2',
	);

or:

	my $m = new HTML::EasyTemplate::DirMenu (
			{'arg1'=>'val1','arg2'=>'val2',}
	);

=head2 Arguments

=item MODE

Must be set to one of either 'all', 'dirs', 'files'.

=item START

The directory to menu, or at which to start menuing.

=item EXTENSIONS

Filter - a regular expression fragment applied to the filenames within a directory: insensitive to case, is bracketed, and matches after a dot, and is tied to the the end of the string:

	m/\.($HERE)$/i

Deafults to C<.*\.html?>.

=item PRINTEXTENSIONS

True or false to request that filename extensions, defined in the object's C<EXTENSIONS> slot above, be included or excluded in the printing of a filename.  Defaults to exclude.

=item EXC_DIRS, EXC_FILES

A regular expression to be applied against directories/files to decide exclusion.

=item TITLE_FROM

An HTML element within the doc, the first occurance of which will be accessed to get the text for the menu link. If it fails or is not supplied, will use the doc's filename.

=item LIST_START, LIST_END

HTML to put at the top and bottom of the menu output.

=item ARTICLE_START, ARTICLE_END

HTML to put at before and after each menu item.

=item HTMLDEFAULT

HTML to use when no files are found in a directory. Defaults to C<[No content]>.

=item TOPDIRTEXT

Text I<will be> used as top-level directory title.

=item ARTICLE_ROOT

The directory in which to begin work; defaults to the same value as the START slot detailed above.

The ARTICLE_ROOT is stripped from filepaths when creating HTML A href elements, and replaced with...

=item URL_ROOT

This slot is used as the BASE for created hyperlinks to files, instead of ARTICLE_ROOT, above.

=item URL_ROOT_TEXT

Text to use in a link that refers to C<URL_ROOT>.
=head2 Other Slots

=item HTML

It is in this slot that a single scalar representing the composed HTML menu will be found.

=item OUTPUT

Defaults to LIST, which produces HTML output using the options and defaults above.  Could be used to call another processing sub (in C<&new>) to output maybe a drop-down menu.

=cut


sub new { my ($class) = (shift);
	my %args;
	my $self = {};
	bless $self, $class;
	# Take parameters and place in object slots/set as instance variables
	if (ref $_[0] eq 'HASH'){	%args = %{$_[0]} }
	elsif (not ref $_[0]){		%args = @_ }

	# Set default values for public slots
	$self->{START} 				= cwd;
	$self->{URL_ROOT} 			= 'http://localhost/';
	$self->{URL_ROOT_TEXT}		= "Home";
	$self->{EXTENSIONS}			= '.*\.(html?|asp)$';
	$self->{PRINTEXTENSIONS}	= 'false';
	$self->{LIST_START}			= '<UL>';
	$self->{LIST_END}			= '</UL>';
	$self->{ARTICLE_START}		= '<LI>';
	$self->{ARTICLE_END}		= '</LI>';
	$self->{DIR_START}			= '<BR><BIG>',
	$self->{DIR_END}			= '</BIG>',
	$self->{HTMLDEFAULT}		= '[No content]';
	$self->{TITLE_FROM}			= 'title';
	$self->{TOPDIRTEXT}			= 'Home';

	# Set/overwrite public slots with user's values
	foreach (keys %args) {	$self->{uc $_} = $args{$_} }

	# Force these to match
	$self->{ARTICLE_ROOT} = $self->{START} if exists $self->{START};
	$self->{START} = $self->{ARTICLE_ROOT} if exists $self->{ARTICLE_ROOT} and not exists $self->{ARTICLE_ROOT};
	warn "Please supply either the 'START' or 'ARTICLE_ROOT' parameter." and die if not exists $self->{START};
	warn "Please upply the MODE as either ALL, DIRS or FILES." and die if not exists $self->{MODE};
	warn "Please upply the MODE as either ALL, DIRS or FILES." and die if $self->{MODE}!~/^(DIRS|FILES|ALL)$/i;

	# Private slots
	$self->{HTML}		= '';
	$self->{DIRS}		= {};	# key = dirname; value = [file1 .. fileN]

	# Make the HTML and leave in {HTML} IF we can get the file paths
	if (not exists $self->{OUTPUT} or $self->{OUTPUT} =~/^LIST$/){
		$self->create_html if $self->collect_this_dir ( $self->{START} );
	}

	elsif ($self->{OUTPUT} =~/^MENU$/){
		$self->create_html if $self->collect_this_dir ( $self->{START} );
	}
	return $self;
}



=head1 METHOD collect_this_dir

Collects content info of a directory, the path to which it accepts as it's sole argument.

Returns undef on failure.

=cut

sub collect_this_dir { my ($self,$dir)= (shift,shift);
	warn "Usage: \$self->collect_this_dir (\$dir_to_look_in)" and return undef if not $dir;
	warn "Dir supplied does not exist: $!" if not chdir $dir;
	local *DIR;
	my $dir_mod = $self->dir2url($dir);

	opendir DIR, $dir
						or warn "Passed dir <$dir> can't be opened: does it exist?"
						and return undef;
	my @read_dir = (grep {!-d and /($self->{EXTENSIONS})$/i} sort readdir DIR);
	closedir DIR;

	# Include the files in this directoyr in the menu?
	if ($self->{MODE}=~/^(ALL|FILES)$/i){
		foreach my $fn (@read_dir){
			my $link_text='';
			my $p;
			next if exists $self->{EXC_FILES} and $fn=~m/$self->{EXC_FILES}/sgi;
			$link_text = $p->get_trimmed_text
				if exists $self->{TITLE_FROM}
				and $p = HTML::TokeParser->new("$dir/$fn")
				and $p->get_tag(lc $self->{TITLE_FROM});
			$link_text = $fn if $link_text eq '';
			push @{$self->{DIRS}->{$dir_mod}}, {LINK => "$dir_mod/$fn", TEXT=>$link_text,};
		}
	}

	# Include sub-dirs in the menu?
	if ($self->{MODE}=~/^(ALL|DIRS)$/i and $#read_dir>-1){
		opendir DIR, $dir;
		foreach my $dn (grep {-d and !/^\.{1,2}$/} readdir DIR){
			next if exists $self->{EXC_DIRS} and $dn=~m/$self->{EXC_DIRS}/sgi;
			if (exists $self->{RECURSE} and $self->{RECURSE} =~ m/^(true|yes)$/i){
				$self->collect_this_dir( $dir.'/'.$dn );
			} else {
				# Just add link to this dir
				push @{$self->{DIRS}->{$dir_mod}}, {LINK => $dir_mod.'/'.$dn, TEXT => $self->dir2txt($dir_mod.'/'.$dn), ISDIR => 1,};
			}
		}
		closedir DIR;
	}

	return 1;
}






=head1 METHOD create_html

Fills the calling object's HTML slot detailed in the constructor method's documentation.

Incidentaly returns that HTML.

=cut

sub create_html { my $self = shift;
#use Data::Dumper;print Dumper($self);exit;
	$self->{HTML} = "\n<!-- LIST_START follows -->\n" . $self->{LIST_START} . "\n\n";
	if ($self->{DIRS} eq {}) {			# Create the menu if dirs were found
		$self->{HTML} .= "\t$self->{ARTICLE_START}\n\t\t$self->{HTMLDEFAULT}\n\t$self->{ARTICLE_END}\n\n";
	} else {
		foreach my $dir (sort keys %{$self->{DIRS}} ){
			my $dir_mod = $self->dir2url($dir);
			if (exists $self->{URL_ROOT}){
				$dir_mod =~ s/^($self->{URL_ROOT})// if defined $self->{ARTICLE_ROOT};
			} elsif (defined $main::ARTICLE_ROOT) {
				$dir_mod =~ s/^($main::URL_ROOT)// if defined $main::ARTICLE_ROOT;
			}
			$dir_mod = '/' if $dir_mod eq '';

			# Build link to this dir
			if ($self->{MODE}=~/^(ALL|DIRS)$/i){
				$self->{HTML} .= "\n<!-- Dir $dir -->\n";
				$self->{HTML} .= "\t$self->{DIR_START}" if exists $self->{DIR_START};
				my ($root, $seg);
				foreach (split '/',$dir_mod){
					$root .= $_.'/';
					next if $_ eq '' or $self->{URL_ROOT} =~ m/^$root/;
					$seg .= " <A href='$root'>$_</A>";
				}
				$self->{HTML} .= "\t$seg\t";
				$self->{HTML} .= "\t$self->{DIR_END}\n" if exists $self->{DIR_END};;
			}

			# Build links to files
			foreach (@{$self->{DIRS}->{$dir}}){
				if ($self->{MODE}=~/^(ALL|DIRS)$/i and exists $self->{$dir}->{ISDIR}){
					next;
					$self->{HTML} .= "\n<!-- Dir $dir -->\n";
					$self->{HTML} .= "\t$self->{DIR_START}" if exists $self->{DIR_START};
					my ($root, $seg);
					foreach (split '/',$dir_mod){
						next if $_ eq '';
						$root .= '/'.$_;
						$seg .= "/<A href='$root'>$_</A>";
					}
					$self->{HTML} .= "\t$seg\t";
					$self->{HTML} .= "\t$self->{DIR_END}\n" if exists $self->{DIR_END};;
				}

				else {
					$self->{HTML} .= "\t$self->{ARTICLE_START}\n";
					$self->{HTML} .= "\t\t<A href='$_->{LINK}'>";
					if (exists $self->{PRINTEXTENSIONS} and $self->{PRINTEXTENSIONS} !~ m/^(false|no)$/i) {
						$self->{HTML} .= $_->{TEXT};
					} else {
						$_->{TEXT} =~ s/\.($self->{EXTENSIONS})$//gi;
						$self->{HTML} .= $_->{TEXT};
					}
					$self->{HTML} .= "</A>\n";
					$self->{HTML} .= "\t$self->{ARTICLE_END}\n";
				}
			} # Next file in dir
		}	# Next dir
	} # End if
	$self->{HTML} .= "\n<!-- LIST_END follows -->\n" . $self->{LIST_END} ."\n\n";
	return $self->{HTML};
}


#
# Take dir path and return url
#
sub dir2url { my ($self,$dir_mod) = (shift,shift);
	if (exists $self->{ARTICLE_ROOT}){
		$dir_mod =~ s/^($self->{ARTICLE_ROOT})// if defined $self->{ARTICLE_ROOT};
	} elsif (defined $main::ARTICLE_ROOT) {
		$dir_mod =~ s/^($main::ARTICLE_ROOT)// if defined $main::ARTICLE_ROOT;
	}
	if (exists $self->{URL_ROOT}) {
		$dir_mod = $self->{URL_ROOT}.$dir_mod;
	} elsif (defined $main::ARTICLE_ROOT){
		$dir_mod = $main::URL_ROOT.$dir_mod if $main::URI_ROOT;
	} else {
		$dir_mod = $main::ARTICLE_ROOT . $dir_mod;
	}
}


#
# Take dir path and return last dir in path
#
sub dir2txt { my ($self,$dirpath) = (shift,shift);
	if ($dirpath eq $self->{URL_ROOT}) {
		$dirpath = $self->{URL_ROOT_TEXT};
	}
	elsif ($dirpath =~ m/\/([^\/]+)$/) {
		$dirpath = $1
	} else {
		$dirpath = $self->{TOPDIRTEXT};
	}
	return $dirpath;
}


1; # Return a true value for 'use'

=head1 CAVEATS

=item *

Does not list directories empty of files mathcing the search pattern.

=item *

If called with C<RECURSE=>'false'>, directories will displayed as if they were files. This may change.

=item *

Whilst this has been fully tested on non-recursive functions, more time needs to be spent on RECURSE method before we get to version 1.0.

=head1 TODO

=item *

Sort listings alphabetically.

=head1 SEE ALSO

	HTML::TokeParser
	HTML::EasyTemplate
	HTML::EasyTemplate::PageMenu
	HTML::EasyTemplate::BuildMySite

=head1 AUTHOR

Lee Goddard (LGoddard@CPAN.org)

=head1 COPYRIGHT

Copyright 2000-2001 Lee Goddard.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

