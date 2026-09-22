# macOSの自動更新を公開する

Sparkle 2.10.0を固定して使用します。アプリの「自動更新」は初期状態ではオフです。
オンにすると定期確認と自動ダウンロード・インストールを有効にし、Sparkleが利用者の設定を保存します。
通常は終了時などに適用します。権限が必要な場合や長期間終了しない場合は確認画面が出ることがあります。
「アップデートを確認…」は自動更新がオフでも使えます。

## 初回設定

1. MacでDeveloper ID Application証明書を準備し、notarytoolの認証情報を
   `fukura-notary` などの名前でキーチェーンに保存する。
2. `swift package --package-path macos resolve` でSparkleを取得する。
   `macos/.build/artifacts` 内のSparkle配布物にある `bin/generate_keys` をMacで実行する。
   秘密鍵はキーチェーンに保管し、表示された公開鍵だけを以下の設定に使う。
3. 更新フィードのURLを決める。このリポジトリのGitHub Releasesを使うなら、
   例として `https://github.com/kai-asai/fukura/releases/latest/download/appcast.xml`。
   このURLは公開まで存在しなくてもよいが、利用者へ配布する前に到達できることを確認する。

秘密鍵・Appleの認証情報をソースや公開ファイルへ入れないでください。
更新鍵は毎回作り直さず、バックアップして継続利用します。

## 公開用ビルド

リポジトリのルートで、例の名前・Team ID・公開鍵を実際の値へ置き換えて実行します。

```bash
PUBLIC_RELEASE=1 \
APP_VERSION=1.1.0 APP_BUILD=3 \
SPARKLE_FEED_URL="https://github.com/kai-asai/fukura/releases/latest/download/appcast.xml" \
SPARKLE_PUBLIC_KEY="generate_keysが表示した公開鍵" \
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="fukura-notary" \
bash macos/package-app.sh
```

公開モードでは未設定項目があるとビルドを中止します。通常の開発・CIでは公開鍵とURLを
省略でき、その場合は更新機能を起動せず、ネットワーク通信もしません。
URLまたは公開鍵の片方だけを設定することはできません。
署名・公証・staple・検証後の `macos/dist/fukura-mac.zip` を配布します。
Sparkleの内包コードも内側から順に署名します。

APP_BUILDは配布のたびに必ず増やしてください（3 → 4 → 5）。
APP_VERSIONは表示用です。ビルドのCPUアーキテクチャを配布対象に合わせてください。
現在のCIはApple Silicon向けです。

## 更新フィードの生成と公開

公証後のZIPをバージョン付きで専用ディレクトリへコピーし、Sparkleの
`bin/generate_appcast` を使ってアーカイブのEdDSA署名とappcast.xmlを生成します。
例（`SPARKLE_BIN` は取得したSparkle配布物のbinディレクトリ）:

```bash
mkdir -p macos/update-release
cp macos/dist/fukura-mac.zip macos/update-release/fukura-mac-1.1.0.zip
"$SPARKLE_BIN/generate_appcast" \
  --download-url-prefix "https://github.com/kai-asai/fukura/releases/download/macos-v1.1.0/" \
  macos/update-release
```

このフォルダーには今回配布するZIPだけを入れて生成します。秘密鍵はキーチェーンから読み込まれます。
生成後はZIPを変更しません。GitHub Releaseのタグ `macos-v1.1.0` に、
ZIPとappcast.xmlをアップロードして公開します。アプリ内の公開鍵と署名鍵が対応することを確認します。
配布URLとフィード内のURL・バージョン・署名を確認してください。

`releases/latest/download` を使う場合、最新リリースには常にmacOSのappcast.xmlが必要です。
iOSやWindowsのみのリリースをlatestにすると更新が止まるため、latestの運用を揃えるか、
恒久的なHTTPS配信先を用意してください。

## リリース前テスト

- `swift test --package-path macos` と `python3 -m unittest discover -s macos/packaging-tests` を実行する。
- 公開URLと鍵がないビルドで更新通信が始まらず、手動確認は利用不可の案内になること。
- 設定済みビルドで手動更新確認、ネットワークエラーの表示、自動更新オン・オフの永続化を確認する。
- テスト用フィードで旧ビルドから新ビルドへの署名・公証済み更新を実行し、
  辞書、ログイン時起動、一時停止、入力監視の権限と展開を確認する。
- 不正な署名の更新が拒否されることを確認する。

CIはコンパイル・テスト・同梱フレームワークの読み込みを検証しますが、
Developer ID署名・公証や実際の更新適用はローカルの認証情報を使った確認が必要です。
初回だけ自動更新対応版への手動入れ替えが必要です。
