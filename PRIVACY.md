# Privacy

fukuraは入力したトリガーを端末内で検出し、端末内の辞書から本文へ置換します。

- 辞書、入力履歴、クリップボードの内容を外部サーバーへ送信しません。
- アカウント登録、解析SDK、広告SDK、ネットワーク同期はありません。
- macOSの更新対応版は、手動の更新確認または「自動更新」をオンにした場合に、配布サーバーへ更新情報・アプリを取得する通信を行います。配布サーバーにはIPアドレスなど通常の接続情報が伝わります。Sparkleのシステム情報収集は無効です。辞書や入力内容は送信しません。
- 入力監視はトリガー照合に必要な末尾の短い文字列だけをメモリ上に保持し、ファイルやログへ保存しません。
- 展開時はクリップボードを一時利用し、貼り付け後に可能な範囲で元の内容へ戻します。
- macOSではAccessibility / Input Monitoring権限が必要です。Windowsでは利用者権限でキーボードフックを使用します。

辞書は利用者の端末内に保存されます。

- macOS: `~/Library/Application Support/fukura/`
- Windows: `%LOCALAPPDATA%\fukura\`
- iOS: App Group `group.com.kaiasai.fukura` の共有コンテナ内
- Android: アプリ専用の内部ストレージ（`filesDir`）

macOS / Windowsではアプリを削除しても辞書は残ります。完全に削除する場合は、アプリ終了後に上記フォルダーも削除してください。iOS / Androidの辞書はOS管理のアプリコンテナに保存され、関連するアプリをアンインストールするとOSによって削除されます。Androidは `android:allowBackup="false"` のため自動バックアップ対象外です。
