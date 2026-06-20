# ストア公開 手順書

[store-release-checklist.md](store-release-checklist.md) の「必要なあなたの作業」を、実際の操作手順に落とし込んだものです。上から順に進めてください。

---

## 0. 事前バックアップ（最優先・まだの場合は今すぐ）

以下の2ファイルを安全な場所（パスワード管理ツール、暗号化した外部ドライブ等）にバックアップする。

```
android/upload-keystore.jks
android/key.properties
```

この2つを失うと、Play Store公開後に同じアプリの更新版を二度と出せなくなる。

---

## 1. GitHub Pages を有効化してプライバシーポリシーを公開する

1. ブラウザで `https://github.com/fukudak/pedometer-town/settings/pages` を開く
2. "Build and deployment" の **Source** を `Deploy from a branch` にする
3. **Branch** を `master`、フォルダを `/docs` に設定して **Save**
4. 数分待つと `https://fukudak.github.io/pedometer-town/privacy.html` でプライバシーポリシーが公開される
5. 公開されたURLにアクセスして表示を確認する
6. `docs/store-listing.md` 内の「プライバシーポリシーURL」が実際のURLと一致しているか確認する（リポジトリ名が異なる場合は要修正）

---

## 2. スクリーンショットを準備する

1. 実機（または `flutter run` でシミュレータ）でアプリを起動
2. 以下の画面を撮影する（最低4〜6枚推奨）
   - ホーム画面（蓄電池・歩数・発電量が表示された状態）
   - 町画面（建物がいくつか建っている状態）
   - 建物配置中の画面（「配置する場所をタップ」のバナーが出た状態）
   - 履歴画面
   - 設定画面
3. iOS は端末ごとに必要なサイズが異なる（6.7インチ / 6.5インチ / 5.5インチ等）。手元の実機サイズが対象外の場合、Xcodeシミュレータで撮影するか、App Store Connect側で後から追加できるサイズに絞る
4. Android は単一サイズで概ね問題ないが、複数デバイスのスクリーンショットがあると印象が良い

---

## 3. iOS: Xcode で署名チームを設定する

1. ターミナルで以下を実行して Xcode を開く

   ```bash
   open ios/Runner.xcworkspace
   ```

   ※ `.xcodeproj` ではなく `.xcworkspace` を開くこと（CocoaPods管理のため）

2. 左のナビゲータで一番上の `Runner`（プロジェクト）を選択
3. 中央の TARGETS から `Runner` を選択
4. 上部タブの **Signing & Capabilities** を開く
5. **Team** のドロップダウンから、自分の Apple Developer アカウント（個人 or 組織）を選択
6. Bundle Identifier が `com.pedometertown.pedometerTown` になっていることを確認
7. エラーが出ていなければ署名設定は完了（自動的にプロビジョニングプロファイルが生成される）

---

## 4. App Store Connect でアプリを新規作成する

1. `https://appstoreconnect.apple.com` にログイン
2. **マイアプリ** → 左上の **+** → **新規アプリ**
3. 以下を入力
   - プラットフォーム: iOS
   - 名前: `万歩計タウン`
   - プライマリ言語: 日本語
   - バンドルID: `com.pedometertown.pedometerTown`（事前に Certificates, Identifiers & Profiles で同じBundle IDのApp IDを作成しておく必要がある場合あり。Xcodeで一度ビルド/署名すると自動登録されることが多い）
   - SKU: 任意の一意な文字列（例: `pedometertown001`）
4. 作成後、左メニューの **アプリ情報** で以下を入力
   - サブタイトル（任意）
   - プライバシーポリシーURL: 手順1で公開したURL
   - カテゴリ: ヘルスケア/フィットネス
5. **App Privacy**（プライバシー）セクションで質問に回答
   - 収集するデータ: 健康データ（歩数）、位置情報
   - 用途: アプリ機能の提供のみ。ユーザーに関連付けない・トラッキングしない、を選択
   - `docs/privacy.html` の内容を参照しながら回答する
6. **価格および配信状況** で無料/有料を設定し、配信先地域を選択

---

## 5. iOS ビルドをアップロードする

1. ターミナルで以下を実行してIPAを作成

   ```bash
   flutter build ipa --release
   ```

2. ビルドが成功すると `build/ios/archive/Runner.xcarchive` が生成される
3. Xcode を開き、メニューの **Window → Organizer** を選択
4. 生成された Archive を選択し、**Distribute App** をクリック
5. **App Store Connect** → **Upload** を選択し、画面の指示に従って進める
6. アップロード完了後、App Store Connect の **TestFlight** タブで処理完了（数分〜数十分）を待つ
7. TestFlight で自分の端末にインストールして動作確認する
8. 問題なければ **App Store** タブでビルドを選択し、スクリーンショット等を入力して **審査へ提出**

---

## 6. Google Play Console に登録する

1. `https://play.google.com/console/signup` にアクセス
2. Google アカウントでログインし、登録料 $25 を支払う（初回のみ、デベロッパーアカウント全体で1回）
3. デベロッパー名、連絡先情報等を入力して登録完了

---

## 7. Google Play でアプリを新規作成する

1. Play Console ダッシュボードで **アプリを作成**
2. 以下を入力
   - アプリ名: `万歩計タウン`
   - デフォルトの言語: 日本語
   - アプリ/ゲーム: アプリ
   - 無料/有料: 選択
3. 作成後、左メニューの **ストアの掲載情報** で以下を入力
   - 簡単な説明・詳細な説明: `docs/store-listing.md` の内容を使用
   - アプリのアイコン、スクリーンショット、フィーチャーグラフィックをアップロード
   - カテゴリ: 健康/フィットネス
4. **ポリシー → アプリのコンテンツ** で以下に回答
   - プライバシーポリシー: 手順1で公開したURL
   - 広告: なし（広告を含まない場合）
   - コンテンツのレーティング: アンケートに回答（健康フィットネス系アプリとして概ね「全年齢対象」になる想定）
   - データセーフティ: 収集する情報（歩数、位置情報、体重等の設定値）/ 用途（アプリ機能のみ）/ 第三者への共有なし / 暗号化なし送信（端末内保存のみのため「データを収集しているが送信していない」を選択） / ユーザーがデータ削除可能（アプリ内履歴削除機能あり）

---

## 8. Android ビルドを作成・アップロードする

1. ターミナルで以下を実行して .aab（App Bundle）を作成

   ```bash
   flutter build appbundle --release
   ```

2. 生成物は `build/app/outputs/bundle/release/app-release.aab`
3. Play Console の左メニュー **テスト → 内部テスト**（最初は内部テストを推奨）
4. **新しいリリースを作成** → 上記の `.aab` をアップロード
5. リリースノートを入力して保存 → 確認 → 公開
6. 内部テストのテスターとして自分のGoogleアカウントを登録し、テストリンクからインストールして動作確認
7. 問題なければ **製品版** リリースを作成し、同じ `.aab` を使って審査に提出

---

## 9. 審査提出後

- App Store: 通常1〜3日程度で審査結果が来る。リジェクトされた場合は理由を確認し、該当箇所を修正して再提出
- Google Play: 初回審査は数時間〜数日程度。ポリシー違反の指摘があれば修正して再提出

---

## 困ったときに確認する箇所

| 問題 | 確認先 |
|---|---|
| iOS署名エラー | 手順3（Xcode Team設定）、Apple Developer の証明書/プロビジョニングプロファイル |
| Android署名エラー | `android/key.properties` の内容、`upload-keystore.jks` の存在 |
| Health/位置情報の審査リジェクト | `docs/privacy.html` の内容と App Privacy / データセーフティ の回答が一致しているか |
| ビルドが古いバージョンのまま | `pubspec.yaml` の `version:` を更新してから再ビルド（例: `1.0.0+1` → `1.0.1+2`） |
