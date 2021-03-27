
----
## これはなに

Spotifyから現在再生中の曲を取って適当にフィルタしてMatrixに送るスクリプト。
cron
cron+perlできて

----
## どう使うの

### Spotify APIを使うアプリの登録
- [Spotifyの開発者ダッシュボード](https://developer.spotify.com/dashboard/applications) を開いてMy New App を選ぶ。
- App name と App description を書く。たとえば "currentGet" や "my private app to get current playing." など。
- 同意事項にチェックをつけてCreate。
- Client ID と Client Secret を控えておく

### oAuth認証用のWebアプリを一時的に動かす。

https://github.com/spotify/web-api-auth-examples を使う。

- node.js をインストールしておく。
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

### login.json を書く。

```
{
  "clientId": "WWWWWWWWWWW",
  "clientSecret": "ZZZZZ",
  "refreshToken": "XXXX",
  "accessToken": "YYYYY"
}
```
- 上記のようなjsonを書いてlogin.jsonという名前で保存する。
- 各パラメータの値はこれまでメモしたものに置き換える。
- chmod 600 login.json
- このファイルはログイン情報を含む&botスクリプトから上書きするのでパーミッションに注意。

### matrixLoginSecret.txt を書く。

```
;; コメントは ;; です。 (matrixだと # や // を多用するため)
userAgent Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.72 Safari/537.36
server matrix.juggler.jp
room !hhHXgRobyeOzxDPGkA:matrix.juggler.jp
user kaede
password XXXXXX
;;verbose 1
;;token XXXXXXXXXXXXXXX
```

- 上記のようなテキストを書いてmatrixLoginSecret.txt という名前で保存する。
- roomは内部部屋ID。Elementだと部屋の設定の詳細に記載されている。
- (optional) verboseが1だとログイン直後にアクセストークンを標準出力に出す。
- (optional) tokenを指定する(コメントではなくする)とuser,passを使わず指定されたトークンを使う。
- ログイン情報を含むので chmod 0600 matrixLoginSecret.txt しておく

### currentGet.pl を動かす

```
chmod 755 currentGet.pl
./currentGet.pl
```

うまく動けばSpotyfyからデータを取ってきてMatrixの部屋に曲名、アーティスト、アルバムURLを送ります。

## cronに登録する

```
*/2 * * * *  cd /x/spotifyToMatrix && ./currentGet.pl >>/x/spotifyToMatrix/cron.log 2>&1
```
