#!/usr/bin/env perl
###################################################################
# % $0 KN001_Keitai_1/ out-html/
#
# 1記事中 (KN001_Keitai_1/) の全文の係り受け・意味関係ページ
# と形態素ページの作成。
# out-htmlは出力先ディレクトリ。
###################################################################

use strict;
use warnings;
use utf8;
use List::Util;
use File::Basename;
use Storable qw(retrieve);

binmode STDOUT, ":encoding(euc-jp)";
binmode STDERR, ":encoding(euc-jp)";
binmode STDIN, ":encoding(euc-jp)";

my $nict_ann = "$ARGV[1]/nict_sentiment_annotation.bin";
my $nict_ref;
if(-f $nict_ann){
    $nict_ref = retrieve $nict_ann;
}

my $article = basename $ARGV[0];
$article =~ s/\/+$//;

my @sentences = sort {
    #(split /-/, $a)[2] <=> (split /-/, $b)[2]
    (split /-/, $a)[-2] <=> (split /-/, $b)[-2]
} glob("$ARGV[0]/KN*");

my $out = "$ARGV[1]/$article-annotation.html";

open OUT, ">:encoding(euc-jp)", $out or die "Can't write into $out: $!";

print OUT "<html><head><title>$article</title><meta http-equiv=\"content-type\" content=\"application/html; charset=EUC-JP\" /></head>";
print OUT "<link rel=\"stylesheet\" type=\"text/css\" href=\"knbc_annotation_per-article.css\" />";
print OUT "<body>";


for my $sent (@sentences){

    my $sent_bn = basename $sent;
    print OUT "<h2>$sent_bn</h2>";

    open IN, "<:encoding(euc-jp)", $sent or die "Can't open $sent: $!";
    my $sid;
    my $bnst_total = -1;
    my %dep_parent; # keyの文節の係り先を返す
    my %dep_type;
    my %dep_children; # keyの文節の係り元を返す
    my %bnst2case;
    my %bnst2ne;
    my %morph_h;
    my %bnst_or_tag;

    while(<IN>){
	chomp;
	if(/^\#/){
	    $sid = $_;
	}elsif(/^\+/ || /^\*/){
	    /^[+*] ([-0-9]*)([ADIP])/;
	    $dep_parent{++$bnst_total} = $1;
	    $dep_type{$bnst_total} = '<span id=deptype>'.$2.'</span>';
	    push @{$dep_children{$1}}, $bnst_total;
	    $bnst2case{$bnst_total} = &get_case($_);
	    $bnst2ne{$bnst_total} = &get_NE($_);
	    $bnst_or_tag{$bnst_total} = $_ =~ /^\*/ ?
		'文節区切り' : 'タグ区切り';
	}elsif($_ eq 'EOS'){
	    
	}else{
	    push @{$morph_h{$bnst_total}}, [ (split / /)[0,1,2,3,5,7,9] ];
	}
    }
    close IN;



    # NICT評判表現マーク
    my $char_offset = 0;
    my %bnst2sentiment;
    if(defined $nict_ref){
	# アノテーション（評価表現文字範囲、評価者、タイプ、評価対象）取得
	my @char_span;
	my @evaluator;
	my @eval_type;
	my @evaluated;
	for my $ann (@{$nict_ref->{$sent_bn}}){
	    push @char_span, $ann->[2];
	    push @evaluator, $ann->[0];
	    push @eval_type, $ann->[3];
	    push @evaluated, $ann->[4];
	}
    
	#マーク
	my %sentiment_done;
	for my $bid (sort {$a <=> $b} keys %morph_h){
	    for my $morph_a (@{$morph_h{$bid}}){
		my $morph_a_length = length $morph_a->[0];
		( $morph_a->[0], my $which_sentiment ) =
		    @{&mark_sentiment($morph_a->[0],
				      \@char_span, $char_offset)};
		$char_offset = $char_offset + $morph_a_length;

		next if $which_sentiment == -1;

		next if defined $sentiment_done{$which_sentiment};

		my $sentiment_ann = '<span id=evaluated>'.$evaluated[$which_sentiment].'</span>';
		$sentiment_ann .= ':'.'<span id=eval_type>'.$eval_type[$which_sentiment].'</span>';
		$sentiment_ann .= ':'.$evaluator[$which_sentiment]
		    if $evaluator[$which_sentiment] ne '[著者]';
		${$bnst2sentiment{$bid}}[$which_sentiment] = $sentiment_ann;
		$sentiment_done{$which_sentiment}++;
	    }
	}
    }



    print OUT "<table>";

    print OUT "<tr><th id=synsemhead>係り受け</th><th id=synsemhead>格・省略・照応、固有表現</th><th id=synsemhead>評判表現</th></tr>";
    
    for my $myid (sort {$a <=> $b} keys %dep_parent){
	my $mrph;
	for my $morph_a (@{$morph_h{$myid}}){
	    $mrph .= ${$morph_a}[0];
	}
	#$mrph = "<a href=\"$sent-morph.html#$myid\" target=\"$sent-morph\">".$mrph."</a>";
	$mrph .= "<span id=kakari-keisen>";
	for my $currentid ((1 + $myid) .. $bnst_total){
	    # 自分の親か？
	    if($dep_parent{$myid} == $currentid){
		# 自分より前の文節の親でもあるか？
		if(List::Util::min(@{$dep_children{$dep_parent{$myid}}}) < $myid){
		    $mrph .= $dep_type{$myid} eq '<span id=deptype>D</span>' ? '┫' : $dep_type{$myid};
		    #$mrph .= '┫';
		}else{
		    $mrph .= $dep_type{$myid} eq '<span id=deptype>D</span>' ? '┓' : $dep_type{$myid};
		    #$mrph .= '┓';
		}
	    }
	    # 自分の親はまだ先か？
	    elsif($dep_parent{$myid} > $currentid){
		# 今の文節は自分より前の文節の親か？
		if(defined $dep_children{$currentid} &&
		   List::Util::min(@{$dep_children{$currentid}}) < $myid){
		    $mrph .= '<span id=cross>╋</span>';
		}else{
		    $mrph .= '━';
		}
	    }
	    # 自分の親はもう出たか？
	    else{
		#今の文節は自分より前の文節の親か？
		if(defined $dep_children{$currentid} &&
		   List::Util::min(@{$dep_children{$currentid}}) < $myid){
		    $mrph .= '┃';
		}else{
		    $mrph .= '　';
		} 
	    }
	}
	$mrph .= "</span>";
	print OUT "<tr><td id=dep>";
	print OUT $mrph;
	print OUT "</td><td id=sem>";
	print OUT '&nbsp;&nbsp;';
	print OUT $bnst2case{$myid} if defined $bnst2case{$myid} && $bnst2case{$myid} ne '';
	if(defined $bnst2case{$myid} && $bnst2case{$myid} ne ''
	   && defined $bnst2ne{$myid} && $bnst2ne{$myid} ne ''){
	    print OUT ',&nbsp;' ;
	}
	print OUT $bnst2ne{$myid} if defined $bnst2ne{$myid} && $bnst2ne{$myid} ne '';
	print OUT '&nbsp;&nbsp;';
	print OUT "</td>";
	my $sentiment_string = join(',&nbsp;', grep { defined } @{$bnst2sentiment{$myid}});
	my $tmp_sentiment_td = $sentiment_string ne '' ? '<td id=with_sentiment>' : '<td id=without_sentiment>';
	print OUT $tmp_sentiment_td;
	print OUT '&nbsp;&nbsp;';
	print OUT $sentiment_string;
	print OUT '&nbsp;&nbsp;';
	print OUT "</td></tr>";
    }

    print OUT "</table>";

    print OUT "<p />";

    print OUT "<table>";

    print OUT "<tr><th>表出形</th><th>読み</th><th>原形</th><th>品詞</th><th>活用</th></tr>";
    for my $myid (sort {$a <=> $b} keys %morph_h){
	for my $i (0 .. $#{$morph_h{$myid}}){
	    my $morph_a = ${$morph_h{$myid}}[$i];
	    
	    if($i == 0){
		print OUT "<tr>";
		print OUT "<td colspan=\"5\" id=";
		print OUT $bnst_or_tag{$myid} eq '文節区切り' ?
		    'bnst-kugiri' : 'tag-kugiri';
		print OUT ">";
		print OUT "<a name=$myid>";
		print OUT $bnst_or_tag{$myid};
		print OUT "</a>";
		print OUT "</td>";
		print OUT "</tr>";
	    }
	    
	    print OUT "<tr>";
	    print OUT "<td id=morphrow>${$morph_a}[0]</td>";
	    print OUT "<td id=morphrow>${$morph_a}[1]</td>";
	    print OUT "<td id=morphrow>${$morph_a}[2]</td>";
	    print OUT "<td id=morphrow>";
	    print OUT ${$morph_a}[3] eq '*' ? '' : ${$morph_a}[3];
	    print OUT ' ';
	    print OUT ${$morph_a}[4] eq '*' ? '' : ${$morph_a}[4];
	    print OUT "</td>";
	    print OUT "<td id=morphrow>";
	    print OUT ${$morph_a}[5] eq '*' ? '' : ${$morph_a}[5];
	    print OUT ' ';
	    print OUT ${$morph_a}[6] eq '*' ? '' : ${$morph_a}[6];
	    print OUT "</td>";
	    print OUT "</tr>";
	}
    }
    print OUT "</table>";
}

print OUT "</body></html>";

close OUT;

sub get_case {
    my $str = shift;
    my @cases = $str =~ /<(C用\;.+?)>/g;

    my @result_a;
    for my $case (@cases){
	$case =~ /C用\;【(.*?)】\;(.+?)\;.+?\((.+?)\).*?/;
	die "Unexpected:[$case]" unless defined $1 && $2 && $3;
	my $word = $1;
	my $marker = $2;
	my $position = $3;

	if($marker eq 'メモ'){
	    push @result_a, "<span id=memo>メモ:$word</span>";
	}else{
	    if($position eq '同一文'){
		push @result_a, "<span id=caseword>$word</span>:<span id=casemarker>$marker</span>";
	    }else{
		push @result_a, "<span id=caseword>$word</span>:<span id=casemarker>$marker</span>:<span id=caseposition>$position</span>";
	    }
	}
    }

    return join(',&nbsp;', @result_a);
}

sub get_NE {
    my $str = shift;
    my @NEs = $str =~ /<NE\:(.+?)>/g;
    my @result_a;
    for my $ne (@NEs){
	$ne =~ /^(....).*?:(.+?)$/;
	my $ne_type = $1;
	my $ne_word = $2;
	die "Unexpected NE: $ne" unless defined $ne_type && defined $ne_word;
	push @result_a, "<span id=neword>$ne_word</span>:<span id=netype>$ne_type</span>";
    }

    return join(',&nbsp;', @result_a);
}

sub mark_sentiment {
    (my $morp, my $span_ref, my $offset_start) = @_;
    my $length = length $morp;
    $length--;
    my $offset_end = $offset_start + $length;
    for my $i (0 .. $#{$span_ref}){
	(my $start, my $end) = split /-/, ${$span_ref}[$i];

	die "Illegal span:[${$span_ref}[$i]]" if $start eq '';

	next if $end < $offset_start || $offset_end < $start;
	return [ "<span id=sentiment_exp>$morp</span>", $i ];
    }
    return [ $morp, -1 ];
}
