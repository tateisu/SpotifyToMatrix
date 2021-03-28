
----
## これはなに

Spotifyから現在再生中の曲を取って適当にフィルタしてMatrixに送るPerlスクリプト。
cronから定期的に起動される想定です。

----
## どう使うの

### 作業PCの用意

SpotifyのOAuth認証のため一時的にWebアプリを動かしてブラウザからアクセスする必要があります。
Webアプリを動かすホストと、それをブラウザから見る際のホスト名/IPアドレスを整理しておいてください。

- Webアプリを動かすホストにはnode.js をインストールして`node`や`npm`コマンドが使える状態にします。
- ↑のホストをブラウザから見れるホスト名/IPアドレスを決めます(A)
- (A)のホストのポート8888が空いてないなら別のポート番号を決めます(B)

次にSpotifyのOAuth認証で使うコールバックURLを決めます。

- http://localhost:8888 
- http://localhost:8888/callback

`localhost` や `8888` の部分は(A)や(B)の条件により変化するかもしれません。
以下の説明でコールバックURLが出てくる部分は適時置き換えてください。


### Spotify APIを使うアプリの登録
- [Spotifyの開発者ダッシュボード](https://developer.spotify.com/dashboard/applications) を開いてMy New App を選ぶ。
- App name と App description を書く。たとえば "currentGet" や "my private app to get current playing." など。
- 同意事項にチェックをつけてCreate。
- Client ID と Client Secret を控えておく
- Edit Settingsを開いてRedirect URIs に http://localhost:8888 と http://localhost:8888/callback を追加しておく。

### oAuth認証用のWebアプリを一時的に動かす

Spotifyが用意してるOAuth認証サンプルWebアプリhttps://github.com/spotify/web-api-auth-examples を
お手元のPCに設置して動かします。

- git clone git@github.com:spotify/web-api-auth-examples.git
- cd web-api-auth-examples.git
- npm install

authorization_code/app.js を編集する。

```
diff --git a/authorization_code/app.js b/authorization_code/app.js
index 9b8a6b5..ba7157a 100644
--- a/authorization_code/app.js
+++ b/authorization_code/app.js
@@ -13,9 +13,10 @@ var cors = require('cors');
 var querystring = require('querystring');
 var cookieParser = require('cookie-parser');

-var client_id = 'CLIENT_ID'; // Your client id
-var client_secret = 'CLIENT_SECRET'; // Your secret
-var redirect_uri = 'REDIRECT_URI'; // Your redirect uri
+var client_id = 'XXXXXXXXXXXXXXXXXXXXXXXX'; // Your client id
+var client_secret = 'XXXXXXXXXXXXXXXXXXXXXXX'; // Your secret
+var redirect_uri = 'http://localhost:8888/callback'; // Your redirect uri
+var scope = 'user-read-recently-played user-read-playback-state';

 /**
  * Generates a random string containing numbers and letters
@@ -46,7 +47,6 @@ app.get('/login', function(req, res) {
   res.cookie(stateKey, state);

   // your application requests authorization
-  var scope = 'user-read-private user-read-email';
   res.redirect('https://accounts.spotify.com/authorize?' +
     querystring.stringify({
       response_type: 'code',
```

Client ID と Client Secret だけでなくリダイレクトURLとscopeの変更が必要。

- 変更できたら`cd authorization_code && node app.js` でHTTPサーバを動かす。
- http://localhost:8888/ を開いてWebUIからログインする。
- ログイン出来たらブラウザのアドレスバーからアドレスをコピーして、URL中に含まれる`access_token`と`refresh_token`をメモしておく。

トークンの取得が終わったらnodeプロセスは止めても構いません。

### Perl モジュールのインストール

ここからはこのスクリプトの設定作業です。

以下のPerlモジュールをインストールします。

- Attribute::Constant
- Crypt::SSLeay
- Data::Dump
- HTML::Entities
- JSON::XS
- LWP::UserAgent
- URI::Escape

雑にやるなら[cpanminus](https://metacpan.org/pod/App::cpanminus) を入れてから
```
sudo cpanm  Attribute::Constant
sudo cpanm  Crypt::SSLeay
sudo cpanm  Data::Dump
sudo cpanm  HTML::Entities
sudo cpanm  JSON::XS
sudo cpanm  LWP::UserAgent
sudo cpanm  URI::Escape
```
するのがお手軽だと思います。

### login.json を書く

以下のようなjsonを書いてlogin.jsonという名前で保存します。

```
{
  "clientId": "WWWWWWWWWWW",
  "clientSecret": "ZZZZZ",
  "refreshToken": "XXXX",
  "accessToken": "YYYYY"
}
```

- 各パラメータの値はこれまでメモしたものに置き換えます。
- 注意：このファイルはbotスクリプトから上書きするので、ファイルとそれを含むフォルダにはスクリプト実行ユーザの書き込み権限が必要です。
- 注意：ログイン情報を含むので `chmod 0600 login.json` しておきましょう。

### matrixLoginSecret.txt を書く

以下のようなテキストを書いてmatrixLoginSecret.txt という名前で保存します。

```
;; コメントは ;; です。 (matrixだと # や // を多用するため)
userAgent Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.72 Safari/537.36
server matrix.org
room !hhHXgRobyeOzxDPGkA:matrix.org
user replaceme
password replaceme
;;verbose 1
;;token XXXXXXXXXXXXXXX
```

- roomは内部部屋IDです。Elementだと部屋の設定の詳細に記載されています。
- (optional) verboseが1だとログイン直後にアクセストークンを標準出力に出す。
- (optional) tokenを指定する(コメントではなくする)とuser,passを使わず指定されたトークンを使う。
- 注意：ログイン情報を含むので `chmod 0600 matrixLoginSecret.txt` しておきましょう。

### currentGet.pl を動かす

```
chmod 755 currentGet.pl
./currentGet.pl
```

うまく動けばSpotyfyからデータを取ってきてMatrixの部屋に曲名、アーティスト、トラックURLを送ります。

### cronに登録する

```
*/2 * * * *  cd /x/spotifyToMatrix && ./currentGet.pl >>/x/spotifyToMatrix/cron.log 2>&1
```

----
## このスクリプトでやらないこと

- URLプレビューを出すのはSynapseの設定変更でやれるやつです。 https://lemmy.juggler.jp/post/794
- IFTTTみてて思ったんだけど、NowPlayingって「現在再生中」じゃなくて手動で再生開始したとかお気に入りしたとか言う時に出力するものなの…？
- IFTTTだと色々できるのはSpotifyとIFTTTが何か協業してるっぽい。素のAPIだとああいうのは作りにくい。
