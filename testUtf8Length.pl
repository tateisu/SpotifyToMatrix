#!/usr/bin/perl --
use strict;
use warnings;
use utf8;
use feature qw(say);

sub lengthBytes($){
	use bytes;
	return length $_[0];
}
sub substrBytes{
	use bytes;
	return substr($_[0],$_[1],$_[2]);
}

sub trimValidUtf8($){
	use bytes;
	$_[0] =~ /((?:[\x00-\x7F]|[\xC2-\xDF][\x80-\xBF]{1}|[\xE0-\xEF][\x80-\xBF]{2}|[\xF0-\xF4][\x80-\xBF]{3})*)/;
	return $1;
}

my $fileNameMaxBytes = 255-8; # -8 for ".tmpXXXX"
my $ellipsis = "…";
my $ellipsisBytes = lengthBytes $ellipsis;

sub safeName($){
	my($a)=@_;
	$a =~ s%[\\/:*?"<>|_]+%_%g;

	# linuxではファイル名(not include parent folder)は255バイトまで
	my $lb = lengthBytes($a);
	if($lb>$fileNameMaxBytes){
		$a = trimValidUtf8 substrBytes($a,0,$fileNameMaxBytes-$ellipsisBytes);
		utf8::decode($a);
		$a .= $ellipsis;
	}

	$a;
}


my $a = "8 Humoresques, Op. 101, B. 187: No. 7, Poco lento e grazioso (Transcribed by Oscar Morawetz for Violin, Cello & Orchestra) / Antonín Dvořák, Seiji Ozawa, Yo-Yo Ma, Itzhak Perlman, Boston Symphony Orchestra https://open.spotify.com/track/78w7y8EDtL5LFaZ80rOkRl";
say lengthBytes $a;
say lengthBytes safeName($a);

