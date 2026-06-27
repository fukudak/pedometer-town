# 万歩計タウン 実装仕様書

**バージョン**: 2.0  
**日付**: 2026-06-27  
**前提ドキュメント**: `requirements.md`, `tech-stack.md`

> 本書は Flutter 版の正式仕様である。  
> **数値・挙動の正典は `lib/constants/`・`test/`・実装コード** を優先する。

---

## 0. 概要

完全オフラインの Flutter アプリ。歩数から移動エネルギー(Wh)を計算し蓄電池に蓄積する。蓄電池が満タンになるとストックされ、町画面で消費して建物が自動建設され、町が発展する。

### 画面構成

| 画面 | 役割 |
|------|------|
| HomeScreen | 蓄電池・今日の歩数/発電量・自動同期 |
| TownScreen | 発展段階の地平線ビュー・満タン蓄電池の消費・統計 |
| HistoryScreen | 日次記録・満タンイベント・ロケット発射・実績 |
| SettingsScreen | 体重・速度・発電係数・GPS 速度計測 |

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

アプリバージョン: `pubspec.yaml` の `version`（現在 `1.0.0+1`）

---

## 2. ディレクトリ構成

```
lib/
├── main.dart
├── app.dart
├── constants/
│   ├── game_constants.dart
│   ├── building_definitions.dart
│   ├── town_stages.dart
│   └── achievements.dart
├── domain/
│   ├── models/
│   │   ├── player_settings.dart
│   │   ├── battery_state.dart
│   │   ├── building.dart
│   │   ├── town_state.dart
│   │   ├── daily_step_record.dart
│   │   ├── full_battery_event.dart
│   │   ├── rocket_launch_event.dart
│   │   └── achievement_event.dart
│   ├── energy_calculator.dart
│   └── town_logic.dart
├── data/
│   └── local_storage.dart
├── services/
│   ├── health_service.dart
│   └── speed_measurement_service.dart
├── providers/
│   ├── settings_provider.dart
│   ├── energy_provider.dart
│   ├── town_provider.dart
│   └── history_provider.dart
└── screens/
    ├── home_screen.dart
    ├── town_screen.dart
    ├── history_screen.dart
    └── settings_screen.dart

test/
├── energy_calculator_test.dart
├── battery_state_test.dart
├── town_logic_test.dart
├── local_storage_test.dart
├── energy_provider_test.dart
├── town_provider_test.dart
├── history_provider_test.dart
├── health_service_test.dart
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

公園の効果は係数に累積乗算（1棟あたり ×1.1）。

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

容量は建物効果から導出（永続化しない）。発電所1棟あたり +2,000 Wh。

### 3.4 歩数同期

- **iOS**: HealthKit から今日（端末ローカル日付 0:00〜現在）の歩数合計
- **Android**: センサー累積値をベースライン正規化して今日分を算出
- 前回同期時の歩数との差分 `deltaSteps` をエネルギーに変換
- `deltaSteps < 0`（センサーリセット）は `totalSteps` を新規歩数として扱う
- ホーム画面表示時・フォアグラウンド復帰時に自動同期

---

## 4. データモデル

### 4.1 PlayerSettings

```dart
class PlayerSettings {
  final double weightKg;          // 30.0〜200.0
  final double defaultSpeedKmh;   // 0.5〜15.0
  final double energyCoefficient; // 0.1〜5.0
}
```

**SharedPreferences キー**:
- `player_weight_kg`
- `player_default_speed_kmh`
- `player_energy_coefficient`

### 4.2 BatteryState

```dart
class BatteryState {
  final double storedWh;
  final double capacityWh;  // 建物効果込み（導出値）
}
```

- `addEnergy(amount)`: 満タン到達時は折り返し、`batteriesFilled` を返す
- `consumeEnergy(amount)`: 不足時は失敗

**永続化キー**: `battery_stored_wh`（容量は永続化しない）

### 4.3 Building / TownState

```dart
enum BuildingType { house, powerPlant, park }

class Building {
  final BuildingType type;
  final int x, y;  // 5×5 グリッド座標（自動割当）
}

class TownState {
  final List<Building> buildings;
  int get townLevel => buildings.length;
}
```

**永続化キー**: `town_buildings` (JSON array)

### 4.4 イベント記録

| モデル | 用途 | キー |
|--------|------|------|
| DailyStepRecord | 日次歩数・発電量 | `daily_record_{YYYY-MM-DD}` |
| FullBatteryEvent | 蓄電池満タン回数 | `full_battery_events` |
| RocketLaunchEvent | ロケット発射 | `rocket_launch_events` |
| AchievementEvent | 実績解除 | `achievement_events` |

その他: `last_synced_at`, `lifetime_energy_wh`, `pending_batteries`, Android ベースライン

---

## 5. 建物

### 5.1 定義

| type | 表示名 | コスト(Wh) | 効果 | 人口 |
|------|--------|------------|------|------|
| house | 住宅 | 500 | なし | 4 |
| powerPlant | 発電所 | 1,000 | 蓄電池容量 +2,000 Wh | 1 |
| park | 公園 | 800 | 係数 ×1.1（累積乗算） | 0 |

> 建設コストはデータ定義として保持するが、現行ゲームプレイでは手動建設 UI はなく、満タン蓄電池消費時に建物が自動建設される。

### 5.2 自動建設フロー

1. 歩行でエネルギー蓄積 → 満タン到達で `pendingBatteries` 増加
2. 町画面で「使う」→ `EnergyProvider.useStockedBatteries()`
3. `TownProvider.advanceTown(count)` で空き座標に建物を自動配置
4. 建物種別は `buildings.length % 3` で house → powerPlant → park をローテーション
5. 容量再計算・実績チェック・ロケット発射記録

グリッド: 5×5（`GameConstants.townGridSize`）。満杯時は建設停止。

---

## 6. 町の発展段階

`TownStages.stages` に建物数しきい値で定義:

| 建物数 | 段階名 |
|--------|--------|
| 0 | 何もない地平線 |
| 1 | 豆電球がつく |
| 2 | 電灯がつく |
| 4 | 家の明かりが付く |
| 7 | 工場が稼働する |
| 10 | 街が広がる |
| 13 | 都市になる |
| 17 | ロケット建設する |

最終段階到達後、2棟ごとにロケット発射（`GameConstants.rocketLaunchInterval`）。

---

## 7. 実績

`lib/constants/achievements.dart` に定義（6種）:

- 最初の住宅 / 電力供給開始 / 緑のある暮らし
- 発展する町（10棟）
- 宇宙への第一歩 / 宇宙開発の常連（ロケット 1回 / 5回）

解除時は町画面で祝福ダイアログ表示。履歴画面でも確認可能。

---

## 8. Providers

| Provider | 状態 | 主要メソッド |
|----------|------|--------------|
| SettingsProvider | PlayerSettings | `updateWeight`, `updateSpeed`, `updateCoefficient` |
| EnergyProvider | BatteryState, DailyStepRecord, pendingBatteries | `syncStepsFromHealth`, `useStockedBatteries`, `refreshDisplay` |
| TownProvider | TownState, 実績キュー | `advanceTown`, `effectiveCapacity`, `effectiveCoefficient` |
| HistoryProvider | — | `loadHistory`, `deleteHistoryRecord`, イベント読み出し |

`EnergyProvider` は `TownProvider.effectiveCoefficient` を係数供給元として参照する。  
満タン時コールバックで `TownProvider.advanceTown` を呼ぶ（手動建設時）。

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
| `town_logic_test.dart` | 建物効果・グリッド判定 |
| `local_storage_test.dart` | シリアライズ・導出容量 |
| `energy_provider_test.dart` | 同期・係数・refreshDisplay |
| `town_provider_test.dart` | advanceTown・実績・ロケット |
| `history_provider_test.dart` | 履歴削除 |
| `health_service_test.dart` | Android 正規化 |
| `widget_test.dart` | アプリ起動 |

---

## 11. 用語集

| 用語 | 意味 |
|------|------|
| Wh | ワット時。ゲーム内エネルギー単位 |
| 移動エネルギー | 歩数・体重・速度から算出されるゲーム資源 |
| 蓄電池 | エネルギーの貯蔵。満タンでストックに変換 |
| 満タンストック | 蓄電池が満タンになった回数。町発展に消費 |
| 同期 | 歩数を取得し差分をエネルギーに反映する操作 |
| 文明スコア | 棟数×10 + 累積発電量/100 + ロケット発射×50 |
