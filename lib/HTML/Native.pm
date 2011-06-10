package HTML::Native;

# Copyright (C) 2011 Michael Brown <mbrown@fensystems.co.uk>.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=head1 NAME

HTML::Native - Generate and manipulate HTML as native Perl data structures

=head1 SYNOPSIS

    use HTML::Native qw ( is_html_element );

    # Create some HTML
    my $html = HTML::Native->new (
      div => { class => "main" },
      [ img => { src => "logo.png", alt => "logo" } ],
      [ div => { class => "welcome" },
        [ h1 => "Hello!" ],
        "This is some text",
      ],
      [ div => { class => "footer" },
        "Generated by HTML::Native",
      ],
    );

    # Create a link element
    my $link = HTML::Native->new ( a => { href => "/home" }, "Home" );
    # Modify the href attribute
    $link->{href} = "/home.html";
    # Print the modified link
    print $link;   # prints "<a href="/home.html">Home</a>"

    # Strip out any <img> elements within a block of HTML
    @$html = grep { ! is_html_element ( $_, "img" ) } @$html;

    # Convert any <h1> elements within a block of HTML to <h2>
    do { $$_ =~ s/h1/h2/ if is_html_element ( $_ ) } foreach @$html;

    # Find all elements with a class of "error"
    grep { is_html_element ( $_ ) && $_->{class}->{error} } @$html;

=head1 DESCRIPTION

L<HTML::Native> allows you to treat an HTML document tree as a native
Perl data structure built using arrays and hashes.

Consider the HTML element:

    <div class="main">Hello world!</div>

This could be constructed as an L<HTML::Native> object using:

    my $elem = HTML::Native->new (
      div => { class => "main" },
      "Hello world!",
    );

The object C<$elem> is a magic variable that provides access to the
name (C<div>), the attributes (C<class="main">), the contents (the
text "Hello world!"), and the resulting generated HTML.

=head2 GENERATED HTML (STRINGIFICATION)

You can treat C<$elem> as a string in order to obtain the generated
HTML.  For example:

    print $elem;
    # prints "<div class="main">Hello world!</div>"

This is equivalent to calling C<< $elem->html() >>.

=head2 ELEMENT NAME (SCALAR REFERENCE)

You can treat C<$elem> as a scalar reference in order to access the
element name.  For example:

    print $$elem;  # prints "div"
    $$elem = "p";  # change from <div> to <p>
    print $elem;
    # now prints "<p class="main">Hello world!</p>"

=head2 ATTRIBUTES (HASH REFERENCE)

You can treat C<$elem> as a hash reference in order to access the
element attributes.  For example:

    print $elem->{class};  # prints "main"
    $elem->{class}->{error} = 1;  # apply class="error"
    print $elem;
    # now prints "<p class="error main">Hello world!</p>"

The attributes have some additional magical behaviour, such as the
ability to treat an attribute as a scalar:

    $elem->{class} = "error"

or as a hash:

    $elem->{class}->{error} = 1;

or as an array:

    $elem->{class} = [ "error" ];

See L<HTML::Native::Attribute> for further details.

=head2 CONTENTS (ARRAY REFERENCE)

You can treat C<$elem> as an array reference in order to access the
element contents.  For example:

    print $elem->[0];  # prints "Hello world!"
    push @$elem, [ img => { src => "logo.png" } ];  # append <img>
    print $elem;
    # now prints:
    #  "<p class="error main">Hello world!<img src="logo.png" /></p>"

The contents have some additional magical behaviour, such as the
ability to automatically construct descendant L<HTML::Native> objects:

    push @$elem, [ img => { src => "logo.png" } ];  # append <img>
    print $elem->[-1];  # prints "<img src="logo.png" />"
    print $elem->[-1]->{src}  # prints "logo.png"

See L<HTML::Native::List> for further details.

=head1 PHILOSOPHY

Perl has a rich, natural, and extremely efficient syntax for
manipulating tree-like data structures.  L<HTML::Native> allows you to
use this syntax to manipulate an HTML document tree.  For example:

    # Mark the link to the current page with class="active"
    foreach my $link ( @$navbar ) {
      $link->{class}->{active} = ( $link->{href} eq $current );
    }

    # Wrap any <table> elements inside a <div class="results"> element
    foreach my $elem ( @$list ) {
      $elem = HTML::Native->new ( div => { class => "results" }, $elem )
        if is_html_element ( $elem, "table" );
    }

L<HTML::Native> is an alternative to mixed-language modules such as
L<Template|Template Toolkit> and L<HTML::Mason>, and to method-based
modules such as L<HTML::Tree>.  L<HTML::Native> aims to provide the
most naturally Perlish way of generating and manipulating an HTML
document tree.  Compare the code required to conditionally add an
atttribute C<< class="fatal" >> to a C<< <div> >> element based on the
variable C<$fatal>:

=over 4

=item Hand-crafted HTML

Mixed HTML and Perl:

    "<div class=\"error".( $fatal ? " fatal" : "" )."\">"

=item L<Template|Template Toolkit>

Mixed HTML and Perl with custom markup syntax:

    <div class="error[% $fatal ? " fatal" : "" %]">

=item L<HTML::Mason>

Mixed HTML and Perl with custom markup syntax:

    <div class="error<% $fatal ? " fatal": "" %>">

=item L<HTML::Tree>

Pure Perl using method calls:

    $div->attr ( "class",
		 $div->attr ( "class" )." fatal" ) if $fatal;

=item L<HTML::Native>

Pure Perl:

    $div->{class}->{fatal} = $fatal;

=back

=head1 METHODS

=cut

use Scalar::Util qw ( blessed weaken );
use Exporter qw ( import );
use HTML::Native::List;
use HTML::Native::Attributes;
use strict;
use warnings;

use 5.009_005;
our $VERSION = "1.0.1";

our @EXPORT_OK = qw ( is_html_element is_html_attributes is_html_list );
our %EXPORT_TAGS = ( all => [ @EXPORT_OK ] );

use overload
    '""' => sub { my $self = shift; return $self->html; },
    '${}' => sub { my $self = shift; return \&$self->{SCALAR}; },
    '%{}' => sub { my $self = shift; return &$self->{HASH}; },
    '@{}' => sub { my $self = shift; return &$self->{ARRAY}; },
    fallback => 1;

=head2 new()

    $elem = HTML::Native->new ( <name> => );

    $elem = HTML::Native->new ( <name> => { <attributes> } );

    $elem = HTML::Native->new ( <name> => <content>, ... );

    $elem = HTML::Native->new ( <name> => { <attributes> },
                                <content>, ... );

Create a new L<HTML::Native> object, representing a single HTML
element with the specified name (such as C<div>).  For example:

    my $elem = HTML::Native->new ( div => );
    print $elem; # prints "<div />"

The attributes (such as C<< class="error" >>) are optional, and can be
provided as an anonymous hash (or a ready-made
L<HTML::Native::Attributes> object, if you prefer).  For example:

    my $elem = HTML::Native->new ( div => { class => "error" } );
    print $elem; # prints "<div class="error" />"

Any remaining arguments are taken to be the contents of the element.
For example:

    my $elem = HTML::Native->new ( div => { class => "error" },
				   "Something happened" );
    print $elem; # prints "<div class="error">Something happened</div>"

Any anonymous arrays within the contents will be automatically
converted into new L<HTML::Native> objects.  For example:

    my $elem = HTML::Native->new (
      div => { class => "error" },
      [ img => { src => "error.png" } ],
      "Something happened",
      [ div =>
	[ a => { href => "retry" }, "Try again" ],
	[ a => { href => "cancel" }, "Give up" ],
      ],
    );
    print $elem;
    # prints (on a single line):
    #   <div class="error">
    #     <img src="error.png" />
    #     Something happened
    #     <div>
    #       <a href="retry">Try again</a>
    #       <a href="cancel">Give up</a>
    #     </div>
    #   </div>

To create a list of multiple L<HTML::Native> elements that are not
(yet) contained within a single parent element, you can use
L<HTML::Native::List>.  For example:

    my $content = HTML::Native::List->new (
      [ a => { href => "/home" }, "Home" ],
      [ a => { href => "/edit" }, "Edit" ],
      [ a => { href => "/logout" }, "Logout" ],
    );

    my $elem = HTML::Native->new ( div => { class => "navbar" },
				   $content );

=cut

sub new {
  my $old = shift;
  my $class = ref $old || $old;
  my $name = shift;
  my $attributes = ( ( ( ref $_[0] eq "HASH" ) || is_html_attributes ( $_[0] ) )
		     ? shift : {} );
  my $children = ( is_html_list ( $_[0] ) ? shift : \@_ );

  # Convert unblessed attributes to HTML::Native::Attributes
  $attributes = $class->new_attributes ( $attributes )
      unless blessed ( $attributes );

  # Convert children to HTML::Native::List
  $children = $class->new_children ( $children )
      unless blessed ( $children );

  # Expose name via scalar dereference, attributes via hash
  # dereference, and children via array dereference.  Since hash
  # dereference is itself overloaded, we use an anonymous sub to gain
  # access to the underlying hash containing the real data.
  my $data = {
    SCALAR => $name,
    HASH => $attributes,
    ARRAY => $children,
    bookmarks => {},
  };
  my $self = sub { $data; };

  bless $self, $class;
  return $self;
}

=head2 html()

    $html = $elem->html();

    $elem->html ( <callback> );

Generate the HTML serialisation of the element and all its
descendants.  For example:

    my $elem = HTML::Native->new (
      div => { class => "error" },
      [ img => { src => "error.png" } ],
      "Oh dear",
    );
    my $html = $elem->html();
    print $html;
    # prints "<div class="error"><img src="error.png" />Oh dear</div>"

You can use stringification as a shortcut for calling C<html()>.  For
example:

    print $elem;
    # prints "<div class="error"><img src="error.png" />Oh dear</div>"

HTML entity encoding will be applied as necessary.  For example:

    my $elem = HTML::Native->new ( div => "I <3 you" );
    print $elem;
    # prints "<div>I &lt;3 you</div>"

=head3 CALLBACK

You can optionally pass a callback function which will be called with
each successive fragment of HTML.  For example:

    $elem->html ( sub { print FH, shift; } );

would print each fragment of HTML directly to the filehandle C<FH> as
soon as it is generated, rather than building up a single string
containing the entirety of the generated HTML.

=cut

sub html {
  my $self = shift;
  my $html = "";
  my $callback = shift || sub { $html .= shift; };

  my $name = $$self;
  my $attributes = \%$self;
  my $children = \@$self;

  if ( @$children ) {
    &$callback ( "<".$name.$attributes.">" );
    $children->html ( $callback );
    &$callback ( "</".$name.">" );
  } else {
    &$callback ( "<".$name.$attributes." />" );
  }
  return $html;
}

=head2 bookmark()

    $elem->bookmark ( <name>, <reference> );

    $bookmarked = $elem->bookmark ( <name> );

Create or retrieve a named bookmark.  You can use bookmarks to provide
shortcut access to specific descendant elements.  For example:

    my $elem = HTML::Native->new (
      div =>
      [ h1 => "Welcome" ],
      "Hello world",
    );
    $elem->bookmark ( "heading", $elem->[0] );

    my $h = $elem->bookmark ( "heading" );
    print $h;
    # prints "<h1>Welcome</h1>"

Bookmarks hold weakened references, and so will become undefined if
the bookmarked element is deleted.  For example:

    print "exists" if $elem->bookmark ( "heading" );  # prints "exists"
    delete $elem->[0];
    print "exists" if $elem->bookmark ( "heading" );  # prints nothing

=cut

sub bookmark {
  my $self = shift;
  my $bookmark = shift;
  my $bookmarks = &$self->{bookmarks};

  if ( @_ ) {
    $bookmarks->{$bookmark} = shift;
    weaken $bookmarks->{$bookmark};
  }

  return $bookmarks->{$bookmark};
}

=head1 FUNCTIONS

L<HTML::Native> provides a selection of functions that may be useful
to code that manipulates L<HTML::Native> objects.

To use any of these functions, include them in the import list for
L<HTML::Native>.  For example:

    use HTML::Native qw ( is_html_element );

    use HTML::Native qw ( is_html_element is_html_attributes );

    use HTML::Native qw ( :all );

Note that these are plain functions; they are I<not> class or object
methods.

=head2 is_html_element()

    $is_element = is_html_element ( <thing> );

    $is_named_element = is_html_element ( <thing>, <name> );

Determine whether or not something is an L<HTML::Native> object
representing an HTML element.  This is useful when using functions
such as C<map> or C<grep> to operate on lists that contain a mixture
of L<HTML::Native> objects and plain-text content.  For example:

    # Find all elements with class="error" within a <div> element
    @errors = grep { is_html_element ( $_ ) && $_->{class}->{error} }
		   @$elem;

You can optionally specify a name in order to select only elements
with the specified (case-insensitive) name.  For example:

    # Add class="logo" to any <img> elements within a <div> element
    do { $_->{class}->{logo} = 1 if is_html_element ( $_, "img" ) }
       foreach @$elem;

=cut

sub is_html_element {
  my $thing = shift;
  my $name = shift;

  return unless ( blessed ( $thing ) && $thing->isa ( "HTML::Native" ) );
  return ( $name ? ( lc $name eq lc $$thing ) : 1 );
}

=head2 is_html_attributes()

    $is_attributes = is_html_attributes ( <thing> );

Determine whether or not something is an L<HTML::Native::Attributes>
object representing the attributes of an HTML element.

=cut

sub is_html_attributes {
  my $thing = shift;

  return ( blessed ( $thing ) && $thing->isa ( "HTML::Native::Attributes" ) );
}

=head2 is_html_list()

    $is_list = is_html_list ( <thing> );

Determine whether or not something is an L<HTML::Native::List> object
representing the contents of an HTML element.

=cut

sub is_html_list {
  my $thing = shift;

  return ( blessed ( $thing ) && $thing->isa ( "HTML::Native::List" ) );
}

=head1 SUBCLASSING

When subclassing L<HTML::Native>, you may wish to override the class
that is used by default to hold element attributes and contents.  You
can do this by overriding the C<new_attributes()> and/or
C<new_children> methods:

=head2 new_attributes()

    $attrs = $self->new_attributes ( { <attributes> } );

The default implementation of this method simply calls
C<< HTML::Native::Attributes->new() >>:

    return HTML::Native::Attributes->new ( shift );

=cut

sub new_attributes {
  my $self = shift;
  my $attributes = shift;

  return HTML::Native::Attributes->new ( $attributes );
}

=head2 new_children()

    $children = $self->new_children ( <children> );

The default implementation of this method simply calls
C<< HTML::Native::List->new() >>:

    my $children = shift;
    return HTML::Native::List->new ( @$children );

=cut

sub new_children {
  my $self = shift;
  my $children = shift;

  return HTML::Native::List->new ( @$children );
}

=head1 ADVANCED

=head2 EMPTY ELEMENTS

L<HTML::Native> will generate XHTML-style self-closing tags for
elements that are empty (i.e. have no contents).  For example:

    my $elem = HTML::Native->new ( img => { src => "logo.png",
					    alt => "logo" } );
    print $elem;
    # prints "<img src="logo.png" alt="logo" />"

To force an HTML-style separate closing tag even when the element is
empty, you can use an empty string as the element contents.  For
example:

    my $elem = HTML::Native->new ( p => "" );
    print $elem;
    # prints "<p></p>" rather than "<p />"

=head2 LITERALS

You may wish to prevent some of your content from being
entity-encoded.  You can do this using L<HTML::Native::Literal>.  For
example:

    my $elem = HTML::Native->new (
      div =>
      ">>",
      HTML::Native::Literal->new ( "<p>byebye</p>" )
      "<<",
    );
    print $elem;
    # prints "<div>&gt;&gt;<p>byebye</p>&lt;&lt;</div>"

See also L<HTML::Native::JavaScript>, which will automatically handle
embedded JavaScript code correctly.

=head2 WHOLE-HASH OR WHOLE-ARRAY ASSIGNMENT

To completely replace all attributes of an L<HTML::Native> object, you
cannot use the syntax

    $elem = { <attributes }

since that would cause Perl to overwrite the L<HTML::Native> object
itself.  Instead, you must use the syntax

    %$elem = ( <attributes )

For example:

    %$elem = ( class => "error" )

Similarly, to replace all contents of an L<HTML::Native> object, you
must use the syntax:

    @$elem = ( <children> )

For example:

    @$elem = ( [ img => { src => "logo.png", alt => "logo" } ],
	       "Welcome to my website" );

=head2 DYNAMIC GENERATION

You can use anonymous subroutines (closures) to dynamically generate
portions of an L<HTML::Native> element tree.  For example:

    my $error = { text => "" };
    my $elem = HTML::Native->new (
      div => { class => sub { return { error => 1,
				       fatal => $error->{is_fatal} }; },
             },
      "Error:",
      [ p => sub { return $error->{text} } ],
    );
    print $elem;
    # prints "<div class="error">Error:<p></p></div>"

    $error->{is_fatal} = 1;
    $error->{text} = "It crashed";
    print $elem;
    # now prints
    #   "<div class="error fatal">Error:<p>It crashed</p></div>"

See L<HTML::Native::Attributes> and L<HTML::Native::List> for further
details.

=head1 SEE ALSO

=over 4

=item L<HTML::Native::Attribute>

=item L<HTML::Native::List>

=item L<HTML::Native::Document>

=item L<HTML::Native::Literal>

=item L<HTML::Native::Comment>

=item L<HTML::Native::JavaScript>

=back

=head1 AUTHOR

Michael Brown <mbrown@fensystems.co.uk>

=head1 COPYRIGHT & LICENSE

Copyright (C) 2011 Michael Brown <mbrown@fensystems.co.uk>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or any
later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=cut

1;
