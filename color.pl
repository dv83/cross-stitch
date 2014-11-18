#!/usr/bin/perl

use strict;

use utf8;

use POSIX qw (sprintf);
use LWP::Simple;
use GD;
use Data::Dumper;

use constant GRAYSCALE => 0;
use constant GRAYSCALE_SIGN => 10;

use constant MIXED_COLORS => 1;
use constant MIXED_COLORS_SIGN => 25;

use constant STANDARD => 'DMC';
#use constant STANDARD => 'GAMMA';
#use constant STANDARD => 'ANCHOR';
#use constant STANDARD => 'MADEIRA';

use constant SPACE => 0;
use constant SIZE => 2;
use constant SPACE2 => 1;
use constant SIZE2 => 12;

my $__standard = STANDARD;

my @bgs = qw ( FFFFFF CCFF66 99FFFF 33FF99 FF9999 FFFF33 );
#my @bgs = qw ( FFFFFF 888888 EFEFEF 989898 DFDFDF A8A8A8 CFCFCF B8B8B8 BFBFBF C8C8C8 AFAFAF D8D8D8 9F9F9F E8E8E8 8F8F8F F8F8F8 );
#my @bgs = qw ( FFFFFF F8F8F8 EFEFEF E8E8E8 DFDFDF D8D8D8 CFCFCF C8C8C8 BFBFBF B8B8B8 );
my $bgcnt = 0;

$| = 1;

print "Start\n";

# download colors

my $url = 'http://www.fabrics.ru/color_map/Muline5Colour.htm';

my $c = get $url;

# parse it

$c =~ s/^.*?(<table.*?<\/table>).*$/$1/s;
$c =~ s/[\n\r\t]//g;

my $standard = {
    'DMC' => {},
    'GAMMA' => {},
    'ANCHOR' => {},
    'MADEIRA' => {}
};

my $standard_cnt = {
    'DMC' => 0,
    'GAMMA' => 0,
    'ANCHOR' => 0,
    'MADEIRA' => 0
};

my $standard_mix = {
    'DMC' => {},
    'GAMMA' => {},
    'ANCHOR' => {},
    'MADEIRA' => {}
};

my $standard_mix_cnt = {
    'DMC' => 0,
    'GAMMA' => 0,
    'ANCHOR' => 0,
    'MADEIRA' => 0
};

print "Parse\n";

while ($c =~ s/^.*?<tr>\s*<td([^>]+)>.*?<\/td>\s*<td[^>]+>(.*?)<\/td>\s*<td[^>]+>(.*?)<\/td>\s*<td[^>]+>(.*?)<\/td>\s*<td[^>]+>(.*?)<\/td>\s*<\/tr>//i) {

    my $color = $1;
    my $gamma = $2;
    my $dmc = $3;
    my $anchor = $4;
    my $madeira = $5;

    $color =~ s/\s+//g;
    $gamma =~ s/\s+//g;
    $dmc =~ s/\s+//g;
    $anchor =~ s/\s+//g;
    $madeira =~ s/\s+//g;

#    print '`'.$1.'`,`'.$2.'`,`'.$3.'`,`'.$4.'`,`'.$5."`\n";

    $color =~ s/white/#FFFFFF/o;
    $color =~ s/black/#000000/o;

    next unless $color =~ /bgcolor/o;

    $color =~ s/^.*?="#([\w\d]{6})".*?$/$1/;

    next unless $color =~ /^[\w\d]{6}$/o;

    my $red   = sprintf("%d", hex(uc substr($color, 0, 2)));
    my $green = sprintf("%d", hex(uc substr($color, 2, 2)));
    my $blue  = sprintf("%d", hex(uc substr($color, 4, 2)));

    next unless &grayscale_check($red, $green, $blue);

    # DMC

    $dmc =~ s/<palign.*?>//o;
    chomp($dmc);
    
    if ( $dmc && ( $dmc =~ /^\d+$/o || $dmc =~ /blanc/) ) {
	$standard_cnt->{'DMC'}++;
	push @{$standard->{'DMC'}->{$dmc}},
	{
	    'RGB' => $color,
	    'R' => $red,
	    'G' => $green,
	    'B' => $blue
	};
    }

    # Gamma
    
    $gamma =~ s/<palign.*?>//o;
    chomp($gamma);
    
    if ( $gamma && $gamma =~ /^\d+$/o ) {
	$standard_cnt->{'GAMMA'}++;
	push @{$standard->{'GAMMA'}->{$gamma}}, {
	    'RGB' => $color,
	    'R' => $red,
	    'G' => $green,
	    'B' => $blue
	};
    }

    # Anchor

    $anchor =~ s/<palign.*?>//o;
    $anchor =~ s/,.+$//o;
    chomp($anchor);
    
    if ( $anchor && $anchor =~ /^\d+$/o ) {
	$standard_cnt->{'ANCHOR'}++;
	push @{$standard->{'ANCHOR'}->{$anchor}}, {
	    'RGB' => $color,
	    'R' => $red,
	    'G' => $green,
	    'B' => $blue
	};
    }

    # Madeira

    $madeira =~ s/<palign.*?>//o;
    $madeira =~ s/,.+$//o;
    chomp($madeira);
    
    if ( $madeira && ( $madeira =~ /^\d+$/o || $madeira =~ /Black/ ) ) {
	$standard_cnt->{'MADEIRA'}++;
	push @{$standard->{'MADEIRA'}->{$madeira}}, {
	    'RGB' => $color,
	    'R' => $red,
	    'G' => $green,
	    'B' => $blue
	};
    }

}



# prepare additional mixed colors...

if ( MIXED_COLORS ) {

    foreach my $s ( 'DMC', 'GAMMA', 'ANCHOR', 'MADEIRA' ) {
	
	foreach my $icolor (keys %{$standard->{$s}}) {

	    foreach my $jcolor (keys %{$standard->{$s}}) {
		
		foreach my $i (@{$standard->{$s}->{$icolor}}) {
		    
		    foreach my $j (@{$standard->{$s}->{$jcolor}}) {
			
			next if $i->{R} == $j->{R} && $i->{G} == $j->{G} && $i->{B} == $j->{B}; # skip the same
			next if $icolor eq $jcolor; # skip the almost same
			
			my $dr = $i->{R} - $j->{R};
			my $dg = $i->{G} - $j->{G};
			my $db = $i->{B} - $j->{B};
			my $d = sqrt ( $dr ** 2 + $dg ** 2 + $db ** 2 );
			
			if ($d > 0.1 && $d <= MIXED_COLORS_SIGN) {
			    my $nr = int ( ( $i->{R} + $j->{R} ) / 2 );
			    my $ng = int ( ( $i->{G} + $j->{G} ) / 2 );
			    my $nb = int ( ( $i->{B} + $j->{B} ) / 2 );
				
			    $standard_mix_cnt->{$s}++;
			    push @{$standard_mix->{$s}->{$icolor.'+'.$jcolor}}, {
				'R' => $nr,
				'G' => $ng,
				'B' => $nb,
				'RGB' => uc ( sprintf("%02x", $nr) . sprintf("%02x", $ng) . sprintf("%02x", $nb) )
			    };
			}
			
		    }
		    
		}
		
	    }
	    
	}

    }
    
}



# load image

my $img = newFromJpeg GD::Image('color.jpg');

my ($w, $h) = $img->getBounds();



# prepare standard!

my $standard_cache = {};
my $standard_match = {};
my $standard_out = [];

foreach my $j (0..$h-1) {

    my $arr = [];

    foreach my $i (0..$w-1) {

        my ($r, $g, $b) = $img->rgb($img->getPixel($i,$j));
        
        my $standard_res = $standard_cache->{$r.'|'.$g.'|'.$b} || &get_standard($r, $g, $b);
        $standard_cache->{$r.'|'.$g.'|'.$b} ||= $standard_res;

        push @$arr, $standard_res;

        $standard_match->{$standard_res->{'standard'}}++;

    }

    push @$standard_out, $arr;

}



# print html table

my $htmlout  = "<html>\n<head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"><style> BODY { margin: 0; } table td { width: ".SIZE."px; height: ".SIZE."px; display: inline-block; white-space: nowrap; } </style></head>\n<body>\n<table cellspacing=".SPACE." cellpadding=0>\n";
my $htmlout2h = "<html>\n<head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"><style> BODY { margin: 0; } table, td { border: 1px solid gray; border-collapse: collapse; text-align: center; vertical-align: middle; width: ".SIZE2."px; height: ".SIZE2."px; display: inline-block; white-space: nowrap; font-size: ".SIZE2."px; } </style></head>\n<body>\n";
my $htmlout2s = '';
my $htmlout2 = "<table cellspacing=".SPACE2." cellpadding=0>\n";

my $signs_cache = {};
my $signs_std_cache = {};
my $signs_bg_cache = {};
my $signs_init = 2200;
#my $signs_init = 2701;

foreach my $j (0..$h-1) {

    $htmlout  .= "\t<tr>\n\t\t";
    $htmlout2 .= "\t<tr>\n\t\t";
    
    foreach my $i (0..$w-1) {

	my $_color = $standard_out->[$j][$i]->{'color'};
	my $_std = $standard_out->[$j][$i]->{'standard'};
        
        $htmlout .= "<td bgcolor=\"#".$_color."\">";
	my $ns = &new_sign($_color, $_std);
        $htmlout2 .= "<td bgcolor=\"".$signs_bg_cache->{$_color}."\">".$ns."</td>";
        
    }
    
    $htmlout .= "\n";
    $htmlout2 .= "\n";

}

$htmlout2s .= '<table><tr><td>symbol<td>code<td>color<td>#';

foreach (sort { $standard_match->{$b} <=> $standard_match->{$a} } keys %$standard_match) {
    $htmlout2s .= '<tr><td bgcolor="'.$signs_bg_cache->{$standard->{$__standard}->{$_}->[0]->{'RGB'}}.'">' . $signs_std_cache->{$_} . '<td>' . STANDARD . ' ' . $_ . '<td bgcolor="#' . ( $standard->{$__standard}->{$_}->[0]->{'RGB'} || $standard_mix->{$__standard}->{$_}->[0]->{'RGB'} ) . '">' . '<td>' . $standard_match->{$_};
}

$htmlout2s .= '</table><br/><br/>';

$htmlout  .= "</html>";
$htmlout2 .= "</html>";

open F, ">", "./color.html";
binmode F, ":utf8";
print F $htmlout;
close F;

open F, ">", "./color.signs.html";
binmode F, ":utf8";
print F $htmlout2h;
print F $htmlout2s;
print F $htmlout2;
close F;

open F, ">", "./color.standard_out";
binmode F, ":utf8";
print F Dumper($standard_out);
close F;

open F, ">", "./color.standard_all";
binmode F, ":utf8";
print F Dumper($standard);
close F;

open F, ">", "./color.standard_mix";
binmode F, ":utf8";
print F Dumper($standard_mix);
close F;

open F, ">", "./color.standard_cnt";
binmode F, ":utf8";
print F Dumper($standard_cnt);
print F Dumper($standard_mix_cnt);
close F;

open F, ">", "./color.standard_match";
binmode F, ":utf8";
foreach (sort { $standard_match->{$b} <=> $standard_match->{$a} } keys %$standard_match) {
    print F $_ . ( ' ' x ( 18 - length($_) ) ) . ' ' . $standard_match->{$_} . "\n";
}
close F;

exit;

# -------------------------------------------------------------------------------------




sub get_standard {
    my ($r, $g, $b) = @_;

    my $min = 300 * 300 * 300;
    my $out = undef;

    foreach my $color (keys %{$standard->{$__standard}}) {

        foreach (@{$standard->{$__standard}->{$color}}) {

            my $_min_r = $r - $_->{R};
            my $_min_g = $g - $_->{G};
            my $_min_b = $b - $_->{B};
            my $_min = sqrt ( $_min_r ** 2 + $_min_g ** 2 + $_min_b ** 2 );
            
            if ($_min < $min) {
                $min = $_min;
                
                $out = {
                    'origin' => { 'r0' => $r, 'g0' => $g, 'b0' => $b },
		    'standard' => $color,
		    'r' => $_->{R},
		    'g' => $_->{G},
		    'b' => $_->{B},
		    'color' => $_->{RGB},
		    'delta' => $_min
                };
            }

        }
    }

    if ( MIXED_COLORS ) {
	
	foreach my $color (keys %{$standard_mix->{$__standard}}) {
	    
	    foreach (@{$standard_mix->{$__standard}->{$color}}) {
		
		my $_min_r = $r - $_->{R};
		my $_min_g = $g - $_->{G};
		my $_min_b = $b - $_->{B};
		my $_min = sqrt ( $_min_r ** 2 + $_min_g ** 2 + $_min_b ** 2 );
		
		if ($_min < $min) {
		    $min = $_min;
		    
		    $out = {
			'origin' => { 'r0' => $r, 'g0' => $g, 'b0' => $b },
			'standard' => $color,
			'r' => $_->{R},
			'g' => $_->{G},
			'b' => $_->{B},
			'color' => $_->{RGB},
			'delta' => $_min,
			'mixed' => 1
		    };
		}
		
	    }
	}
	
    }
    
    return $out;
} # sub get_standard

sub grayscale_check {
    my ($r, $g, $b) = @_;

    return 1 unless GRAYSCALE;

    my $mid = ( $r + $g + $b ) / 3;
    
    return 0 if ( abs ( $r - $mid ) ) > GRAYSCALE_SIGN;
    return 0 if ( abs ( $g - $mid ) ) > GRAYSCALE_SIGN;
    return 0 if ( abs ( $b - $mid ) ) > GRAYSCALE_SIGN;

    return 1;
} # sub grayscale_check

sub new_sign {
    my ($color, $std) = @_;

    return $signs_cache->{$color} if $signs_cache->{$color};

    $signs_cache->{$color} = "\&\#" .  sprintf("%d", hex($signs_init)) . ";";
    $signs_std_cache->{$std} = "\&\#" .  sprintf("%d", hex($signs_init)) . ";";

    $bgcnt = 0 unless $bgs[$bgcnt];
    $signs_bg_cache->{$color} = "\#" . $bgs[$bgcnt++];

    $signs_init++;

    return $signs_cache->{$color};
} # sub new_sign
