# Changelog

このプロジェクトの主な変更を記録します。

## [Unreleased]

- Windowsの辞書コアを `net8.0` に分離し、読み書き・検証・旧辞書移行・照合を自動テストできるようにした。辞書画面の分割位置は表示後に設定する
- AndroidにGradle Wrapper、単体テスト、未署名リリースビルド、IME subtypeを追加した。Backspaceはトリガーの1文字だけを戻し、辞書の更新はキーボードを開いたまま反映する
- iOSのバージョンと画面方向の重複を解消し、1.0.0 (3) とした。書き出し、インポート失敗時のアラート、初期サンプル辞書、キーボードの高さを追加した
- iOS / Androidとも、選んでいるfukuraキーボードの中だけで展開する。システム全体の置換やiOSのフルアクセスは行わない
- 共通ロジック、Windowsコア、Android、iOS向けのCIを追加した。署名とストア提出は含まない

## iOS App Store 1.0 (1) - 2026-07-18

- iOS版をApp Store Connectの審査へ提出
- App Store用のバージョン、ビルド番号、画面方向を設定
- App Groupを `group.com.kaiasai.fukura` に統一

## [1.0.0] - 2026-07-16

- macOS / Windows向け常駐型スニペット展開
- iOS / Android向けカスタムキーボード
- アプリ内辞書編集とJSONインポート・書き出し
- 旧bon / 旧版からの辞書移行
- OS別のfukuraアイコン
