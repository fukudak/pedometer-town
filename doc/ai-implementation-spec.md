# 万歩計タウン 実装仕様書

**バージョン**: 4.0
**日付**: 2026-08-08
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

---

## 0. 概要

完全オフラインの Flutter アプリ。歩数から移動エネルギー(Wh)を計算し蓄電池に蓄積する。蓄電池が満タンになるとストックされ、まち画面で消費して電力を投入し、夜の地球に街明かりが広がっていく。

### 画面構成

| 画面 | 役割 |
|------|------|
| HomeScreen | 蓄電池・今日の歩数/発電量・自動同期 |
| CompanionScreen | 発展段階（地球の灯り）・きげん・満タン蓄電池の投入・統計 |
| HistoryScreen | 日次の歩数・発電量 |
| SettingsScreen | 体重・速度・発電係数・GPS 速度計測・まちの名前・遊び方 |

---

## 1. 技術スタック

| 項目 | 技術 | バージョン目安 |
|------|------|----------------|
| フレームワーク | Flutter + Dart | SDK ^3.12.1 |
| 健康データ (iOS) | `health` | ^13.0.0 |
| 歩数 (Android) | `pedometer` | ^4.2.0 |
| 権限 | `permission_handler` | ^12.0.3 |
| GPS | `geolocator` | ^13.0.0 |
| 状態管理 | `provider` | ^6.1.0 |
| ローカル保存 | `shared_preferences` | ^2.3.0 |

アプリバージョン:
- `pubspec.yaml` の `version`: `1.0.0+1`（ストア向け build-name / build-number）
- 設定画面に表示する `GameConstants.appVersion`: `0.9`（UI 表示用。変更時は両方を揃えること）

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
│   ├── companion_atmosphere.dart
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
│   │   ├── sparkle_event.dart
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
│       ├── companion_avatar.dart       # 夜の地球儀（球面投影の街明かり）
│       └── companion_weather_overlay.dart
└── demo_stages_main.dart               # 発展段階の見た目デモ専用エントリポイント
                                         # `flutter run -t lib/demo_stages_main.dart` で起動

assets/
└── earth/
    ├── black_marble_2016.jpg           # NASA Black Marble 夜間光（正距円筒図法・地球儀の元データ）
    └── CREDIT.txt                      # 出典表記

test/
├── energy_calculator_test.dart
├── battery_state_test.dart
├── companion_logic_test.dart
├── local_storage_test.dart
├── energy_provider_test.dart
├── companion_provider_test.dart
├── history_provider_test.dart
├── health_service_test.dart
├── companion_atmosphere_test.dart
├── companion_weather_overlay_test.dart
├── companion_avatar_test.dart
├── town_stats_test.dart
├── home_and_settings_screen_test.dart
└── widget_test.dart
```

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

---

## 4. データモデル

### 4.1 PlayerSettings

```dart
class PlayerSettings {
  final double weightKg;          // 30.0〜200.0
  final double defaultSpeedKmh;   // 0.5〜15.0
  final double energyCoefficient; // 0.1〜5.0
  final bool companionWeatherFxEnabled;
  final String companionName;
}
```

**SharedPreferences キー**:
- `player_weight_kg`
- `player_default_speed_kmh`
- `player_energy_coefficient`
- `companion_weather_fx_enabled`
- `companion_name`

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
| SparkleEvent | きらめきタイム発生 | `sparkle_events` |
| AchievementEvent | 実績解除 | `companion_achievement_events` |
| CompanionStageEvent | 進化段階到達 | `companion_stage_events` |
| FeedEvent | 給餌直後の UI 演出 | **非永続**（再起動後は再生しない） |

その他: `last_synced_at`, `lifetime_energy_wh`, `pending_batteries`,
`companion_last_fed_at`, `companion_celebrated_stage_ids`, Android ベースライン

旧 `town_buildings` キーは companion カウント未作成時のマイグレーション専用（座標は破棄）。

### 4.5 きげん（CompanionMood）

`CompanionLogic.moodFor` が `companion_last_fed_at` から導出する（きげん自体は非永続）。

| 状態 | 条件 | UI 目安 |
|------|------|---------|
| `none` | 未給餌 | まだ生まれていない |
| `happy` | 最終給餌から 24 時間以内 | ごきげん |
| `normal` | 最終給餌から 3 日以内 | ふつう |
| `lonely` | それ以降 | さみしそう |

閾値定数: `CompanionLogic.happyThreshold` / `normalThreshold`。

### 4.6 愛着スコア

```
bondScore = level × 10 + floor(lifetimeEnergyWh / 100) + sparkleMoments × 50
```

`CompanionLogic.bondScore` / `CompanionProvider.bondScore`。

### 4.7 相棒画面の情緒・触れ合い（見た目）

| 機能 | 内容 | 永続化 |
|------|------|--------|
| 時間帯パレット | morning/day/evening/night（端末ローカル時刻） | なし |
| 天気・季節オーバーレイ | 日付シードの天気 + 月の季節パーティクル | `companion_weather_fx_enabled` で ON/OFF |
| なでる | 相棒タップ → ハプティック + ハート演出 | なし |
| スクリーンショットモード | セッション限り。ストック・統計等を隠し、相棒＋名前＋段階を中心表示 | なし |

### 4.8 地球儀ビュー（`CompanionAvatar`）

`assets/earth/black_marble_2016.jpg`（NASA Black Marble 夜間光、正距円筒図法）から
街明かりの輝点を緯度経度付きで抽出し、`CustomPainter` で毎フレーム正射投影して描画する。

- 自転角・視点の傾きから球面座標→正射投影で各光点を再計算。裏側（z≤0）の点は描画せず、
  縁に近い点ほど暗く小さくする（`limb` 減衰）ことで、板ではなく球体が回っているように見せる
- 発展度（`EarthLights`/`TownStats.buildingCount`）に応じて明るい都市から順に点灯していく
- ドラッグで手動回転可（`interactive: true` の場合）。指を離すと自動回転を再開
- 発展度17（最終段階）到達時の演出は都市光点の増加のみ。以前あった軌道アーク装飾は
  地表と無関係に浮いて見えるため 2026-08-08 に削除した

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
2. まち画面で「投入」ボタン → `EnergyProvider.consumeStockedBatteries(1)` で蓄電池1個消費
3. `CompanionProvider.feedChosen(FeedItemType.meal)` を常に呼び出し、発展度 +1（常に成功）
4. 容量再計算・進化段階祝福・実績チェック・きらめきタイム記録

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
地球儀の光点数の算出にのみ使用）と、きらめきタイム回数だけが増え続ける。
きらめきタイムは2回投入するごとに1回発生（`GameConstants.sparkleMomentInterval`）。

---

## 7. 実績

`lib/constants/achievements.dart` に定義（6種）:

- はじめてのごはん / げんきの素デビュー / 一緒に遊ぶ道具
- すっかりなついた（なつき度10）
- はじめてのきらめき / きらめきの常連（きらめきタイム 1回 / 5回）

解除時は相棒画面で祝福ダイアログ表示。

---

## 8. Providers

| Provider | 状態 | 主要メソッド |
|----------|------|--------------|
| SettingsProvider | PlayerSettings | `updateWeight`, `updateSpeed`, `updateCoefficient`, `updateCompanionName`, `updateCompanionWeatherFxEnabled` |
| EnergyProvider | BatteryState, DailyStepRecord, pendingBatteries | `syncStepsFromHealth`, `consumeStockedBatteries`, `refreshDisplay` |
| CompanionProvider | CompanionState, mood, bondScore, 実績・進化キュー, FeedEvent | `feedChosen`, `effectiveCapacityWh`, `effectiveCoefficient`, `firstSparkleDate` |
| HistoryProvider | — | `loadHistory`, `deleteHistoryRecord`, イベント読み出し |

`EnergyProvider` は `CompanionProvider.effectiveCoefficient` を係数供給元として参照する。

---

## 9. サービス

### HealthService

- iOS: `health` パッケージで HealthKit 歩数取得
- Android: `pedometer` でセンサー値取得、ベースライン正規化
- 権限拒否時は `HealthServiceException`

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
| `energy_provider_test.dart` | 同期・係数・refreshDisplay |
| `companion_provider_test.dart` | feedChosen・実績・進化祝福・きらめきタイム |
| `history_provider_test.dart` | 履歴削除 |
| `health_service_test.dart` | Android 正規化 |
| `companion_atmosphere_test.dart` | 時間帯・天気・季節判定 |
| `companion_weather_overlay_test.dart` | 天気演出の表示切り替え |
| `companion_avatar_test.dart` | 全進化段階での `CompanionAvatar` 描画 |
| `town_stats_test.dart` | `TownStats.buildingCount`/`population` の算出 |
| `home_and_settings_screen_test.dart` | ホーム/設定画面のナビゲーション（遊び方ボタンの位置、まちアイコン） |
| `widget_test.dart` | アプリ起動 |

---

## 11. 用語集

| 用語 | 意味 |
|------|------|
| Wh | ワット時。ゲーム内エネルギー単位 |
| 移動エネルギー | 歩数・体重・速度から算出されるゲーム資源 |
| 蓄電池 | エネルギーの貯蔵。満タンでストックに変換 |
| 満タンストック | 蓄電池が満タンになった回数。給餌に消費 |
| 同期 | 歩数を取得し差分をエネルギーに反映する操作 |
| なつき度 | 給餌回数の合計。進化段階を決定する |
| 愛着スコア | なつき度×10 + 累積発電量/100 + きらめきタイム×50 |
| きげん | 最終給餌からの経過で決まる気分（happy / normal / lonely / none） |
| きらめきタイム | 最終進化段階到達後、一定間隔で発生する祝福演出 |
| なでる | 相棒タップの軽い触れ合い演出（電気を消費しない） |
