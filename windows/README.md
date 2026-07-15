# fukura for Windows

Windows 10 / 11向けのタスクトレイ常駐アプリです。macOS版と同じ `snippets.json` を利用でき、辞書編集・インポート・ログイン時起動・一時停止に対応します。

## 開発実行

.NET 8 SDKをインストールしたWindowsで実行します。

```powershell
dotnet run --project .\FukuraWindows.csproj
```

起動後、タスクトレイのアイコンをダブルクリックすると辞書編集画面が開きます。トレイアイコンはWindowsのタスクバーテーマを判定し、テーマ変更通知を受けて明暗に適したモノクロ素材へ切り替えます。

辞書の保存先:

```text
%LOCALAPPDATA%\fukura\snippets.json
```

保存のたびに同じフォルダーの `snippets.backup.json` へ直前の辞書をバックアップします。fukuraの辞書がまだない場合は、旧 `%LOCALAPPDATA%\bon\` または `SnippetExpander\` から自動コピーします。

旧bonのWindowsログイン時起動が登録されている場合は、初回起動時に旧 `bon` エントリを削除し、`fukura` エントリへ置き換えます。起動中のbonを検出した場合は、二重展開を防ぐため終了確認を表示します。

## 配布用ZIP

```powershell
.\package-app.ps1 -Runtime win-x64
```

`dist\fukura-win-x64.zip` が作成されます。.NETランタイム込みの単一EXEです。ARM版Windows向けは `-Runtime win-arm64` を指定します。

一般公開用にコード署名証明書がWindows証明書ストアへ入っている場合は、SHA-1 thumbprintを渡します。Windows SDKの `signtool.exe` が必要です。

```powershell
.\package-app.ps1 -Runtime win-x64 -CertificateThumbprint "YOUR_CERTIFICATE_THUMBPRINT"
```

証明書を指定しないCI成果物は未署名で、SmartScreen警告が表示される可能性があります。

## 制約

- 管理者権限で動くアプリの入力欄へ展開する場合、fukura側も同じ権限が必要です。通常利用では管理者起動しないでください。
- パスワード欄など、貼り付けを禁止している入力欄では展開できません。
- 一部のゲームや独自入力方式のアプリではグローバルキーボードフックが利用できないことがあります。
