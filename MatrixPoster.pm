package MatrixPoster;
$MatrixPoster::VERSION = '0.20210314'; # YYYYMMDD

use strict;
use warnings;
use utf8;
use Encode;
use Data::Dump qw(dump);
use JSON::XS;
use URI::Escape;
use HTML::Entities;
use LWP::UserAgent;
use Attribute::Constant;
use feature qw(say);


my $utf8 = Encode::find_encoding("utf8");

sub new{
    my($class,%others)=@_;
    my $self = \%others;

    my $configFile = $self->{configFile};
    if($configFile){
         open(my $fh,"<:utf8",$configFile) or die "$! $configFile";
         while(<$fh>){
             s/[\x0f\x0a]+//g;
             s/;;.*//g;
             s/^\s+//;
             s/\s+$//;
             next if not length;
             my($name,$value)=split /\s+/,$_,2;
             defined($value) or die "not in form 'name value'. [$_]";
             $self->{$name}=$value;
        }
        close($fh) or die "$! $configFile";
    }

    if( not $self->{ua}){
        my $ua = $self->{ua} = LWP::UserAgent->new(
             timeout => 30,
             agent => $self->{userAgent} || "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.72 Safari/537.36",
        );
        $ua->env_proxy;
    }

    die "missing 'server'." unless $self->{server};
    die "missing 'token' or pair of 'user' and 'password'." unless $self->{token} || ($self->{user} && $self->{password});

    return bless $self,$class;
}

sub encodeQuery($){
    my($hash)=@_;
    return join "&",map{ uri_escape($_)."=".uri_escape($hash->{$_}) } sort keys %$hash;
}

sub showUrl{
    my($self,$method,$url)=@_;
    if($self->{verbose}){
        $url =~ s/access_token=[^&]+/access_token=xxx/g;
        $self->{verbose} and warn "$method $url\n";
    }
}

my $methodPost : Constant("POST");
my $methodGet : Constant("GET");

sub matrixApi{
    my($self,$method,$path,$params)=@_;
    my $url = "https://$self->{server}/_matrix/client/r0$path";
    if($self->{token}){
        my $delm = index($url,"?")==-1? "?":"&";
        $url = $url . $delm .encodeQuery({access_token=>$self->{token}})
    }
    my $res;
    if( $method eq $methodPost){
        $self->showUrl($method,$url);
        $res = $self->{ua}->post($url,Content => encode_json($params || {}));
    }else{
        die "matrixApi: unsupport method $method";
    }

    $res->is_success or die "request failed. ",$res->status_line;

    my $content = $res->decoded_content;
    $self->{lastContent} = $content;
    return decode_json($content);
}

sub login{
    my($self)=@_;
    my $root = $self->matrixApi("POST","/login",{
        type=>"m.login.password",
        user=>$self->{user},
        password=>$self->{password},
    });
    $self->{token} = $root->{access_token};
    die "missing token in API response. $self->{lastContent}" unless $self->{token};

    $self->{verbose} and say "access_token=$self->{token}";
}

sub postText{
    my($self,$roomId, $text)=@_;
    $self->login if not $self->{token};

    my $root = $self->matrixApi(
        "POST",
        "/rooms/".uri_escape($roomId)."/send/m.room.message",
        {
            msgtype=>"m.text", 
            body=>$text,
        }
    );
    my $eventId =  $root->{event_id};
    die "missing eventId in API response." unless $eventId;
    return $eventId;
}

1;
__END__
