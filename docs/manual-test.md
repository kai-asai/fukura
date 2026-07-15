# Manual Test

## 共通

1. `node --test tests/*.test.mjs` を実行する。
2. `examples/snippets.example.json` が読み込めることを確認する。
3. `enabled: false` の `;addr` が展開対象外であることを確認する。
4. `;t` と `;today` では `;today` が優先されることを確認する。
5. 壊れたJSON、`version: 2`、空の `trigger`、重複 `trigger` が検証エラーになることを確認する。
6. 512 KiB超、501件以上、65文字以上の `trigger`、8001文字以上の `body` が検証エラーになることを確認する。

## macOS

1. `cd macos && swift build` を実行する。
2. `swift run FukuraMac` で起動する。
3. 起動後、メニューバーにfukuraのモノクロアイコンが表示され、明暗モードで反転することを確認する。
4. 権限不足時にAccessibility / Input Monitoringの案内が出ることを確認する。
5. `プライバシー設定を開く` からシステム設定を開けることを確認する。
6. Accessibility / Input Monitoringを許可し、FukuraMacを再起動する。
7. `辞書を編集…` で編集画面が開き、追加・複製・削除・検索・有効/無効が動くことを確認する。
8. 本文欄でReturnを使って複数行を入力し、保存後の展開が改行されることを確認する。
9. 空のトリガー・本文、重複トリガーが保存できないことを確認する。
10. 未保存で閉じると破棄確認が出て、`⌘S` 保存後は出ないことを確認する。
11. 保存時に `snippets.backup.json` が作成され、保存直後から新しいスニペットが展開されることを確認する。
12. `snippets.jsonを開く` で `~/Library/Application Support/fukura/snippets.json` が開くことを確認する。
13. TextEditで `;mail` と `;thx` を入力し、本文へ置換されることを確認する。
14. 別のJSONを `snippets.jsonをインポート…` から取り込み、バックアップが作成されることを確認する。
15. 一時停止・再開、修飾キー中の除外が動くことを確認する。
16. 失敗時にメニューの `状態:` とターミナルの `[fukura]` ログで原因を追えることを確認する。
17. fukura側の辞書がない状態で旧 `bon/snippets.json` を置き、起動時に自動コピーされることを確認する。
18. TextEditで `;mai` まで入力してBackspace、その後 `l` を入力しても展開されないこと、改めて `;mail` を入力すると正しく展開されることを確認する。
19. 矢印、Home / End、Tab、Returnなどの編集・移動キーでトリガー照合がリセットされることを確認する。
20. 旧bonをログイン時起動に登録した状態でfukuraを起動し、bonの終了とログイン項目の解除案内が表示されること。bonを終了しない場合はfukuraの展開が停止され、二重展開されないことを確認する。

## Windows

1. Windows 10 / 11と.NET 8 SDKで `dotnet build windows/FukuraWindows.csproj` を実行する。
2. タスクトレイへfukuraのモノクロアイコンが表示され、ライト/ダークのタスクバーで視認できることを確認する。
3. ダブルクリックで辞書編集画面が開き、追加・複製・削除・検索・有効/無効と `Ctrl+S` 保存が動くことを確認する。
4. 本文欄へEnterで複数行を入力し、展開結果にも改行が入ることを確認する。
5. 保存時に `%LOCALAPPDATA%\fukura\snippets.backup.json` が作成されることを確認する。
6. メモ帳で `;mail` / `;thx` が展開され、元のクリップボードが復元されることを確認する。
7. 一時停止、再開、JSONインポート、保存フォルダーを開く、ログイン時起動が動くことを確認する。
8. `package-app.ps1 -Runtime win-x64` でランタイム同梱ZIPが作成され、.NET未導入の別PCで起動できることを確認する。
9. fukura側の辞書がない状態で旧 `%LOCALAPPDATA%\bon\snippets.json` から自動コピーされることを確認する。
10. Windowsのライト/ダークモードをfukura起動中に変更し、トレイアイコンが再起動なしで切り替わることを確認する。
11. 旧 `bon` のRunレジストリ値がfukura起動時に削除され、`fukura` に置き換わること。bonが起動中なら終了確認が出て、二重展開されないことを確認する。

## Android

1. Android Studioで `android` を開き、Debug APKを実機またはエミュレータへインストールする。
2. ランチャーにfukuraのアダプティブアイコンが表示され、テーマアイコンにも対応することを確認する。
3. Appから `snippets.json をインポート` を押し、`examples/snippets.example.json` を選ぶ。
4. `キーボードを有効化` からfukura Keyboardを有効化し、`入力方法を選択` で選ぶ。
5. テキスト入力欄で `;mail` と `;thx` の候補をタップし、展開できることを確認する。
6. AndroidManifestの `android:allowBackup` が `false` であることを確認する。
7. QWERTY配列で通常の英字、数字、記号、Shift、空白、Backspace、改行が入力できることを確認する。
8. 地球キーが表示され、タップで別のIMEへ切り替えてfukura Keyboardから脱出できることを確認する。
9. fukura本体で辞書を編集またはインポートし、プロセスを強制終了せずに入力欄へ戻って新しい辞書が読み込まれることを確認する。
10. 空のトリガー、空の本文、重複トリガーを保存しようとするとダイアログ内に検証エラーが表示され、削除保存の失敗も表示されることを確認する。
11. 旧Application ID `dev.fsc.snippetexpander` のAPKと同じ署名鍵でfukura APKを上書きインストールし、旧 `filesDir/snippets.json` がそのまま読み込まれることを確認する。

## iOS

1. `ios/generate-project.sh` で `Fukura.xcodeproj` を生成する。
2. `Fukura` スキームのApp本体と `FukuraKeyboard` Extensionがビルドできることを確認する。
3. App本体とKeyboard Extensionに `group.com.kaiasai.fukura` を設定し、App本体に移行用の `group.com.kaiasai.bon` / `group.dev.fsc.snippetexpander` も設定する。
4. App本体から `snippets.json` をインポートする。
5. 設定アプリでfukura Keyboardを有効化し、テキスト入力欄で切り替える。
6. `;mail` を入力し、候補をタップして展開できることを確認する。
7. App本体の説明で「標準キーボードでは動作しない」制約が分かることを確認する。
8. 旧App Groupにだけ辞書がある状態でfukura本体を起動し、新App Groupへコピーされることを確認する。
9. キーボードを初めて表示した直後にShiftがオフであること。`;mail` をそのまま入力して候補が出ることを確認する。
10. Shiftのオン/オフが `⇧●` / `⇧` で見分けられることを確認する。
11. OSバージョンにかかわらず `needsInputModeSwitchKey` が真なら地球キーが表示され、タップで切り替え、長押しで入力モード一覧が使えることを確認する。
12. 読み込みに失敗するJSONを選ぶとアラートでエラーが表示されることを確認する。
