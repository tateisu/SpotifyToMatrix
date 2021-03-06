#!/usr/bin/perl --
use strict;
use warnings;
use feature qw(say);
use utf8;

use LWP::UserAgent;
use JSON::XS;
use MIME::Base64;
use Data::Dump qw(dump);
use Encode;

# スクリプトのあるフォルダを依存関係に追加する
use FindBin 1.51 qw( $RealBin );
use lib $RealBin;

use MatrixPoster;

binmode $_,":utf8" for \*STDOUT,\*STDERR;
my $utf8 = Encode::find_encoding('utf8');

my $cacheDir = "./cache";
mkdir $cacheDir;

my $songDir = "./song";
mkdir $songDir;

#############################################################
# 既出チェックのファイル名が255バイトを超えないようにする

# UTF8文字列のバイト数
sub lengthBytes($){
	use bytes;
	length $_[0];
}

# UTF8文字列をバイト指定でsubstr
sub substrBytes{
	use bytes;
	substr($_[0],$_[1],$_[2]);
}

# 有効なUTF8文字列を抽出
sub trimValidUtf8($){
	use bytes;
	$_[0] =~ /((?:[\x00-\x7F]|[\xC2-\xDF][\x80-\xBF]{1}|[\xE0-\xEF][\x80-\xBF]{2}|[\xF0-\xF4][\x80-\xBF]{3})*)/;
	$1;
}

my $fileNameMaxBytes = 255-8; # -8 for ".tmpXXXX"
my $ellipsis = "…";
my $ellipsisBytes = lengthBytes $ellipsis;

sub safeName($){
	my($a)=@_;
	
	# ファイル名に使えない文字を浄化する
	$a =~ s%[\\/:*?"<>|_]+%_%g;

	# ファイル名に使えるバイト数
	my $lb = lengthBytes($a);
	if($lb>$fileNameMaxBytes){
		$a = trimValidUtf8 substrBytes($a,0,$fileNameMaxBytes-$ellipsisBytes);
		utf8::decode($a);
		$a .= $ellipsis;
	}

	$a;
}

################################################################

sub loadFile($){
	my($fname) = @_;
	open(my $fh,"<:raw",$fname) or die "$fname $!";
	local $/ = undef;
	my $data = <$fh>;
	close($fh) or die "$fname $!";
	$data;
}

sub saveFile($$){
	my($fname,$data) = @_;
	my $tmpFile = "$fname.tmp".substr($$,-4);
	open(my $fh,">:raw",$tmpFile) or die "$tmpFile $!";
	print $fh $data;
	close($fh) or die "$tmpFile $!";
	rename($tmpFile,$fname) or die "$fname $!";
}

################################################################

my $ua = LWP::UserAgent->new(
	timeout => 30,
	agent => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.90 Safari/537.36',
);
$ua->env_proxy;

my $loginFile = shift // "login.json";
my $loginInfo = decode_json loadFile $loginFile;

$loginInfo->{clientId} or die "$loginFile : missing clientId.\n";
$loginInfo->{clientSecret} or die "$loginFile : missing clientSecret.\n";
$loginInfo->{refreshToken} or die "$loginFile : missing refreshToken.\n";

sub saveLoginInfo(){
	saveFile($loginFile,encode_json($loginInfo));
	chmod 0600, $loginFile;
}

my($url,$res,$root);

if( $loginInfo->{expiresAt} 
&&  $loginInfo->{expiresAt} - time > 30
&&  $loginInfo->{accessToken}
){
	# no need to refresh token
}else{
	## refresh token
	$url = "https://accounts.spotify.com/api/token";
	$res = $ua->post(
		$url,
		Authorization => "Basic ".encode_base64("$loginInfo->{clientId}:$loginInfo->{clientSecret}","" ),
		# application/x-www-form-urlencoded
		Content => {
			grant_type => "refresh_token",
			refresh_token => $loginInfo->{refreshToken},
		}
	);

	$res->is_success or die $url," ",$res->status_line;
	$root = decode_json( $res->content );

	#{
	#   "access_token": "NgA6ZcYI...ixn8bUQ",
	#   "token_type": "Bearer",
	#   "scope": "user-read-private user-read-email",
	#   "expires_in": 3600
	#}

	if( $root->{access_token} and $root->{expires_in} ){
		$loginInfo->{accessToken} = $root->{access_token};
		$loginInfo->{expiresAt} = time + $root->{expires_in};
		saveLoginInfo;
	}else{
		say dump($root);
		die "failed to refresh token.\n";
	}
}


my $lastBytes;
sub cachedGet{
	my($url)=@_;

	my $cacheFile = $cacheDir . "/". safeName($url);

	my @st = stat($cacheFile);
	if(@st and $st[9] > time - 60 ){
		my $bytes = loadFile $cacheFile;
		$lastBytes = $bytes;
		return decode_json $bytes;
	}

	my $res = $ua->get(
		$url,
		Authorization => "Bearer $loginInfo->{accessToken}"
	);
	$res->is_success or die $url," ",$res->status_line;

	my $bytes = $res->content;
	$lastBytes = $bytes;
	saveFile($cacheFile,$bytes);

	$bytes or die "empty response. $url\n";

	my $root = eval{ decode_json $bytes };
	return $root if not $@;

 	say "content=",$utf8->decode($bytes);
	die $@;
}

# Get Information About The User's Current Playback
$root = cachedGet("https://api.spotify.com/v1/me/player");

$root->{is_playing} or exit;

my $name = $root->{item}{name} or exit;
my $artist = join ", ",map{ $_->{name} } @{$root->{item}{artists}};
$artist and $name = "$name / $artist";

my @urls = grep{ defined $_ and length $_ } (
	$root->{item}{external_urls}{spotify},
	$root->{item}{album}{external_urls}{spotify},
	$root->{context}{external_urls}{spotify} );
@urls or exit;

###########################################################
# 最近書いた曲を除外する

my $songFile = $songDir."/". safeName( join(" ",$urls[0],$name));
my @st = stat($songFile);
if( @st && $st[9] >= time - 86400*7){
	say "skip: exists $songFile";
	exit;
}

my $text = join(" ",$name,$urls[0]);
say $text;

###################################################

# Matrixに出力
my $poster = MatrixPoster->new( configFile => './matrixLoginSecret.txt');
$poster->postText($poster->{room},$text);

# 最近出力したファイルを覚える
saveFile($songFile,$lastBytes);
