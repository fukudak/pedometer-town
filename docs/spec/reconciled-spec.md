# 万歩計タウン 仕様書(コード照合済み)

- 作成日: 2026-10-05
- 対象コミット: `fa0c3f7`(master)＋ 未コミットの作業ツリー(`local_storage.dart` / `energy_provider.dart` / `companion_provider.dart` / `main.dart` のジャーナル方式変更を含む)
- 参照した既存ドキュメント: `README.md`, `doc/requirements.md`(v2.4), `doc/ai-implementation-spec.md`(v6.0), `doc/tech-stack.md`(v1.3)
- ステータス: **確定**(2026-10-05 ユーザー承認。§7 Open Questions は未解決のまま残す)
- 検証状況: コードとテストの**読解**による照合。`flutter test` / `flutter analyze` は sandbox が Flutter SDK キャッシュへの書き込みを拒否したため**未実行**(テストの合否は未確認)。実機確認も未実施。

> このドキュメントは、既存ドキュメントとコードベースを突合し、ユーザー確認のうえで確定した**正本**の仕様書である。既存ドキュメントは上書きしていない。
> 対象外: `docs/` 配下のストア公開・プライバシー文書(§8 参照)。

---

## 1. Overview

- **目的・対象範囲**: 歩数を移動エネルギー(Wh)に変換して蓄電池に溜め、満タン分(ストック)を星画面で「投入」すると、NASA Black Marble の夜間光を球面投影した地球儀に街明かりが広がる Flutter アプリ。完全オフライン、データは端末内(SharedPreferences)のみ。
- **主要ユースケース**: 歩く → アプリを開くと自動同期 → 蓄電池が満タンでストック +1 → 星画面で投入 → 発展度 +1 で灯りが増える。
- **対象読者**: 開発者(AI エージェント含む)。
- **クリア条件なし**の無限育成型。最終段階後は「完成した星」が積み上がる(§4.6)。

## 2. Architecture & Dependencies

### 2.1 モジュール構成と責務

| 層 | パス | 責務 |
|---|---|---|
| エントリ | `lib/main.dart`, `lib/app.dart` | 起動時復旧→`HealthService.configure()`→`runApp`。Provider 組み立てと M3 テーマ(seed=amber, light) |
| 定数 | `lib/constants/` | `game_constants`(数値)、`companion_stages`(段階・`TownStats`)、`achievements`、`feed_item_definitions` |
| ドメイン | `lib/domain/` | `energy_calculator`、`companion_logic`(容量・係数・愛着スコア・きげん)、`models/*` |
| 永続化 | `lib/data/local_storage.dart` | SharedPreferences ラッパーと 2 種のジャーナル(`EnergySyncCommit` / `InvestmentCommit`) |
| サービス | `lib/services/` | `HealthService`(歩数)、`SpeedMeasurementService`(GPS 速度) |
| 状態 | `lib/providers/` | `Settings` / `Energy` / `Companion` / `History` |
| 画面 | `lib/screens/`, `lib/widgets/` | Home / Companion / History / Settings / HowToPlay、`CompanionAvatar`(地球儀) |
| デモ | `lib/demo_stages_main.dart` | 発展段階の見た目確認専用エントリ(`flutter run -t lib/demo_stages_main.dart`) |

### 2.2 依存方向

- `EnergyProvider` → `LocalStorage`, `HealthService`, `SettingsProvider`。係数は `setCoefficientSupplier` で `CompanionProvider.effectiveCoefficient` を注入([app.dart:50](../../lib/app.dart))。
- `CompanionProvider` → `LocalStorage`, `EnergyProvider`, `SettingsProvider`。
- `HistoryProvider` → `LocalStorage`, `EnergyProvider`, `CompanionProvider`(全履歴クリア時に両者の `resetProgress` を呼ぶ)。
- ドメイン層(`domain/`, `constants/`)は Provider・画面に依存しない純粋ロジック。

### 2.3 外部依存(`pubspec.yaml`)

| パッケージ | バージョン | 用途 |
|---|---|---|
| Flutter / Dart SDK | `^3.12.1` | — |
| `health` | `^13.0.0` | iOS HealthKit。Android では Health Connect(過去日の副系) |
| `pedometer` | `^4.2.0` | Android 歩数センサー(主系) |
| `permission_handler` | `^12.0.3` | Android `ACTIVITY_RECOGNITION` |
| `geolocator` | `^13.0.0` | GPS 歩行速度計測 |
| `package_info_plus` | `^9.0.1` | 設定画面のバージョン表示 |
| `provider` | `^6.1.0` | 状態管理 |
| `shared_preferences` | `^2.3.0` | 永続化 |
| `flutter_launcher_icons` | `^0.14.3`(dev) | アイコン生成 |

アセット: `assets/earth/black_marble_2016.jpg`(出典は `assets/earth/CREDIT.txt`)。

### 2.4 プラットフォーム設定

| 項目 | 値 | 根拠 |
|---|---|---|
| Android applicationId / minSdk | `com.pedometertown.pedometer_town` / 26 | `android/app/build.gradle.kts:29,32` |
| Android 権限 | `health.READ_STEPS`, `ACTIVITY_RECOGNITION`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | `AndroidManifest.xml:3-8` |
| iOS 最低バージョン | 13.0 | `project.pbxproj`(`IPHONEOS_DEPLOYMENT_TARGET`) |
| iOS Info.plist | `NSHealthShareUsageDescription`, `NSLocationWhenInUseUsageDescription` | `ios/Runner/Info.plist` |

## 3. Data Model

### 3.1 モデル

| エンティティ | フィールド | 型 / 制約 | 根拠 |
|---|---|---|---|
| `PlayerSettings` | `weightKg` 30〜200(既定70)、`defaultSpeedKmh` 0.5〜15.0(既定5.0)、`energyCoefficient` 0.1〜5.0(既定1.0)、`companionName`(既定 `''`) | double×3 + String | `player_settings.dart`, `game_constants.dart` |
| `BatteryState` | `storedWh`, `capacityWh`(導出値) | double | `battery_state.dart` |
| `CompanionState` | `mealCount`, `boosterCount`, `toyCount`。`level = 合計` | int×3 | `companion_state.dart:18` |
| `DailyStepRecord` | `date`(`YYYY-MM-DD`), `totalSteps`, `totalEnergyWh`, `lastSyncedSteps`(表示用) | — | `daily_step_record.dart` |
| `FullBatteryEvent` | `number`, `date` | — | `full_battery_event.dart` |
| `AchievementEvent` | `id`, `date` | — | `achievement_event.dart` |
| `CompanionStageEvent` | `stageId`, `date` | — | `companion_stage_event.dart` |
| `FeedEvent` | `type`, `createdAt` | **非永続**(UI 演出用) | `feed_event.dart` |
| `EnergySyncCommit` | 電池・当日記録・累積発電量・ストック・満タン履歴・同期カーソル・最終同期日時・コミット済み日 | JSON `version: 1` | `local_storage.dart:20-93` |
| `InvestmentCommit` | 相棒状態・ストック・最終投入日時・実績履歴・段階履歴・祝福済み段階 | JSON `version: 1` | `local_storage.dart:96-161` |

### 3.2 SharedPreferences キー(`local_storage.dart:169-194`)

| 区分 | キー |
|---|---|
| 設定 | `player_weight_kg`, `player_default_speed_kmh`, `player_energy_coefficient`, `companion_name` |
| 蓄電池・進行 | `battery_stored_wh`(**容量は保存しない**)、`lifetime_energy_wh`, `pending_batteries` |
| 相棒 | `companion_meal_count`, `companion_booster_count`, `companion_toy_count`, `companion_last_fed_at`, `companion_celebrated_stage_ids` |
| 履歴 | `daily_record_{YYYY-MM-DD}`, `full_battery_events`, `companion_achievement_events`, `companion_stage_events` |
| 同期 | `last_synced_at`, `today_synced_date`, `today_synced_steps`(**同期カーソル**)、`backfill_floor_date`, `backfill_committed_dates` |
| Android | `health_android_baseline_date`, `health_android_baseline_steps` |
| ジャーナル | `energy_sync_journal`, `investment_journal` |
| 旧データ | `town_buildings`(移行専用) |

削除済み機能の残存キー(`companion_weather_fx_enabled`, `sparkle_events`)は読まれないだけで無害。

### 3.3 永続化・移行・復旧

- **永続化先**: SharedPreferences のみ。破損した JSON は読み込み時に空として扱う(日次記録・各イベント。`local_storage.dart:290-302,376-391`)。
- **旧町ビルド移行**: 相棒カウントのキーが 1 つも無く `town_buildings` がある場合、house→meal / powerPlant→booster / park→toy の個数へ変換(座標は破棄。`local_storage.dart:259-288`)。
- **ジャーナル復旧**: 保存対象一式を先にジャーナルへ書き、各キーへ反映後に削除。起動時(`main.dart:16-25`)と同期の冒頭で未完了ジャーナルを再適用する。再適用は同値上書きで冪等。**復号できないジャーナルは破棄**して以後の同期・投入を妨げない。
- **同期カーソル移行**: `today_synced_*` が未設定(旧版から更新直後)の場合のみ、当日の `DailyStepRecord.lastSyncedSteps` を起点に使う([energy_provider.dart:67-74](../../lib/providers/energy_provider.dart))。
- **祝福済み段階の移行**: `companion_celebrated_stage_ids` が未設定なら、現在の到達済み段階(`egg` 除く)を祝福済みとして保存(`companion_provider.dart:296-305`)。

## 4. Functional Spec

### 4.1 エネルギー計算

- **式**: `energyWh = steps × (weightKg / 70) × (speedKmh / 5) × coefficient`(`energy_calculator.dart:10-20`)。**1 日の上限なし**。
- **例**: 70kg/5km/h/1000 歩 → 1000 Wh。84kg/6km/h/5000 歩 → 7200 Wh(`energy_calculator_test.dart`)。
- 実効係数 = 設定係数 × 1.1^`toyCount`(`companion_logic.dart:26-32`)。実効容量 = 10,000 + 2,000×`boosterCount` Wh(`companion_logic.dart:17-23`)。

### 4.2 蓄電池

- 初期 蓄積 0 / 容量 10,000 Wh。加算で `total ≥ capacity` なら `floor(total/capacity)` 個が満タンとなり剰余を残す(`battery_state.dart:17-28`)。満タン分は `pendingBatteries`(ストック)に加算。
- `consumeEnergy` は不足時 `success=false` で状態不変。
- 容量は `CompanionState` から都度導出し保存しない。

### 4.3 歩数同期

**トリガ**: ホーム画面の初回表示、アプリのフォアグラウンド復帰(`resumed`)、「同期」ボタン。多重実行は `_isSyncing` で抑止([home_screen.dart:37-63](../../lib/screens/home_screen.dart))。

**`EnergyProvider.syncStepsFromHealth` の手順**([energy_provider.dart:83-138](../../lib/providers/energy_provider.dart)):
1. 未完了の同期ジャーナルを復旧し、メモリへ再読込。
2. 権限要求 → さかのぼり同期(§4.4)。
3. `HealthService.getTodaySteps()` で「今日これまでの累計」を取得。
4. `delta = 累計 − 同期カーソル`。`delta < 0`(センサーリセット)は累計をそのまま新規歩数とする。
5. 新規歩数をエネルギー化して蓄電池・累積発電量に加算し、満タン分をストックへ。`EnergySyncCommit` として一括確定(§3.3)。
6. `delta == 0` でも `lastSyncedAt` とカーソルは更新する。

**プラットフォーム別の取得**(`health_service.dart`):

| OS | 今日の歩数 | 過去日の歩数(`getStepsForDate`) |
|---|---|---|
| iOS | HealthKit `getTotalStepsInInterval(今日0:00, 現在)`。失敗/`null` は `HealthServiceException` | HealthKit の日別集計 |
| Android | 歩数センサー(`pedometer`、5 秒タイムアウト)をベースライン正規化。ベースラインは「**最終同期時点のセンサー値**」で同期のたびに前進 | **Health Connect(`health` パッケージ)をベストエフォートで問い合わせ**。非対応・未許可・失敗時は例外を投げず `null` |

- Android 正規化(`normalizeAndroidSteps`): 初回(ベースライン未設定)は増分 0 で現在値を起点にする。`raw < baseline`(端末再起動)は `raw` をそのまま増分。戻り値 = `今日の同期済みカーソル + 増分`(`health_service.dart:158-182`)。日またぎでも増分を取りこぼさず、前日までの加算分は二重計上しない(`health_service_test.dart` の通し同期シナリオ)。
- 権限(`requestPermissions`): Android は `ACTIVITY_RECOGNITION` が**必須**(拒否で例外)。Health Connect の `requestAuthorization` は**ベストエフォート**(失敗は無視)。iOS は HealthKit 歩数読み取りが必須。`configure()` の失敗は Android では無視、iOS では例外。
- 例外: プラグイン例外は `HealthServiceException` に変換し内部詳細を出さない。ホームは例外メッセージを SnackBar 表示、想定外エラーは「同期中にエラーが発生しました」。

### 4.4 さかのぼり同期(`_backfillMissedDays`)

- `lastSyncedAt` が無い(初回)場合は何もしない。下限日は `backfill_floor_date`(初回同期時の日付で**一度だけ固定**)。
- 対象は「昨日から新しい順に最大 30 日」のうち、下限日より後で `backfill_committed_dates` に無い日。加算は**古い日から**(満タン履歴を日付順にするため)。
- 取得は日ごとに並列、1 日の例外は `null`(スキップ→次回再試行)。`steps <= 0` の日も取得できていればコミット済みとして記録する。
- 換算には**現在の**体重・速度・係数を使う(当時の設定は保持しない)。
- 日ごとに `EnergySyncCommit`(`backfillCommittedDates` 付き)で確定。

### 4.5 電池の投入(`CompanionProvider.investBattery`)

- UI の「投入」は常に `meal` として計上(種類選択なし)。ストックが 0、または処理中(`_investing`)なら `false` を返し何もしない(`companion_provider.dart:121-125`)。
- `InvestmentCommit`(相棒・ストック−1・最終投入日時・実績・段階履歴・祝福済み段階)を計算して一括確定。書き込み失敗時は直ちにジャーナル再適用を試み、復旧不能なら再送出(画面は SnackBar「投入に失敗しました。もう一度お試しください。」)。
- 成功後に `FeedEvent` を積み、段階祝福・実績祝福・星の完成のキューを更新。
- `feedChosen(type)` はストック消費を伴わない個別保存 API で、**UI からは呼ばれない**(テスト・内部用)。`booster`(容量 +2,000 Wh)・`toy`(係数 ×1.1)の効果自体はドメインに存在するが UI から到達不能。

| type | 効果 | コスト定義 | UI から到達 |
|---|---|---|---|
| `meal` | 発展度 +1(数値効果なし) | `batteryCost: 1` | ○(唯一の経路) |
| `booster` | 容量 +2,000 Wh | `batteryCost: 2` | × |
| `toy` | 係数 ×1.1(累積) | `batteryCost: 1` | × |

> `FeedItemDefinition` の `displayName`(建材/配線キット/街灯アップ)・`batteryCost`・`icon` は旧町ビル名称が残ったもので、lib/test のどこからも参照されていない。仕様としては確定しない。

### 4.6 発展段階と「完成した星」

発展度 = `CompanionState.level`(投入回数の合計)。**20 段階**(`companion_stages.dart:23-44`):

| 発展度 | id | 名称 | 発展度 | id | 名称 |
|---|---|---|---|---|---|
| 0 | egg | 暗い星 | 21 | region | 広がる都市圏 |
| 1 | spark | 最初の灯り | 24 | corridor | 地方を結ぶ光の道 |
| 2 | flicker | 小さな灯り | 28 | continent | 大陸の光網 |
| 3 | hamlet | 集落の灯り | 32 | farshore | 大陸を越える灯り |
| 4 | village | 村の灯り | 36 | nightland | 夜の大陸が輝く |
| 6 | crossroads | 灯りの村道 | 40 | hemisphere | 半球が輝く |
| 8 | town | 小さな街 | 45 | radiant | 夜の星が浮かぶ |
| 10 | district | 街の光帯 | 50 | luminous | 満天の灯り |
| 12 | suburb | 郊外へ広がる灯り | 55 | star | 軌道から見た星(最終) |
| 15 | metro | 大きな街が灯る | | | |
| 18 | megacity | 大都市が輝く | | | |

- **最終段階(55)到達後**: 見た目の段階は固定。`earthCount = 1 + (level−55) ÷ 55`(整数除算)の「**完成した星**」が 55 回投入ごとに 1 個増える(`companion_stages.dart:141-153`)。
- **地球儀の灯りは周期でリセット**: `EarthLights._cycleLevel` が最終段階後の発展度を 55 周期内の進み具合に置換する。完成の瞬間(周期の境目)は満天、次の投入から真っ暗に戻って再び広がる(`companion_avatar.dart:244-252`)。
- `TownStats.buildingCount` は 19 点の折れ線補間で、55 以降は `145 + (level−55)×5`。地球儀の光点数は `buildingCount(cycleLevel) × 12`(上限 1,400)。`population` は UI 未表示。
- 段階の祝福は新規到達した段階(`egg` 除く)ごとに 1 回。投入で複数段階を越えれば複数回。

### 4.7 実績

`Achievements.all`(4 種。解除条件は `CompanionState.level` のみ。`achievements.dart:25-54`):

| id | タイトル | 条件 |
|---|---|---|
| `first_meal` | はじめての投入 | level ≥ 1 |
| `first_booster` | 電力が回りはじめた | level ≥ 5 |
| `first_toy` | 灯りが広がりはじめた | level ≥ 2 |
| `ten_feeds` | 夜の星が輝く | level ≥ 10 |

> id は旧仕様の名残で、タイトル・条件と対応しない(永続化済みの履歴との互換のため id は変えられない点に注意)。

### 4.8 きげん・愛着スコア(内部指標)

- きげん: 最終投入からの経過で `none`(未投入) / `happy`(≤24h) / `normal`(≤3 日) / `lonely`(それ以降)(`companion_logic.dart:43-52`)。**テキスト表示なし**。地球儀の薄いティントとしてのみ反映: happy=淡い暖色、lonely=淡い青、none=わずかに暗く、normal=なし(`companion_avatar.dart:408-415`)。
- 愛着スコア `= level×10 + floor(lifetimeEnergyWh/100)`。`CompanionProvider.bondScore` として算出のみで画面には出ない。

### 4.9 画面仕様

**ホーム**: 蓄電池(蓄積/容量 Wh、ストック個数)、今日の歩数、今日の発電量、**累積発電量**、最終同期時刻、「同期」ボタン。AppBar から履歴・星・設定へ遷移。

**星(CompanionScreen)** — 表示するもの:
- AppBar タイトル = 星の名前(空なら「わたしの星」)。
- 地球儀(`CompanionAvatar`): 自転、ドラッグで手動回転(指を離すと自動回転に戻る)、`mood` ティント。
- **現在の段階名** と **`発展度 {段階番号}/20`**(`companion_screen.dart:268-278`)。
- 累積発電量(小数 1 桁)。
- ストック個数と「投入」ボタン(ストック 0 または処理中は無効)。
- 最終段階未満: 「あと N 回投入すると灯りが広がる」＋進捗バー。最終段階以降: 「完成した星 N 個」＋次の星までの残り回数と進捗バー。
- 演出: 投入時に触覚＋SnackBar「電力を投入した(発展度 +1)」。祝福ダイアログ(段階到達「灯りが広がった」→星の完成「星が完成した！」(紙吹雪＋強い触覚)→実績「実績解除！」の順)。

**履歴**: 日次の歩数・発電量の一覧とグラフ(無期限保持)。1 日削除(今日の記録なら表示も空に)。全クリアは確認ダイアログ付きで、**星の発展状況(発展度・蓄電池・累積発電量・ストック)も初期化**する。

**設定**: 体重・歩行速度(各 スライダー＋数値入力)、発電変換係数、星の名前、GPS 歩行速度計測(30 秒、有効サンプル=0.5km/h 以上の平均、結果を既定速度へ反映)、保存、遊び方、`バージョン {version}+{build}`(`PackageInfo.fromPlatform()`。取得失敗時は行を出さない)。保存ボタン押下時は各入力欄の現在値を必ず検証・クランプして保存する(不正文字列は直前の値へ戻す)。

**遊び方**: 基本の流れ / 発電の仕組み / 電力の投入 / 発展度と星の成長(段階名・発展度の数値表示、最終段階後の「完成した星」と灯りのリセットを説明) / 画面の見方 / ヒント。

### 4.10 全履歴クリア(`HistoryProvider.clearHistory`)

日次記録を全削除 → `CompanionProvider.resetProgress()`(発展度 0) → `EnergyProvider.resetProgress()`(蓄電池・累積発電量・ストック 0)。**この順序が必須**(容量は相棒状態から導出)。**同期カーソル・さかのぼりコミット済み日・基準日には触れない**(再同期での二重加算を防ぐ)。祝福済み段階・実績履歴・段階履歴・最終投入日時は**リセットされない**(`companion_provider.dart:290-294`)。

### 4.11 Provider 公開 API

| Provider | 主な公開 API |
|---|---|
| `SettingsProvider` | `updateWeight` / `updateSpeed` / `updateCoefficient`(範囲外は `ArgumentError`)、`updateCompanionName`(trim) |
| `EnergyProvider` | `syncStepsFromHealth`, `applyBatteryState`, `refreshDisplay`, `resetProgress`, `setCoefficientSupplier`、`battery` / `today` / `lastSyncedAt` / `lifetimeEnergyWh` / `pendingBatteries` |
| `CompanionProvider` | `investBattery`, `feedChosen`, `resetProgress`, `mood`, `bondScore`, `effectiveCapacityWh`, `effectiveCoefficient`、祝福キュー(`pendingCelebrations` / `pendingStageCelebrations` / `pendingStarCompletions` / `pendingFeedEvent`)と各 `clear*` |
| `HistoryProvider` | `loadHistory`, `deleteHistoryRecord`, `clearHistory`(3 つのみ) |

## 5. Configuration & Operations

- **環境変数 / 設定ファイル**: アプリ自体は環境変数を使わない。設定は `pubspec.yaml`(`version: 1.0.0+1` が配布バージョンの唯一の管理場所)と §2.4 のプラットフォーム設定。
- **ビルド / 起動**: `flutter pub get` → `flutter run`。デモ: `flutter run -t lib/demo_stages_main.dart`(根拠: `README.md`, `doc/ai-implementation-spec.md`)。
- **検証コマンド**: `flutter analyze` / `flutter test`(`AGENTS.md`, `README.md`)。個別実行は `flutter test test/<対象>_test.dart`。
- **テスト一覧(`test/`)**: `energy_calculator` / `battery_state` / `companion_logic` / `local_storage` / `energy_provider` / `companion_provider` / `history_provider` / `health_service` / `companion_avatar` / `town_stats` / `home_and_settings_screen` / `settings_screen` / `max_level_behavior`(最終段階前後の画面表示) / `widget`。
- **ログ / 監視**: なし(外部送信なし。エラーは SnackBar とダイアログのみ)。
- **ストア公開**: `docs/store-release-checklist.md`, `docs/release-procedures.md`(本書の対象外)。

## 6. Discrepancies Resolved (Audit Log)

| # | 種別 | 差分の内容 | 既存ドキュメントの記述 | コードの実態 | 確定した正 | 根拠 |
|---|---|---|---|---|---|---|
| 1 | Conflict / 仕様 | 発展段階 | 8 段階、最終 17(`spec` §6, §4.9) | 20 段階、最終 55 | **Code** | `companion_stages.dart:23-44`, `town_stats_test.dart:13,19` |
| 2 | Conflict / 仕様 | 相棒画面の表示 | 発展度の数値は表示しない(`spec` 冒頭・§4.8、`requirements` §3.2) | 段階名＋`発展度 N/20` を表示 | **Code** | `companion_screen.dart:268-278`, `max_level_behavior_test.dart:83` |
| 3 | Code-only / 仕様 | 「完成した星」サイクル、灯りの周期リセット、星完成ダイアログ | 「最終段階の演出は光点の増加のみ」(`spec` §4.9)。完成サイクルの記述なし | 実装済み・テスト済み | **Code**(§4.6, 4.9 に記載) | `companion_stages.dart:141-153`, `companion_avatar.dart:244-252`, `companion_provider.dart:232-241` |
| 4 | Conflict / 仕様 | Android の `getStepsForDate` | 「常に `null`」(`spec` §3.4) | Health Connect を副系で問い合わせ | **Code**(二重計上リスクは Open Questions) | `health_service.dart:211-229`, `AndroidManifest.xml:3`, コミット `be5751c` |
| 5 | Conflict / 仕様 | アイテム表示名 | ごはん/げんきの素/おもちゃ | 建材/配線キット/街灯アップ(未使用値) | **識別子と効果のみ記載、表示名は注記** | `feed_item_definitions.dart:30-46` |
| 6 | Doc-only / 仕様 | 「なでる」 | 用語集・将来検討に記載 | 実装なし(LP からも削除済み `c6661e2`) | 正本から除外 | grep(`lib`/`test` に該当なし) |
| 7 | Doc-only / アーキ | `HistoryProvider` の「イベント読み出し」 | 記載あり | `loadHistory` / `deleteHistoryRecord` / `clearHistory` のみ | **Code** | `history_provider.dart` |
| 8 | Conflict / 仕様 | 実績 4 つ目のタイトル | 夜の地球が輝く | 夜の星が輝く | **Code** | `achievements.dart:47-53` |
| 9 | Conflict / 仕様 | 段階名・「地球」表記 | 暗い地球/大都市が輝く 等 | 暗い星/…(§4.6 の表) | **Code** | `companion_stages.dart` |
| 10 | Doc-only / 運用 | テスト一覧 | `max_level_behavior_test.dart` が無い | 存在 | **Code**(§5 に追記) | `test/` |
| 11 | Code-only / 仕様 | 星画面の祝福ダイアログ順序、触覚、SnackBar、ホームの累積発電量カード | 一部のみ記載 | 実装済み | **Code**(§4.9) | `companion_screen.dart:55-98,173-192`, `home_screen.dart:190-196` |
| 12 | Code-only / 運用 | Android/iOS の権限・最低 SDK、Health Connect 権限 | 技術スタックに権限 `ACTIVITY_RECOGNITION` のみ | `READ_STEPS`・位置情報権限・minSdk 26 | **Code**(§2.4) | `AndroidManifest.xml`, `build.gradle.kts` |

## 7. Open Questions

- [ ] **【要確認・高】Android の二重計上の可能性**: Health Connect が利用できる端末で数日アプリを開かなかった場合、①さかのぼり同期が昨日以前の日別歩数を加算し、②同時にセンサー正規化は前回同期以降の増分**全体**を「今日分」として加算する(`normalizeAndroidSteps` は日をまたいだ増分を今日に積む)。同じ歩数が 2 回計上され得る。`health_service_test.dart` と `energy_provider_test.dart:224` は両者の組合せをカバーしていない。意図(コミット `be5751c` は「日毎に記録される」としている)と実挙動を実機またはテストで確認し、必要なら別タスクで修正。
- [ ] **【要確認・高】iOS の HealthKit Capability**: `ios/` に `*.entitlements` が無く、`project.pbxproj` に HealthKit の記述が見当たらない。Info.plist の使用目的文言はあるが、実機で権限ダイアログが出て歩数が取れるかは本照合では未確認(Xcode の Signing & Capabilities と実機で確認)。
- [ ] **実績 id と内容の不一致**(`first_booster` = 5 回投入 等): 永続化済み履歴との互換のため変更不可か、移行して直すかの方針。
- [ ] **`FeedItemDefinition` の未使用値**(表示名・コスト・アイコン)と `feedChosen` / `booster` / `toy`: 将来 UI を復活させるのか、整理するのか(`requirements` §4「将来検討」に「UI 復活」あり)。
- [ ] **全履歴クリア後に残る状態**: 実績履歴・段階履歴・祝福済み段階・最終投入日時はリセットされない(§4.10)。意図した仕様か(再到達時に祝福が再表示されない)。
- [ ] **`flutter test` / `flutter analyze` の実行結果**: sandbox 制約で未実行。本書の挙動記述は読解ベース。

## 8. Out-of-scope / Known Gaps

- `docs/`(`store-listing.md`、`privacy.html`、`about.html`、リリース手順書 等)は照合対象外。アプリ実装(位置情報・Health データの扱い)とプライバシーポリシー記載の整合は未確認。
- `doc/archive/` は過去計画書のため対象外。
- 地球儀の描画詳細(`CompanionAvatar` の投影計算・光点生成・フレームレート)は構造のみ確認し、数値の詳細は未精査。
- 既存ドキュメントの修正は行っていない。上記 Audit Log の「Code」を選んだ項目(#1〜3, 7〜12)は `doc/*.md` 側に更新が必要で、**別タスク**として実施する。
