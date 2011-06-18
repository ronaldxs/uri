class URI;

use IETF::RFC_Grammar;
use IETF::RFC_Grammar::URI;
use URI::Escape;

has $.uri;  # use of this now deprecated

has $.grammar is ro;
has $!path;
has Bool $!is_absolute is ro;
has $!scheme;
has $!authority;
has $!query;
has $!frag;
has %!query_form;

has @.segments;

method parse (Str $str) {

    # clear string before parsing
    my $c_str = $str;
    $c_str .= subst(/^ \s* ['<' | '"'] /, '');
    $c_str .= subst(/ ['>' | '"'] \s* $/, '');

    $!uri = $!path = $!is_absolute = $!scheme = $!authority = $!query =
        $!frag = Mu;
    %!query_form = @!segments = Nil;

    try {
        $!grammar.parse($c_str);
    }
    CATCH {
        die "Could not parse URI: $str";
    }

    # now deprecated
    $!uri = $!grammar.parse_result;

    my $comp_container = $!grammar.parse_result<URI_reference><URI> //
        $!grammar.parse_result<URI_reference><relative_ref>;
    $!scheme = $comp_container<scheme>;
    $!query = $comp_container<query>;
    $!frag = $comp_container<fragment>;
    $comp_container = $comp_container<hier_part> // $comp_container<relative_part>;

    $!authority = $comp_container<authority>;
    $!path =    $comp_container<path_abempty>       //
                $comp_container<path_absolute>      ;
    $!is_absolute = ?($!path // $.scheme);

    $!path //=  $comp_container<path_noscheme>      //
                $comp_container<path_rootless>      ;

    @!segments = $!path<segment>.list() // ('');
    if my $first_chunk = $!path<segment_nz_nc> // $!path<segment_nz> {
        unshift @!segments, $first_chunk;
    }
    if @!segments.elems == 0 {
        @!segments = ('');
    }
#    @!segments ||= ('');

    try {
        %!query_form = split_query( ~$!query );
    }
    CATCH {
        %!query_form = Nil;
    }
}

sub split_query(Str $query) {
    my %query_form;

    for map { [split(/<[=]>/, $_) ]}, split(/<[&;]>/, $query) -> $qmap {
        for (0, 1) -> $i { # could go past 1 in theory ...
            $qmap[ $i ] ~~ s:g/\+/ /;
            $qmap[ $i ] = uri_unescape($qmap[ $i ]);
        }
        if %query_form.exists($qmap[0]) {
            if %query_form{ $qmap[0] } ~~ Array  {
                %query_form{ $qmap[0] }.push($qmap[1])
            }
            else {
                %query_form{ $qmap[0] } = [
                    %query_form{ $qmap[0] }, $qmap[1]
                ]
            }
        }
        else {
            %query_form{ $qmap[0]} = $qmap[1]
        }
    }

    return %query_form;
}

# deprecated old call for parse
method init ($str) {
    $.parse($str);
}

# new can pass alternate grammars some day ...
submethod BUILD {
    $!grammar = IETF::RFC_Grammar.new('rfc3896');
}

method new(Str $str?) {
    my $obj = self.bless(*);

    if ($str.defined) {
        $obj.parse($str);
    }

    return $obj;
}

method scheme {
    return ~$!scheme.lc;
}

method authority {
    return ~$!authority.lc;
}

method host {
    return ($!authority<host> // '').lc;
}

method port {
    item $!authority<port> // '';
}

method path {
    return ~($!path // '').lc;
}

method absolute {
    return $!is_absolute;
}

method relative {
    return ! $.absolute;
}

method query {
    item ~($!query // '');
}
method frag {
    return ~($!frag // '').lc;
}

method fragment { $.frag }

method Str() {
    my $str;
    $str ~= $.scheme if $.scheme;
    $str ~= '://' ~ $.authority if $.authority;
    $str ~= $.path;
    $str ~= '?' ~ $.query if $.query;
    $str ~= '#' ~ $.frag if $.frag;
    return $str;
}

# chunks now strongly deprecated
# it's segments in p5 URI and segment is part of rfc so no more chunks soon!
method chunks {
    return @!segments;
}

method query_form {
    return %!query_form;
}

=begin pod

=head NAME

URI — Uniform Resource Identifiers (absolute and relative)

=head SYNOPSYS

    use URI;
    my $u = URI.new('http://her.com/foo/bar?tag=woow#bla');

    my $scheme = $u.scheme;
    my $authority = $u.authority;
    my $host = $u.host;
    my $port = $u.port;
    my $path = $u.path;
    my $query = $u.query;
    my $frag = $u.frag; # or $u.fragment;
    my $tag = $u.query_form<tag>; # should be woow

    my $is_absolute = $u.absolute;
    my $is_relative = $u.relative;

    # something p5 URI without grammar could not easily do !
    my $host_in_grammar =
        $u.grammar.parse_result<URI_reference><URI><hier_part><authority><host>;
    if ($host_in_grammar<reg_name>) {
        say 'Host looks like registered domain name - approved!';
    }
    else {
        say 'Sorry we do not take ip address hosts at this time.';
        say 'Please use registered domain name!';
    }

=end pod


# vim:ft=perl6
