# 万歩計プラネット 実装仕様書

**バージョン**: 6.0
**日付**: 2026-08-10
**前提ドキュメント**: `requirements.md`, `tech-stack.md`

> 本書は Flutter 版の正式仕様である。
> **数値・挙動の正典は `lib/constants/`・`test/`・実装コード** を優先する。
> 過去の置き換え計画（相棒育成など）は [archive/](archive/) を参照。
>
> **2026-08-07〜08 の変更**: 相棒の見た目を「町ビルド風の育成キャラクター」から
> 「夜の地球儀（NASA Black Marble 夜間光画像を球面正射投影し、街明かりが自転する）」に
> 置き換えた。内部の状態管理（`CompanionProvider`/`CompanionState`/`FeedItemType` 等）や
> 数値仕様（3〜7章）は変更していない。見た目の実装詳細は
> [`lib/widgets/companion/companion_avatar.dart`](../lib/widgets/companion/companion_avatar.dart) を参照。
> この変更に単独の archive 計画書は作成していない（コアループ自体は不変のため）。
>
> **2026-08-10 の変更（前半）**: CompanionScreen の表示を大幅に簡素化し（発展度の数値・
> きげんのテキスト・きらめき回数・星スコアの表示を削除、地球儀の見た目自体は変更なし）、
> 累積発電量の表示を追加した。あわせて以下の信頼性まわりの修正を行った:
> 履歴削除後の二重加算防止、さかのぼり同期の冪等化、HealthKit例外処理の統一、
> 設定画面の未確定入力の保存、電池投入処理のアトミック化、表示バージョンの一元化
> （`package_info_plus` 導入）。
>
> **2026-08-10 の変更（後半）**: きらめきタイム・天気/季節演出を、表示だけでなく
> **機能ごと完全に削除**した。前半の変更では「内部ロジックは残し表示だけ消す」方針だったが、
> 後半でこの2機能に限り実装ごと除去する方針に変更している。詳細は 4.5〜4.7, 6, 7 章参照。

---

## 0. 概要

完全オフラインの Flutter アプリ。歩数から移動エネルギー(Wh)を計算し蓄電池に蓄積する。蓄電池が満タンになるとストックされ、星画面で消費して電力を投入し、夜の地球に街明かりが広がっていく。

### 画面構成

| 画面 | 役割 |
|------|------|
| HomeScreen | 蓄電池・今日の歩数/発電量・自動同期 |
| CompanionScreen | 地球儀（発展度に応じた街明かり・自転）・累積発電量・満タン蓄電池の投入 |
| HistoryScreen | 日次の歩数・発電量。全履歴クリアは星の発展状況も初期化する |
| SettingsScreen | 体重・速度・発電係数・GPS 速度計測・星の名前・遊び方・バージョン表示 |

CompanionScreen は 2026-08-10 に表示を簡素化した。きげん・発展度の数値・星スコア
（愛着スコア）は画面に表示されない（内部ロジックとしては残っている。4.5〜4.6節参照）。
きらめきタイム・天気/季節演出は表示ではなく機能自体を削除したため、内部ロジックも
存在しない（4.7章参照）。

---

## 1. 技術スタック

| 項目 | 技術 | バージョン目安 |
|------|------|----------------|
| フレームワーク | Flutter + Dart | SDK ^3.12.1 |
| 健康データ (iOS) | `health` | ^13.0.0 |
| 歩数 (Android) | `pedometer` | ^4.2.0 |
| 権限 | `permission_handler` | ^12.0.3 |
| GPS | `geolocator` | ^13.0.0 |
| アプリ情報 | `package_info_plus` | ^9.0.1 |
| 状態管理 | `provider` | ^6.1.0 |
| ローカル保存 | `shared_preferences` | ^2.3.0 |

アプリバージョン:
- `pubspec.yaml` の `version`（例 `1.0.0+1`）が唯一の管理場所。設定画面は
  `package_info_plus` の `PackageInfo.fromPlatform()` でビルド時にこの値を実行時取得して
  `バージョン {version}+{buildNumber}` の形で表示する（`SettingsScreen._loadAppVersion`）。
  手書きの重複定数（旧 `GameConstants.appVersion`）は 2026-08-10 に削除した。

---

## 2. ディレクトリ構成

```
lib/
├── main.dart
├── app.dart
├── constants/
│   ├── game_constants.dart
│   ├── feed_item_definitions.dart
│   ├── companion_stages.dart
│   └── achievements.dart
├── domain/
│   ├── models/
│   │   ├── player_settings.dart
│   │   ├── battery_state.dart
│   │   ├── feed_item_type.dart
│   │   ├── companion_state.dart
│   │   ├── daily_step_record.dart
│   │   ├── full_battery_event.dart
│   │   ├── feed_event.dart
│   │   ├── companion_stage_event.dart
│   │   └── achievement_event.dart
│   ├── energy_calculator.dart
│   └── companion_logic.dart
├── data/
│   └── local_storage.dart
├── services/
│   ├── health_service.dart
│   └── speed_measurement_service.dart
├── providers/
│   ├── settings_provider.dart
│   ├── energy_provider.dart
│   ├── companion_provider.dart
│   └── history_provider.dart
├── screens/
│   ├── home_screen.dart
│   ├── companion_screen.dart
│   ├── history_screen.dart
│   ├── how_to_play_screen.dart
│   └── settings_screen.dart
├── utils/
│   └── date_key.dart
├── widgets/
│   ├── battery_stock_display.dart
│   └── companion/
│       └── companion_avatar.dart        # 夜の地球儀（球面投影の街明かり）
└── demo_stages_main.dart                # 発展段階の見た目デモ専用エントリポイント
                                          # `flutter run -t lib/demo_stages_main.dart` で起動

assets/
└── earth/
    ├── black_marble_2016.jpg            # NASA Black Marble 夜間光（正距円筒図法・地球儀の元データ）
    └── CREDIT.txt                       # 出典表記

test/
├── energy_calculator_test.dart
├── battery_state_test.dart
├── companion_logic_test.dart
├── local_storage_test.dart
├── energy_provider_test.dart
├── companion_provider_test.dart
├── history_provider_test.dart
├── health_service_test.dart
├── companion_avatar_test.dart
├── town_stats_test.dart
├── home_and_settings_screen_test.dart
├── settings_screen_test.dart
└── widget_test.dart
```

> `lib/constants/companion_atmosphere.dart`、`lib/widgets/companion/companion_weather_overlay.dart`、
> `lib/domain/models/sparkle_event.dart` とそれぞれのテストは、2026-08-10 の天気/季節・
> きらめきタイム機能の完全削除に伴い削除済み（4.7章参照）。

---

## 3. 数値設計

### 3.1 発電変換係数

| 項目 | 値 |
|------|-----|
| デフォルト係数 | `1.0` |
| 設定可能範囲 | `0.1` 〜 `5.0` |
| 基準体重 | `70 kg` |
| 基準速度 | `5.0 km/h` |

定数: `GameConstants.energyCoefficient`

おもちゃの効果は係数に累積乗算（1回あたり ×1.1）。

### 3.2 移動エネルギー計算

```
energyWh = steps × (weightKg / 70) × (speedKmh / 5) × coefficient
```

| パラメータ | 型 | 制約 | デフォルト |
|------------|-----|------|------------|
| steps | int | ≥ 0 | — |
| weightKg | double | 30〜200 | 70 |
| speedKmh | double | 0.5〜15.0 | 5.0 |
| coefficient | double | 0.1〜5.0 | 1.0 |

**1日のエネルギー上限はなし**（歩いた分だけ発電する）。

**計算例**（`test/energy_calculator_test.dart` と一致）:
- 70kg, 5km/h, 1000歩 → `1000.0 Wh`
- 84kg, 6km/h, 5000歩 → `7200.0 Wh`

### 3.3 蓄電池

| 項目 | 値 |
|------|-----|
| 初期容量 | 10,000 Wh |
| 初期蓄積 | 0 Wh |
| 満タン時 | 超過分は折り返し、満タン個数としてストック（`pendingBatteries`） |

容量は給餌効果から導出（永続化しない）。げんきの素1回あたり +2,000 Wh。

### 3.4 歩数同期

- **iOS**: HealthKit から今日（端末ローカル日付 0:00〜現在）の歩数合計
- **Android**: センサー累積値をベースライン正規化して今日分を算出
- 前回同期時の歩数との差分 `deltaSteps` をエネルギーに変換
- `deltaSteps < 0`（センサーリセット）は `totalSteps` を新規歩数として扱う
- ホーム画面表示時・フォアグラウンド復帰時に自動同期
- **同期は「アプリを開いたとき」にしか走らないため、数日開かないと歩数が失われる問題への対応**:
  - Android: `HealthService.normalizeAndroidSteps` のベースラインは
    **「最終同期時点のセンサー値」** を意味し、同期のたびに前進する。
    戻り値は常に `今日これまでに同期した歩数 + 前回同期からの増分` となるため、
    日をまたいでも増分を取りこぼさず、かつ前日までに加算済みの歩数を
    二重計上することもない（`test/health_service_test.dart`）
  - iOS: `EnergyProvider._backfillMissedDays` が前回同期日の翌日〜昨日のうち記録の無い日を
    `HealthService.getStepsForDate` でさかのぼり取得し、見つかった分をその日の記録として
    エネルギーに加算する（`test/energy_provider_test.dart`）
    - 走査は **昨日から新しい順** に行い最大30日分。古い順に走査すると長期不在時に
      上限を古い日で使い切り、直近の歩数を取りこぼすため
    - 加算自体は満タン履歴が日付順に並ぶよう古い日から行う
    - 過去日の換算にも「現在の」体重・速度・係数を用いる（当時の設定は保持していないため）
  - Android は HealthKit のような日付指定の過去データ取得手段がないため、
    上記のベースライン方式のみで対応する（`getStepsForDate` は Android では常に `null`）

#### 3.4.1 同期カーソルと表示用履歴の分離（2026-08-10）

以前は「今日すでに同期済みの歩数」を、画面にも表示する `DailyStepRecord.lastSyncedSteps`
（`daily_record_{date}` として保存）から直接読んでいた。そのため今日の履歴を削除・全クリア
すると、この値も一緒に失われ、次回同期で HealthKit / センサーがまだ返す「今日の歩数」が
新規分として再加算される二重加算バグがあった。

対応として、同期差分の起点を **画面の履歴とは別の専用カーソル**
（`LocalStorage.loadTodaySyncedCursor` / `saveTodaySyncedCursor`、キー
`today_synced_date` / `today_synced_steps`）に分離した。

- `EnergyProvider.syncStepsFromHealth` は `deltaSteps` の計算にこのカーソルを使う
  （`_today.lastSyncedSteps` は表示用の記録としてのみ更新する）
- Android の `HealthService._getStepsFromSensor` も、`alreadySyncedToday` の取得元を
  このカーソルに切り替えた（以前は `daily_record_{today}` の `lastSyncedSteps` を直接見ていた）
- `HistoryProvider.deleteHistoryRecord` / `clearHistory` は `daily_record_*` キーのみを
  削除し、このカーソルには触れない。そのため履歴を削除しても再同期で歩数が失われず、
  二重加算もされない（`test/energy_provider_test.dart` の
  `EnergyProvider 履歴削除後の同期(二重加算防止)` グループ）

**移行互換**: このカーソル導入前のバージョンから更新した端末では、`today_synced_*` が
まだ存在しない。`EnergyProvider._todaySyncedCursor` はその場合、今日の日次記録に残っている
旧方式の `lastSyncedSteps` を起点として使う（0から作り直すと、更新直後の1回だけ今日の
同期済み歩数を新規分として再加算してしまうため）。以降はこのカーソルで管理される
（`test/energy_provider_test.dart` の `EnergyProvider 同期カーソルの移行互換` グループ）。

#### 3.4.2 さかのぼり同期の冪等化（2026-08-10）

以前は「さかのぼり対象の日次記録の保存」と「蓄電池・累積発電量・ストック・満タン履歴の保存」
が別タイミングで行われ、また走査範囲の下限に「前回同期日時」（`_lastSyncedAt`、毎回の同期で
更新される）をそのまま使っていた。そのため、複数日をさかのぼる処理の途中で保存に失敗したり
アプリが終了したりすると、次回同期時には走査範囲の下限がすでにその日を追い越しており、
未反映のままその日の分が永久に失われる可能性があった。

対応として `EnergyProvider._backfillMissedDays` を次のように変更した:

- 走査範囲の下限に、**初回同期時に一度だけ固定する専用の基準日**
  （`LocalStorage.loadBackfillFloorDate` / `saveBackfillFloorDate`、キー
  `backfill_floor_date`）を使う。「前回同期日時」は同期のたびに更新されるため、
  それをそのまま下限にすると失敗した日が次回以降ずっと対象から外れてしまうため
- 各日ごとに「日次記録の保存 → 蓄電池・累積発電量・ストック・満タン履歴の保存 →
  コミット済みマーカー（`LocalStorage.loadBackfillCommittedDates` /
  `saveBackfillCommittedDates`、キー `backfill_committed_dates`）への追加」を順番に行う。
  コミット済みマーカーに入っている日だけを「反映済み」とみなす
- 日ごとの取得（`HealthService.getStepsForDate`）は個別に例外を捕捉して `null`
  （取得失敗）に変換する。1日分の取得失敗が他の日の反映を巻き込んで失敗させない
  （`Future.wait` の一括失敗を避ける）

この設計により、複数日のさかのぼり処理中に1日だけ失敗しても他の日は正常に反映され、
失敗した日は次回同期で再試行され、かつ既に成功した日が二重加算されることはない
（`test/energy_provider_test.dart` の `EnergyProvider さかのぼり同期の冪等性` グループ）。

**残る制約**: SharedPreferences には複数キーにまたがる本当のトランザクションが無いため、
1日分の処理の最中（例: 蓄電池保存後・コミット済みマーカー保存前）にアプリが強制終了した
場合は、理論上ごく僅かな不整合が残り得る。現実的に起きやすい失敗（日をまたぐ複数日の処理中
に1日だけ失敗する、次回同期まで中断する）に対しては安全に回復できる設計だが、完全な
ACID 保証ではない。

---

## 4. データモデル

### 4.1 PlayerSettings

```dart
class PlayerSettings {
  final double weightKg;          // 30.0〜200.0
  final double defaultSpeedKmh;   // 0.5〜15.0
  final double energyCoefficient; // 0.1〜5.0
  final String companionName;
}
```

**SharedPreferences キー**:
- `player_weight_kg`
- `player_default_speed_kmh`
- `player_energy_coefficient`
- `companion_name`

> `companionWeatherFxEnabled`（キー `companion_weather_fx_enabled`）は天気/季節演出の
> 完全削除に伴い 2026-08-10 に削除した。既存インストールに残っている同キーの値は
> 単に読まれなくなるだけで、害はない。

### 4.2 BatteryState

```dart
class BatteryState {
  final double storedWh;
  final double capacityWh;  // 給餌効果込み（導出値）
}
```

- `addEnergy(amount)`: 満タン到達時は折り返し、`batteriesFilled` を返す
- `consumeEnergy(amount)`: 不足時は失敗

**永続化キー**: `battery_stored_wh`（容量は永続化しない）

### 4.3 FeedItemType / CompanionState

```dart
enum FeedItemType { meal, booster, toy }

class CompanionState {
  final int mealCount;
  final int boosterCount;
  final int toyCount;
  int get level => mealCount + boosterCount + toyCount;
}
```

**永続化キー**: `companion_meal_count` / `companion_booster_count` / `companion_toy_count`

旧バージョン（町ビルド機能）の `town_buildings`（house/powerPlant/park の座標付きリスト）が
残っている場合、初回読み込み時に house→meal・powerPlant→booster・park→toy の個数へ変換して引き継ぐ
（`LocalStorage.loadCompanionState` 内のマイグレーション処理）。

### 4.4 イベント記録

| モデル | 用途 | キー |
|--------|------|------|
| DailyStepRecord | 日次歩数・発電量 | `daily_record_{YYYY-MM-DD}` |
| FullBatteryEvent | 蓄電池満タン回数 | `full_battery_events` |
| AchievementEvent | 実績解除 | `companion_achievement_events` |
| CompanionStageEvent | 進化段階到達 | `companion_stage_events` |
| FeedEvent | 給餌直後の UI 演出 | **非永続**（再起動後は再生しない） |

その他: `last_synced_at`, `lifetime_energy_wh`, `pending_batteries`,
`companion_last_fed_at`, `companion_celebrated_stage_ids`, Android ベースライン
（`health_android_baseline_date` / `health_android_baseline_steps`）

同期カーソル・さかのぼり同期の冪等化用（3.4.1, 3.4.2節）:
`today_synced_date` / `today_synced_steps`（今日の同期差分カーソル。表示用履歴とは別で
履歴削除の影響を受けない）、`backfill_floor_date`（さかのぼり対象の下限日、初回同期時に
一度だけ固定）、`backfill_committed_dates`（さかのぼり反映済みの日付一覧）

旧 `town_buildings` キーは companion カウント未作成時のマイグレーション専用（座標は破棄）。

> `SparkleEvent`（キー `sparkle_events`）はきらめきタイム機能の完全削除に伴い
> 2026-08-10 に削除した。既存インストールに残っている同キーの値は読まれなくなるだけ。

### 4.5 きげん（CompanionMood）

`CompanionLogic.moodFor` が `companion_last_fed_at` から導出する（きげん自体は非永続）。
CompanionScreen にテキストとしては表示しない。ただし `CompanionAvatar` に `mood` を
渡し続けており、地球儀の色味にごく薄いムードティントとして反映される
（`_NightGlobePainter` 内の `moodTint`）。

| 状態 | 条件 | 見た目への反映 |
|------|------|---------|
| `none` | 未給餌 | ほぼ無色（わずかに暗く） |
| `happy` | 最終給餌から 24 時間以内 | 淡い暖色ティント |
| `normal` | 最終給餌から 3 日以内 | ティントなし |
| `lonely` | それ以降 | 淡い青色ティント |

閾値定数: `CompanionLogic.happyThreshold` / `normalThreshold`。

### 4.6 愛着スコア

```
bondScore = level × 10 + floor(lifetimeEnergyWh / 100)
```

`CompanionLogic.bondScore` / `CompanionProvider.bondScore`。CompanionScreen には
表示していない（内部指標として算出だけは続けている）。2026-08-10 のきらめきタイム
完全削除に伴い、旧式の `sparkleMoments × 50` の項は削除した。

### 4.7 きらめきタイム・天気/季節演出の完全削除（2026-08-10）

きげん・発展度数値・星スコアの「表示だけ削除」（4.5〜4.6節、0章）とは異なり、
きらめきタイムと天気/季節演出は **実装ごと削除** した。理由はユーザー指示による。

**きらめきタイム関連で削除したもの**:
- `CompanionAvatar`/`_NightGlobePainter` の `showSparkles`/`launchProgress` パラメータと
  `_paintSparkles`（地球儀上に光の粒を描く視覚効果）
- `CompanionStages.sparkleCount()`、`GameConstants.sparkleMomentInterval`
- `CompanionProvider._recordSparkleMoments`、`firstSparkleDate` ゲッター
- `SparkleEvent` モデル、`LocalStorage.loadSparkleEvents`/`saveSparkleEvents`
- 実績「はじめてのきらめき」「きらめきの常連」（`Achievements.all` から削除、7章参照）
- `Achievement.isUnlocked` のシグネチャから `sparkleMoments` 引数を削除
- `CompanionLogic.bondScore` から `sparkleMoments` 項を削除（4.6節）
- `demo_stages_main.dart`（デモ画面）の `CompanionAvatar` 呼び出しから `showSparkles`/
  `launchProgress` 引数を削除（デモ自身の演出用ローカル `launchProgress` 変数は
  ロケット打ち上げ演出として残置）

**天気/季節演出関連で削除したもの**:
- `lib/widgets/companion/companion_weather_overlay.dart`（雨・雪・花びら・落ち葉の
  パーティクル描画ウィジェット）を削除
- `lib/constants/companion_atmosphere.dart` を削除（`weatherOf`/`seasonOf` を含む。
  4.9節の旧記述にあった「時間帯パレットのみ削除・天気は残す」という判断は本対応で上書き）
- `PlayerSettings.companionWeatherFxEnabled`、`SettingsProvider.updateCompanionWeatherFxEnabled`
- 設定画面の「背景の天気演出」トグル（`SwitchListTile`）
- `LocalStorage` の `companion_weather_fx_enabled` キー読み書き

**画面への影響**: CompanionScreen から `weather`/`season`/`weatherFxEnabled` 関連の
状態・ウィジェットをすべて削除。地球儀自体の見た目（自転・街明かり）は変更していない。
また、これに伴い `CompanionScreen`/`CompanionScreen.withClock` の `now` パラメータ
（天気・季節の日付計算にのみ使っていた）も未使用になったため削除した。

**遊び方画面の更新**: `HowToPlayScreen` から「地球の灯り」セクション（進化段階一覧の
プレビュー）と「クリア条件」セクション（きらめきタイムを目標として説明していた部分）を
ユーザー指示により削除した。「画面の見方」セクションの設定画面説明からも「天気演出」の
文言を削除した。

**削除したテスト**: `test/companion_atmosphere_test.dart`、
`test/companion_weather_overlay_test.dart`、および `companion_provider_test.dart`/
`companion_logic_test.dart`/`local_storage_test.dart` 内のきらめき・天気関連テスト。

### 4.8 相棒画面の情緒・触れ合い（見た目）

| 機能 | 内容 | 永続化 |
|------|------|--------|
| なでる | 相棒タップ → ハプティック + ハート演出 | なし |
| スクリーンショットモード | セッション限り。ストック・投入カードを隠し、地球儀＋累積発電量のみ表示 | なし |

CompanionScreen の表示は 2026-08-10 に簡素化された。現在表示しているのは
地球儀（`_CompanionStage`/`CompanionAvatar`、見た目は変更なし）・累積発電量
（`EnergyProvider.lifetimeEnergyWh`）・ストック表示と投入ボタン・次の発展段階までの
残り回数カードのみ。星の名前・発展度の数値・きげんラベル・星スコアの表示は削除した
（4.5〜4.6節のとおり内部ロジックとしては残っている）。きらめきタイム・天気/季節演出は
4.7節のとおり実装ごと削除した。

### 4.9 地球儀ビュー（`CompanionAvatar`）

`assets/earth/black_marble_2016.jpg`（NASA Black Marble 夜間光、正距円筒図法）から
街明かりの輝点を緯度経度付きで抽出し、`CustomPainter` で毎フレーム正射投影して描画する。

- 自転角・視点の傾きから球面座標→正射投影で各光点を再計算。裏側（z≤0）の点は描画せず、
  縁に近い点ほど暗く小さくする（`limb` 減衰）ことで、板ではなく球体が回っているように見せる
- 発展度（`EarthLights`/`TownStats.buildingCount`）に応じて明るい都市から順に点灯していく
- ドラッグで手動回転可（`interactive: true` の場合）。指を離すと自動回転を再開
- 発展度17（最終段階）到達時の演出は都市光点の増加のみ。以前あった軌道アーク装飾は
  地表と無関係に浮いて見えるため 2026-08-08 に削除した。きらめき粒子の視覚効果
  （`showSparkles`）も 2026-08-10 に削除した（4.7節参照）

### 4.10 未使用だった時間帯パレットの整理（2026-08-08〜10、経緯の記録）

CompanionScreen は元々、時間帯（morning/day/evening/night）と天気・季節から
`skyColor`/`tileColor` を計算し `_CompanionStage` に渡していたが、現在の地球儀ビューの
背景は固定の黒〜濃紺グラデーション（宇宙背景）で描画されており、この `skyColor` は
どこにも参照されず実質未使用だった（`tileColor` に至っては元から未使用）。

2026-08-10 の前半対応では「時間帯パレット（`CompanionTimeOfDay`/`paletteOf` 等）のみ削除し、
天気・季節オーバーレイ自体は残す」という判断だったが、同日後半のユーザー指示により
天気・季節演出も含めて完全削除する方針に変わった（4.7節）。結果として
`companion_atmosphere.dart` 自体が存在しない。

`CompanionAtmosphere.stageStory()` / `stageIcon()` も、grep で確認した限り
どこからも呼ばれていない別件の未使用コードだった（`demo_stages_main.dart` は同等の文言を
この関数を使わず独自にインライン定義していた）。ファイルごと削除したため、これらも
自動的に削除された。

### 4.11 設定画面: フォーカスを外さない保存の反映（2026-08-10）

`SettingsScreen._save()` は以前、体重・速度・係数・星の名前の入力を
`TextEditingController` の値ではなく、フォーカスアウト時（`FocusNode` リスナー）または
`onSubmitted`（キーボードの「完了」操作）でのみ更新される state 変数から読んでいた。
そのため、入力欄にフォーカスが残ったまま（フォーカスを外さず・「完了」を押さず）
保存ボタンを押すと、直前まで表示されていた古い値がそのまま保存される不具合があった。

`_save()` の冒頭で `_applyWeightText()` / `_applySpeedText()` /
`_applyCoefficientText()` / `_applyCompanionNameText()` を呼び、各コントローラーの
現在の入力値を必ず検証・クランプしてから保存するようにした。不正な文字列は直前の値へ
フォールバックし、範囲外の数値は既存の範囲（`GameConstants.minWeightKg` 等）へ
クランプする、という既存の挙動をそのまま「保存ボタン押下時」にも適用する形。

## 5. ごはん（電力投入）

### 5.1 定義（内部実装）

`FeedItemType` とその効果は次のとおり定義されている。ただし **現行 UI（CompanionScreen）は
種類選択を提供せず、「投入」ボタン1つで常に `meal` として計上する**
（`companion_screen.dart` の `_investBattery()` がセーブ互換のため内部で meal 固定呼び出しをする、とコメントされている）。
booster・toy への割当経路だった `CompanionProvider.feedAuto()`（meal→booster→toy の順に自動割当）は
UIから呼ばれない未使用コードだったため 2026-08-08 に削除した。
booster・toy の効果自体（`CompanionState`/`feed_item_definitions.dart`）と
`CompanionProvider.feedChosen(type)` は引き続き存在するが、それを呼び出すUI導線がないため、
現状は事実上到達不能。

| type | 表示名 | コスト(満タン蓄電池個数) | 効果 | UI から到達可能か |
|------|--------|---------------------------|------|--------------------|
| meal | ごはん | 1 | なつき度(発展度) +1（数値効果なし） | ○（唯一の投入経路） |
| booster | げんきの素 | 2 | 蓄電池容量 +2,000 Wh | ×（呼び出すUI導線がない） |
| toy | おもちゃ | 1 | 係数 ×1.1（累積乗算） | ×（同上） |

> 給餌に「上限」はない。旧バージョンにあった 5×5 グリッド・空きマス判定は廃止した
（`CompanionState` は座標を持たず、種類別カウントのみを保持する）。

### 5.2 投入フロー（現行 UI）

1. 歩行でエネルギー蓄積 → 満タン到達で `pendingBatteries` 増加
2. 星画面で「投入」ボタン → `CompanionProvider.investBattery()` を呼ぶ
3. `investBattery()` 内でストック消費（`EnergyProvider.consumeStockedBatteries(1)`）と
   発展更新（`feedChosen(FeedItemType.meal)`）を呼び出し側から見て単一の操作として実行する
4. 容量再計算・進化段階祝福・実績チェック

#### 5.2.1 電池投入処理のアトミック化（2026-08-10）

以前はストック消費と発展更新が別々の provider 呼び出しで、間に永続化のタイミングが
分かれていた。消費後に発展更新側が失敗すると「電池だけ消費されて発展度が増えない」
不整合が起こり得た。またボタンが処理中も有効なままだったため、連打すると同じストックを
複数回消費しようとする競合状態もあり得た。

`CompanionProvider.investBattery()` として次のようにまとめた:

- 内部の `bool _investing` フラグで多重実行をガードする。Dart はシングルスレッドの
  イベントループで、`await` を挟まない区間は他のコードに割り込まれないため、
  `Future.wait([investBattery(), investBattery()])` のように「同時に」呼んでも
  2回目の呼び出しは即座に `false` を返し、ストックは1個しか消費されない
- ストック消費 → 発展更新の順に実行し、発展更新（`feedChosen`）が例外を投げた場合は
  消費したストックを `EnergyProvider.creditStockedBatteries()` で戻し、メモリ上の
  `CompanionState` もこの呼び出し前の状態に戻してから例外を再送出する
- `CompanionScreen` 側は `_investing` state で投入ボタンを処理中は無効化し、
  `investBattery()` が例外を投げた場合は SnackBar で通知する

**残る制約**: ロールバックの対象は「ストック消費」と「`CompanionState` の発展度」に限る。
`feedChosen`/`_feed` 内部の副次的な永続化（実績・進化祝福の記録、
`EnergyProvider.applyBatteryState` による蓄電池容量の反映、`companion_last_fed_at` の
更新）は、そこに到達した時点で個別に永続化されるため、この呼び出し単位のロールバック
対象にはなっていない。完全なトランザクション化は本対応のスコープ外。

---

## 6. 発展段階（地球の灯り）

`CompanionStages.stages` に発展度（なつき度と同じ数値、投入回数の合計）のしきい値で定義:

| 発展度 | id | 段階名 |
|--------|-----|--------|
| 0 | egg | 暗い地球 |
| 1 | crack | 最初の灯り |
| 2 | hatch | 村の灯り |
| 4 | kid | 街の光帯 |
| 7 | charged | 大都市が輝く |
| 10 | reliable | 大陸の光網 |
| 13 | radiant | 夜の地球が浮かぶ |
| 17 | star | 軌道から見た地球 |

最終段階（17）到達後は見た目の段階は固定され、`TownStats.buildingCount`/`population`
（`CompanionStages.nextMilestone` 経由。`population` は現在 UI 未表示、`buildingCount` は
地球儀の光点数の算出にのみ使用）だけが増え続ける。きらめきタイム演出・回数カウントは
2026-08-10 に機能ごと削除した（4.7節）。

---

## 7. 実績

`lib/constants/achievements.dart` に定義（4種。2026-08-10 にきらめきタイム関連の
「はじめてのきらめき」「きらめきの常連」を削除し、6種から4種になった）:

- はじめての投入 / 電力が回りはじめた / 灯りが広がりはじめた / 夜の地球が輝く

解除条件は `Achievement.isUnlocked(CompanionState companion)`（`CompanionState` のみを
引数に取る。旧 `sparkleMoments` 引数は削除済み）。解除時は相棒画面で祝福ダイアログ表示。

---

## 8. Providers

| Provider | 状態 | 主要メソッド |
|----------|------|--------------|
| SettingsProvider | PlayerSettings | `updateWeight`, `updateSpeed`, `updateCoefficient`, `updateCompanionName` |
| EnergyProvider | BatteryState, DailyStepRecord, pendingBatteries, lifetimeEnergyWh | `syncStepsFromHealth`, `consumeStockedBatteries`, `creditStockedBatteries`（ロールバック用）, `resetProgress`, `refreshDisplay` |
| CompanionProvider | CompanionState, mood, bondScore, 実績・進化キュー, FeedEvent | `feedChosen`, `investBattery`（ストック消費+発展更新の単一操作）, `resetProgress`, `effectiveCapacityWh`, `effectiveCoefficient` |
| HistoryProvider | — | `loadHistory`, `deleteHistoryRecord`, `clearHistory`（全履歴削除＋星の発展状況リセット）, イベント読み出し |

`EnergyProvider` は `CompanionProvider.effectiveCoefficient` を係数供給元として参照する。
`HistoryProvider` は `CompanionProvider` にも依存する（`clearHistory` が
`CompanionProvider.resetProgress`/`EnergyProvider.resetProgress` を呼ぶため）。

> `SettingsProvider.updateCompanionWeatherFxEnabled` と `CompanionProvider.firstSparkleDate`
> は、それぞれ天気演出・きらめきタイムの完全削除に伴い 2026-08-10 に削除した（4.7節）。

### 8.1 全履歴クリアと星の発展状況リセット（2026-08-10）

`HistoryProvider.clearHistory()` は全日次記録の削除に加えて、星の発展状況
（発展度・蓄電池の蓄積量/容量・累積発電量・満タンストック数）も初期状態に戻す。
個別の1日削除（`deleteHistoryRecord`）はこのリセットを行わない。

- `CompanionProvider.resetProgress()`: `CompanionState` を `CompanionState.initial()`
  （発展度0）に戻す
- `EnergyProvider.resetProgress()`: 蓄電池の蓄積量・累積発電量・ストック数を0に戻す
  （容量は `resetProgress` 後の `CompanionState` から再計算されるため、先に
  `CompanionProvider.resetProgress()` を呼ぶ必要がある）
- **同期カーソル（3.4.1節）・さかのぼり同期のコミット済みマーカー（3.4.2節）には
  触れない。** ここをリセットすると、今日すでに同期済みの歩数が次回同期で新規分として
  再加算されてしまうため
- `HistoryScreen` の「履歴をクリア」確認ダイアログの文言もこの挙動を明記するよう更新した

---

## 9. サービス

### HealthService

- iOS: `health` パッケージで HealthKit 歩数取得
- Android: `pedometer` でセンサー値取得、ベースライン正規化
- 権限拒否時は `HealthServiceException`
- **例外処理の統一（2026-08-10）**: `configure()` / `requestPermissions()` /
  `getTodaySteps()`（iOSの内部実装 `_getStepsFromHealthKit`）で `health` パッケージが
  投げる素のプラグイン例外を捕捉し、`HealthServiceException` に変換する
  （ユーザー向けメッセージに内部例外の詳細はそのまま出さない）。
  `getStepsForDate()` は独自のドキュメント契約どおり「取得できなければ例外を投げず
  `null` を返す」を徹底し、プラグイン例外も内部で捕捉して `null` に変換する。
  `HomeScreen._sync` にも `HealthServiceException` 以外の想定外エラー用の
  フォールバック catch を追加した

### SpeedMeasurementService

- `geolocator` で GPS 位置変化から歩行速度を計測
- 設定画面から起動し、結果をデフォルト速度に反映

---

## 10. テスト要件

`flutter test` を **すべてパス** すること。テストが仕様の Source of Truth。

| ファイル | 対象 |
|----------|------|
| `energy_calculator_test.dart` | 計算式・上限なし |
| `battery_state_test.dart` | 加算・消費・満タン折り返し |
| `companion_logic_test.dart` | 給餌効果・愛着スコア・きげん判定 |
| `local_storage_test.dart` | シリアライズ・導出容量・旧データ移行 |
| `energy_provider_test.dart` | 同期・係数・refreshDisplay・履歴削除後の二重加算防止（3.4.1節）・さかのぼり同期の冪等性（3.4.2節） |
| `companion_provider_test.dart` | feedChosen・実績・進化祝福・investBattery のアトミック性（5.2.1節） |
| `history_provider_test.dart` | 履歴削除・全履歴クリアによる星の発展状況リセット（8.1節） |
| `health_service_test.dart` | Android 正規化・プラグイン例外の HealthServiceException への変換（9節） |
| `companion_avatar_test.dart` | 全進化段階での `CompanionAvatar` 描画 |
| `town_stats_test.dart` | `TownStats.buildingCount`/`population` の算出 |
| `home_and_settings_screen_test.dart` | ホーム/設定画面のナビゲーション（遊び方ボタンの位置、星アイコン） |
| `settings_screen_test.dart` | フォーカスを外さない保存時の入力反映・不正値のフォールバック/クランプ（4.11節）・バージョン表示（1節） |
| `widget_test.dart` | アプリ起動 |

> `companion_atmosphere_test.dart`、`companion_weather_overlay_test.dart` は
> 対象コードごと 2026-08-10 に削除した（4.7節）。

---

## 11. 用語集

| 用語 | 意味 |
|------|------|
| Wh | ワット時。ゲーム内エネルギー単位 |
| 移動エネルギー | 歩数・体重・速度から算出されるゲーム資源 |
| 蓄電池 | エネルギーの貯蔵。満タンでストックに変換 |
| 満タンストック | 蓄電池が満タンになった回数。給餌に消費 |
| 同期 | 歩数を取得し差分をエネルギーに反映する操作 |
| なつき度 | 給餌回数の合計。進化段階を決定する（＝発展度） |
| 愛着スコア | なつき度×10 + 累積発電量/100。内部指標のみ（非表示） |
| きげん | 最終給餌からの経過で決まる気分（happy / normal / lonely / none）。地球儀の色味への薄いティントのみ（テキスト非表示） |
| なでる | 相棒タップの軽い触れ合い演出（電気を消費しない） |
| 同期カーソル | 今日すでに同期済みの歩数を、画面の履歴とは別に保持する値。履歴削除の影響を受けない（3.4.1節） |
| さかのぼり基準日 | さかのぼり同期の対象とする最古の日付。初回同期時に一度だけ固定する（3.4.2節） |

> きらめきタイム・天気/季節演出は 2026-08-10 に機能ごと削除したため、用語集から除いた
> （4.7節参照）。
