# FukuraMac

macOS向けの定型文入力メニューバーアプリです。`~/Library/Application Support/fukura/snippets.json` を読み込み、`;mail` / `;thx` などを展開します。

## ビルドと起動

```bash
cd macos
swift build
swift run FukuraMac
```

## アプリと配布ZIPの作成

```bash
cd macos
./package-app.sh
```

`dist/fukura.app` と `dist/fukura-mac.zip` が作成されます。利用するMacではアプリを `/Applications` へコピーし、初回のみAccessibilityとInput Monitoringを許可します。

環境変数を指定しない場合はアドホック署名です。一般公開用はDeveloper ID証明書と公証用Keychain Profileを用意します。

```bash
CODESIGN_IDENTITY="Developer ID Application: Example (TEAMID)" \
NOTARY_PROFILE="fukura-notary" \
./package-app.sh
```

`NOTARY_PROFILE` 指定時はDeveloper ID署名、Hardened Runtime、公証、staple後にZIPを作成します。

## ログイン時に起動

`fukura.app` を `/Applications` から起動し、メニューバーのfukuraアイコン → `ログイン時に起動` をオンにします。macOSから承認を求められた場合は、`システム設定 > 一般 > ログイン項目と機能拡張` でfukuraを許可してください。`swift run` はログイン項目登録の対象外です。

旧bonが起動中の場合、fukuraはbonの終了とログイン項目の確認を案内します。bonを終了しない場合はfukuraの展開を停止し、二重置換を防ぎます。

## 辞書を編集する

メニューバーのfukuraアイコン → `辞書を編集…`（`⌘E`）で編集画面を開きます。初回起動時は自動で開きます。

- トリガー・本文の検索
- 追加、複製、削除、有効 / 無効の切り替え
- `⌘S` で検証して保存
- 未保存のまま閉じると破棄確認
- 保存前の辞書を `snippets.backup.json` へ自動バックアップ

本文は通常の複数行テキスト欄です。JSON用の `\n` を手書きする必要はありません。

## 保存先と旧名からの移行

```text
~/Library/Application Support/fukura/snippets.json
```

fukuraの辞書が未作成の場合、旧 `~/Library/Application Support/bon/` または `SnippetExpander/` の辞書とバックアップを自動コピーします。旧ファイルは削除しません。どの辞書もなければサンプルを作成します。

## 権限

1. メニューの `プライバシー設定を開く` からシステム設定を開く。
2. `プライバシーとセキュリティ > アクセシビリティ` で起動中のターミナルまたはfukuraを許可する。
3. `プライバシーとセキュリティ > 入力監視` でも同じ対象を許可する。
4. FukuraMacを終了して再起動する。

`swift run` で起動する場合、許可対象はターミナルになることがあります。`.build/debug/FukuraMac` を直接起動する場合はそのバイナリを許可します。

## トラブルシュート

- メニューバーに出ない: `swift run FukuraMac` が起動し続けているか確認する。
- トリガーが置換されない: AccessibilityとInput Monitoringの両方を許可し、再起動する。
- JSONが読み込めない: メニューのステータス、またはターミナルの `[fukura]` ログを確認する。
- 置換タイミングがずれる: まずTextEditで確認する。
