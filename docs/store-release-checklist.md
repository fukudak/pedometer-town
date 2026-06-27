# ストア公開チェックリスト

最終更新: 2026-06-27

具体的な操作手順は [release-procedures.md](release-procedures.md) を参照。

## 完了済み（コード・設定）

- [x] アプリ表示名を「万歩計タウン」に統一（Android `AndroidManifest.xml` / iOS `Info.plist`）
- [x] `pubspec.yaml` の description を実態に合わせて更新
- [x] iOS `NSHealthShareUsageDescription`（HealthKit利用目的）を追加 ※未設定だと審査リジェクトされる必須項目だった
- [x] iOS `ITSAppUsesNonExemptEncryption = false` を追加（暗号化に関する質問をスキップ）
- [x] Android リリースビルド用の署名鍵（upload-keystore.jks）を生成し、`key.properties` 経由で `build.gradle.kts` に組み込み
  - `android/key.properties`、`android/upload-keystore.jks` は `.gitignore` 済み（コミットされない）
  - `flutter build apk --release` で署名済みビルドが生成されることを確認済み
- [x] README.md を実態に合わせて更新
- [x] `doc/` 設計ドキュメントを実装に合わせて更新（2026-06-27）
- [x] プライバシーポリシー ドラフト作成（`docs/privacy.html`）
- [x] ストア掲載文ドラフト作成（`docs/store-listing.md`）

## ⚠️ 重要: 署名鍵のバックアップ（必須・最優先）

`android/upload-keystore.jks` と `android/key.properties` は、**一度Play Storeに公開した後はこの2つのファイルがないと同じアプリの更新版を二度と公開できません**。

- 今すぐ両ファイルを安全な場所（パスワード管理ツール、暗号化した外部ドライブ、クラウドの個人用プライベートストレージ等）にバックアップしてください
- パスワードは `android/key.properties` 内に平文で書かれています。このファイル自体を安全に保管してください
- 絶対に公開リポジトリにコミットしないこと（現状 .gitignore 済みで安全です）

## 必要なあなたの作業（私には実行不可）

### 両ストア共通
- [ ] GitHub Pages を有効化し、`docs/privacy.html` を公開
  - GitHubリポジトリ → Settings → Pages → Source を `Deploy from a branch` にし、Branch を `master` / フォルダを `/docs` に設定
  - 公開後のURLを `docs/store-listing.md` 内のプライバシーポリシーURLに反映
- [ ] `docs/store-listing.md` の説明文・キーワードを確認・推敲
- [ ] スクリーンショット撮影（ホーム画面・町画面・履歴画面・設定画面など）

### Google Play
- [ ] Google Play Console アカウント登録（初回$25）
- [ ] アプリの新規作成、ストア掲載情報の入力
- [ ] コンテンツのレーティング questionnaire 回答
- [ ] データセーフティ フォーム回答（収集データ: 歩数・位置情報・体重等の設定値、いずれも端末内保存のみで送信なし）
- [ ] `flutter build appbundle --release` で .aab を作成しアップロード
- [ ] 内部テスト → 製品版リリースの審査提出

### App Store
- [ ] Xcode で `ios/Runner.xcworkspace` を開き、Signing & Capabilities で自分の Apple Developer Team を選択
- [ ] App Store Connect でアプリを新規作成（Bundle ID: `com.pedometertown.pedometerTown`）
- [ ] App Privacy（プライバシー“栄養成分表示”）の回答: Health & Fitness データ・位置情報を収集するが第三者に提供しない、トラッキングに使用しない 等
- [ ] スクリーンショット（必要なデバイスサイズ分）
- [ ] `flutter build ipa --release` でアーカイブを作成し Xcode/Transporter でアップロード
- [ ] TestFlight での動作確認 → 審査提出

## 既知の注意事項

- `health`, `pedometer`, `device_info_plus` が将来の Flutter バージョンで Kotlin Gradle Plugin の非互換警告を出している（現時点ではビルドに影響なし、将来的にパッケージ更新が必要になる可能性）
- Android の Bundle ID: `com.pedometertown.pedometer_town` / iOS: `com.pedometertown.pedometerTown`（大文字小文字が異なるが、プラットフォームごとに別IDのため問題なし）
