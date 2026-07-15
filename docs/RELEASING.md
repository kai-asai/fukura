# Release guide

## 方針

- GitHubにはソースコードを公開します。
- ビルド成果物はGitへコミットせず、タグに対応するGitHub Releaseへ添付します。
- 署名鍵、証明書、APIキー、プロビジョニング情報をコミットしません。
- Pull Requestでは秘密情報を使わないビルドとテストだけを実行します。
- 署名・公証・ストア提出は保護されたGitHub Environmentまたは管理されたローカル環境で行います。

## バージョン公開

1. `CHANGELOG.md` と各OSのバージョンを更新する。
2. 4OSのビルドと `docs/manual-test.md` を確認する。
3. `v1.0.0` のような注釈付きタグを作成する。
4. タグから署名済み成果物を作成する。
5. GitHub Releaseへリリースノート、チェックサム、macOS / Windowsの直接配布物を添付する。
6. iOSはApp Store Connect、AndroidはPlay Console、Windows Store版はPartner Centerへ提出する。

## OS別

- macOS: Developer ID Applicationで署名し、Apple公証後のZIPまたはDMGをGitHub Releaseへ添付する。
- Windows: GitHub直接配布はAuthenticode署名する。Microsoft StoreではMSIXを推奨する。
- Android: Google Playには署名済みAABを提出する。直接配布する場合のみ署名済みAPKをReleaseへ添付する。
- iOS: 通常の利用者向けIPAはGitHub Releaseへ添付せず、TestFlight / App Storeで配布する。
