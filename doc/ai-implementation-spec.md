# 万歩計タウン AI実装仕様書

**バージョン**: 1.0  
**日付**: 2026-06-15  
**対象**: Phase 1〜2（MVP）  
**前提ドキュメント**: `requirements.md`, `tech-stack.md`, `implementation-plan.md`

> 本書は `設計書.md`（React版・v0.1）を **Flutter版に置き換える** 正式仕様である。  
> AIエージェントは本書とユニットテストを唯一の実装基準とすること。

---

## 0. AIへの指示（必読）

### 0.1 ゴール

Flutter アプリ「万歩計タウン」を **完全オフライン** で実装する。  
スマホの歩数から移動エネルギーを計算し蓄電池に蓄積し、エネルギーで建物を建てて町を発展させる。

### 0.2 実装順序

1. `pubspec.yaml` 依存関係を本書どおりに設定
2. `lib/domain/` の純粋ロジックを実装し **`flutter test` を全パス** させる
3. `lib/data/` 永続化層を実装
4. `lib/services/` Health 連携を実装
5. `lib/providers/` + `lib/screens/` UI を実装
6. Phase 2（建物）まで本書 §6 を実装

### 0.3 禁止事項

- オンライン通信・Firebase・バックエンド導入
- Riverpod / Bloc への移行（MVP は Provider のみ）
- マップ表示・リッチアニメーション
- 本書にない数値の独自変更（調整が必要なら定数ファイルのみ変更）

### 0.4 完了判定

- [ ] `flutter test` 全パス
- [ ] Android / iOS で歩数権限リクエストが動作
- [ ] 体重・蓄電池・建物データが SharedPreferences に永続化
- [ ] アプリ再起動後もデータが復元される

---

## 1. 技術スタック（確定）

| 項目 | 技術 | バージョン目安 |
|------|------|----------------|
| フレームワーク | Flutter + Dart | SDK ^3.5.0 |
| 健康データ | `health` | ^11.0.0 |
| 状態管理 | `provider` | ^6.1.0 |
| ローカル保存 | `shared_preferences` | ^2.3.0 |
| UI | Material Design 3 | — |

---

## 2. ディレクトリ構成

```
lib/
├── main.dart
├── app.dart                    # MaterialApp + MultiProvider
├── constants/
│   └── game_constants.dart     # 数値定数（本書 §3）
├── domain/
│   ├── models/
│   │   ├── player_settings.dart
│   │   ├── battery_state.dart
│   │   ├── building.dart
│   │   └── town_state.dart
│   ├── energy_calculator.dart  # 純粋関数（テスト対象）
│   └── town_logic.dart         # 建設・効果計算（テスト対象）
├── data/
│   └── local_storage.dart      # SharedPreferences ラッパー
├── services/
│   └── health_service.dart     # health パッケージラッパー
├── providers/
│   ├── settings_provider.dart
│   ├── energy_provider.dart
│   └── town_provider.dart
└── screens/
    ├── home_screen.dart        # 蓄電池 + 今日の歩数
    ├── settings_screen.dart    # 体重設定
    └── town_screen.dart        # 建物リスト（Phase 2）

test/
├── energy_calculator_test.dart
├── battery_state_test.dart
├── town_logic_test.dart
└── local_storage_test.dart     # mock SharedPreferences
```

---

## 3. 数値設計（MVP確定値）

### 3.1 難易度係数

MVP では **難易度1種類（normal）のみ**。UI切替は Phase 4。

| 難易度 | 係数 | 備考 |
|--------|------|------|
| normal | `0.01` | デフォルト |

定数: `GameConstants.energyCoefficient = 0.01`

### 3.2 移動エネルギー計算

```
energyWh = steps × (weightKg / 70) × (speedKmh / 5) × coefficient
```

| パラメータ | 型 | 制約 | デフォルト |
|------------|-----|------|------------|
| steps | int | ≥ 0 | — |
| weightKg | double | 30〜200 | 70 |
| speedKmh | double | 0.5〜15.0 | 5.0 |
| coefficient | double | — | 0.01 |

**1日のエネルギー上限**: `5000 Wh`（超過分は切り捨て、既存蓄積には影響しない）

**計算例**（テストと一致させること）:
- 70kg, 5km/h, 1000歩 → `1000 × 1.0 × 1.0 × 0.01 = 10.0 Wh`
- 84kg, 6km/h, 5000歩 → `5000 × 1.2 × 1.2 × 0.01 = 72.0 Wh`

### 3.3 蓄電池

| 項目 | 値 |
|------|-----|
| 初期容量 | 10,000 Wh |
| 初期蓄積 | 0 Wh |
| 溢れ | 超過分ロスト（警告なし・MVP） |

建物効果による容量増加は §6.3 参照。

### 3.4 歩数同期

- Health から **今日（端末ローカル日付 0:00〜現在）** の歩数を取得
- 前回同期時の歩数との差分 `deltaSteps` を計算
- `deltaSteps` 分だけエネルギーを加算（1日上限適用）
- 同期時刻・当日累計歩数・当日累計エネルギーを永続化

速度が Health から取得できない場合は `PlayerSettings.defaultSpeedKmh`（5.0）を使用。

---

## 4. データモデル

### 4.1 PlayerSettings

```dart
class PlayerSettings {
  final double weightKg;       // 30.0〜200.0
  final double defaultSpeedKmh; // 0.5〜15.0, default 5.0
  final String difficulty;     // MVP: 'normal' のみ
}
```

**SharedPreferences キー**:
- `player_weight_kg` (double)
- `player_default_speed_kmh` (double)
- `player_difficulty` (String)

### 4.2 BatteryState

```dart
class BatteryState {
  final double storedWh;      // 現在蓄積
  final double capacityWh;    // 最大容量（建物効果込み）
}
```

- `addEnergy(amount)`: `storedWh = min(storedWh + amount, capacityWh)`
- `consumeEnergy(amount)`: 不足時は `false`、成功時 `true` かつ減算

**SharedPreferences キー**:
- `battery_stored_wh` (double)
- `battery_base_capacity_wh` (double) — 建物効果前のベース容量

### 4.3 DailyStepRecord（Phase 3 準備・Phase 1 から保存）

```dart
class DailyStepRecord {
  final String date;          // 'YYYY-MM-DD'
  final int totalSteps;
  final double totalEnergyWh;
  final int lastSyncedSteps;  // Health上の累計歩数
}
```

**SharedPreferences キー**: `daily_record_{YYYY-MM-DD}` (JSON)

### 4.4 Building / TownState（Phase 2）

```dart
enum BuildingType { house, powerPlant, park }

class Building {
  final BuildingType type;
  final int level;            // 1固定（MVPはアップグレードなし）
}

class TownState {
  final List<Building> buildings;
  final int townLevel;        // buildings.length に連動でも可
}
```

**SharedPreferences キー**: `town_buildings` (JSON array)

---

## 5. Phase 1 実装詳細

### 5.1 EnergyCalculator（純粋関数）

ファイル: `lib/domain/energy_calculator.dart`

```dart
class EnergyCalculator {
  /// 歩数差分から Wh を計算。結果は [GameConstants.dailyEnergyCapWh] でキャップ。
  static double calculateEnergyWh({
    required int steps,
    required double weightKg,
    required double speedKmh,
    double coefficient = GameConstants.energyCoefficient,
  });

  /// 当日既存エネルギー [alreadyEarnedTodayWh] を考慮し、
  /// 追加可能な Wh を返す（0以上）。
  static double clampDailyEnergy({
    required double newEnergyWh,
    required double alreadyEarnedTodayWh,
  });
}
```

### 5.2 HealthService

ファイル: `lib/services/health_service.dart`

**責務**:
1. `requestPermissions()` — `HealthDataType.STEPS` の読み取り権限
2. `getTodaySteps()` — 今日 0:00 から現在までの歩数合計
3. 権限拒否時は `HealthServiceException` を throw（UIでメッセージ表示）

**プラットフォーム**:
- iOS: HealthKit
- Android: Health Connect

`health` パッケージの `Health().configure()` を `main()` 前に呼ぶ。

### 5.3 LocalStorage

ファイル: `lib/data/local_storage.dart`

- 全モデルの save / load
- JSON シリアライズは `dart:convert`
- 初回起動時はデフォルト値を返す

### 5.4 Providers

| Provider | 状態 | 主要メソッド |
|----------|------|--------------|
| SettingsProvider | PlayerSettings | `updateWeight`, `updateSpeed` |
| EnergyProvider | BatteryState, DailyStepRecord | `syncStepsFromHealth`, `refreshDisplay` |
| TownProvider | TownState | `buildBuilding`（Phase 2） |

### 5.5 画面

#### HomeScreen
- 蓄電池: 現在値 / 容量（プログレスバー）
- 今日の歩数・今日獲得エネルギー
- 「同期」ボタン（Health から歩数取得）
- ナビ: 設定、町（Phase 2 以降有効）

#### SettingsScreen
- 体重入力（Slider 30〜200 または TextField）
- デフォルト速度（km/h、小数1桁）
- 保存ボタン → SharedPreferences

---

## 6. Phase 2 実装詳細（建物）

### 6.1 建物定義（MVP 3種）

| type | 表示名 | コスト(Wh) | 効果 |
|------|--------|------------|------|
| house | 住宅 | 500 | なし（人口フラグ・将来用） |
| powerPlant | 発電所 | 1,000 | 蓄電池容量 +2,000 Wh |
| park | 公園 | 800 | エネルギー係数 +10%（累積乗算） |

定数: `lib/constants/building_definitions.dart`

### 6.2 建設ルール

1. `BatteryState.storedWh >= cost` を確認
2. エネルギー消費 → 建物リストに追加
3. 効果を即時反映（容量再計算、係数再計算）
4. 永続化

同一タイプの建物は **複数建設可能**（MVP）。

### 6.3 効果計算

```dart
// lib/domain/town_logic.dart
static double effectiveCapacity(double baseCapacity, List<Building> buildings);
static double effectiveCoefficient(double baseCoef, List<Building> buildings);
```

- 発電所1棟につき `+2000 Wh`
- 公園1棟につき `×1.1`（2棟なら `×1.1×1.1`）

### 6.4 TownScreen

- 所持エネルギー表示
- 建物一覧（建設済み）
- 建設可能建物リスト + コスト + 「建設」ボタン
- 建設不可時はボタン disabled

---

## 7. エラーハンドリング

| 状況 | 対応 |
|------|------|
| Health 権限拒否 | SnackBar「歩数へのアクセスが必要です」+ 設定画面への案内 |
| Health データ取得失敗 | 前回値を維持、エラーメッセージ表示 |
| エネルギー不足で建設 | ボタン disabled（事前ガード） |
| 不正入力（体重範囲外） | バリデーションエラー、保存不可 |

---

## 8. テスト要件

### 8.1 ユニットテスト（必須・CI対象）

`test/` 配下のテストを **すべてパス** すること。  
テストが仕様の Source of Truth。実装と乖離した場合は **実装を修正** する。

| ファイル | 対象 |
|----------|------|
| `energy_calculator_test.dart` | 計算式・日次上限 |
| `battery_state_test.dart` | 加算・消費・容量上限 |
| `town_logic_test.dart` | 建物効果・建設コスト |
| `local_storage_test.dart` | シリアライズ往復 |

### 8.2 手動テストチェックリスト

- [ ] 初回起動 → 体重設定 → ホーム表示
- [ ] 同期ボタン → 歩数反映 → エネルギー増加
- [ ] アプリ kill → 再起動 → データ保持
- [ ] 建物建設 → エネルギー減少 → 効果反映
- [ ] 蓄電池満タン時に同期 → 溢れ分が加算されない

---

## 9. pubspec.yaml 最小構成

```yaml
name: pedometer_town
description: 万歩計タウン - 歩いて町を育てる
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: ^3.5.0

dependencies:
  flutter:
    sdk: flutter
  health: ^11.0.0
  provider: ^6.1.0
  shared_preferences: ^2.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

---

## 10. 将来フェーズ（参考・今回実装しない）

- Phase 3: 日次履歴UI、7日連続ボーナス、町レベル表示
- Phase 4: 難易度切替 UI、GPS 速度取得

---

## 11. 用語集

| 用語 | 意味 |
|------|------|
| Wh | ワット時。ゲーム内エネルギー単位 |
| 移動エネルギー | 歩数・体重・速度から算出されるゲーム資源 |
| 蓄電池 | エネルギーの貯蔵。上限あり |
| 同期 | Health API から歩数を取得し差分を反映する操作 |
