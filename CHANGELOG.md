# Changelog

このプロジェクトの主な変更を記録します。

## [Unreleased]

- iOSは公開済みの 1.0 (2) に固定する。基準コミットは `ffde8c1c97660688958d0bf789501e0a4ce0c31b`。main で重複していたバージョンと画面方向は、そのコミットの 1.0 / build 2、iPhone は縦向きのみに合わせた
- Windowsの辞書コアを `net8.0` に分離し、読み書き・検証・旧辞書移行・照合を自動テストできるようにした。辞書画面の分割位置は表示後に設定する
- AndroidにGradle Wrapper、単体テスト、未署名リリースビルド、IME subtypeを追加した。Backspaceはトリガーの1文字だけを戻し、辞書の更新はキーボードを開いたまま反映する
- 共通テスト、Windows、AndroidのCIを追加した。iOSは固定した 1.0 (2) の署名なしコンパイルだけを確認する。署名とストア提出は含まない

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
