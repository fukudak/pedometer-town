# Refactoring Instructions

## Objective

第1ラウンドのリファクタリング（前回の `refactor-instructions.md` と `.claudelog/lessons-learned.md` を参照）はすべて完了し、現在のコードベースは 42 テスト全パス・`flutter analyze` クリーンの状態にある。本書はその**次フェーズ**として、残存する以下の技術的負債を解消する：

1. テストの非密閉性（`FakeHealthService` が本物のプラットフォームチャネルを呼び出す）
2. 町画面での `await` 抜け落ちによるサイレントエラー
3. ハードコードバージョン文字列
4. `LocalStorage.loadBatteryState()` の隠れた副作用（内部で `loadTownState()` を呼ぶ）

目標状態：テストが完全に環境非依存になり、ビルド失敗がユーザーに通知され、バージョン管理が一元化され、`LocalStorage` のメソッドが名前通りの動作をすること。数値定数・ゲームバランス・ストレージキー形式は一切変更しない。

---

## Project Understanding

- **Overview**: 完全オフラインの Flutter アプリ。実際の歩数（iOS: HealthKit / Android: ハードウェアセンサー直読み）を移動エネルギー(Wh)に変換し蓄電池に蓄積し、エネルギーで建物を建てて町を発展させる。仕様の正典: `doc/ai-implementation-spec.md`。
- **Key Workflows & Data Flow**:
  1. **Sync**: `HomeScreen._sync()` → `EnergyProvider.syncStepsFromHealth()` → `HealthService.requestPermissions()` + `HealthService.getTodaySteps()` → delta steps → `EnergyCalculator.calculateEnergyWh` + `clampDailyEnergy`（日次5000Wh上限） → `BatteryState.addEnergy` → `LocalStorage` 永続化。
  2. **Build**: `TownScreen` → `TownProvider.buildBuilding(type)` → `BatteryState.consumeEnergy(cost)` → `Building` 追加 → 容量再計算 → `EnergyProvider.applyBatteryState` → `TownState` 永続化。
  3. **Settings**: `SettingsScreen` → `SettingsProvider.updateWeight/updateSpeed`（範囲バリデーション付き）→ `PlayerSettings` 永続化。
- **Entry Points & Modules**:
  - `lib/main.dart` — `HealthService.configure()`, `SharedPreferences` 初期化, `runApp`。
  - `lib/app.dart` — `StatefulWidget` + `initState` でプロバイダを順番に生成 (`SettingsProvider` → `EnergyProvider` → `TownProvider`) + `setCoefficientSupplier` 呼び出し → `MultiProvider` + `MaterialApp`。
  - `lib/domain/` — 純粋ロジック (`EnergyCalculator`, `TownLogic`) + イミュータブルモデル。**テストの正典。**
  - `lib/data/local_storage.dart` — `SharedPreferences` ラッパー。キー名はスペック §4 で固定。
  - `lib/services/health_service.dart` — プラットフォーム分岐（iOS: HealthKit / Android: `pedometer` センサー直読み）。例外: `HealthServiceException`。
  - `lib/providers/` — `SettingsProvider`, `EnergyProvider`（インジェクタブルクロック・係数サプライヤー付き）, `TownProvider`。
  - `lib/screens/` — `HomeScreen`（`WidgetsBindingObserver` 実装）, `SettingsScreen`, `TownScreen`。
- **External Dependencies**:
  - `health ^13.0.0` (HealthKit / Health Connect)
  - `pedometer ^4.2.0` (Android ハードウェアセンサー)
  - `permission_handler ^12.0.3` (Android `ACTIVITY_RECOGNITION` 権限)
  - `provider ^6.1.0` (状態管理)
  - `shared_preferences ^2.3.0` (永続化)
  - ネットワーク・認証・課金なし（オフライン仕様 §0.3 による）

---

## Baseline Commands

リファクタリング前後・各フェーズ完了後に必ず実行し結果を記録すること：

```bash
flutter analyze        # 期待: "No issues found!"
flutter test           # 期待: 42 テスト全パス（フェーズが進むにつれ増加してよい）
```

`pubspec.yaml` の依存関係は変更しないこと（`flutter pub get` 不要）。
新しいビルドツール・lintツールを追加しないこと。

---

## Behaviors To Preserve

以下は絶対に変更・破壊してはならない：

- **エネルギー計算式と例示値**（仕様 §3.2）: `70kg, 5km/h, 1000歩 → 10.0 Wh`; `84kg, 6km/h, 5000歩 → 72.0 Wh`; 日次上限 5000 Wh。
- **蓄電池の初期値と動作**: 初期蓄積 0 Wh、初期容量 10000 Wh、オーバーフローはロスト、`consumeEnergy` は残量不足時 `success:false` + 状態変化なし。
- **建物コストと効果**: house 500 Wh / powerPlant 1000 Wh（容量 +2000 Wh）/ park 800 Wh（係数 ×1.1 累積乗算）。
- **SharedPreferences のキー名と JSON 形状**（仕様 §4）: `player_weight_kg`, `player_default_speed_kmh`, `player_difficulty`, `battery_stored_wh`, `town_buildings`, `daily_record_YYYY-MM-DD`。キーや JSON 形状の変更は必ず Stop-and-Ask。
- **`test/` 配下の全テスト**: 42 件すべて緑のまま・意図も変更しないこと。テストが仕様の正典。
- **`HealthService` 公開インターフェース**: `configure()`, `requestPermissions()`, `getTodaySteps()`, `HealthServiceException`。
- **HomeScreen の SnackBar エラー UX**: `HealthServiceException` 発生時にメッセージを `SnackBar` で表示。

---

## Non-Negotiables & Constraints (Boundaries)

実装モデルは以下の制約を厳格に遵守すること：

- 最初に `git status` を確認し、未コミットの既存変更と自身の変更を混ぜないこと。
- 編集前にベースラインの検証結果（`flutter analyze` + `flutter test` の出力）を `.claudelog/lessons-learned.md` に記録すること。
- 変更は小さく戻しやすい単位（1フェーズ = 1コミット）に分割すること。
- 無関係なコード整形や目的外の「ついでのリファクタリング」は一切行わないこと。
- 既存の数値定数（`lib/constants/` 以下）を一切変更しないこと。
- 💡【要求されていない自発的アクションの禁止】: 指示されていないファイルの作成（防御的 git バックアップ、未依頼ドキュメント等）は一切行わないこと。
- 各フェーズ完了後に必ずベースラインコマンドを実行すること。
- SharedPreferences のキー名・JSON 形状の変更は発見しても実施せず、即座に Stop-and-Ask に移行すること。

---

## Stop And Ask Conditions

以下の3条件のいずれかに直面した場合のみ作業を即座に中断して人間に指示を仰ぐこと。それ以外は自律的に進行せよ：

1. **破壊的または取り返しのつかない操作**が必要になった場合（SharedPreferences キー変更・JSON 形状変更など、既存インストールデータを破壊する操作）。
2. **リファクタリングのスコープ（目的）の真の変更**が必要であると判明した場合（例：N6・N9・N7/N8 の product decision が必要な変更に踏み込む場合）。
3. **人間本人にしか出せない情報**が不足している場合（Q1–Q3 の回答、未記載の仕様）。

---

## Memory System (Lessons Log)

`.claudelog/lessons-learned.md` に以下の形式で随時追記すること（上書き・削除禁止）：

```
## Phase N — <フェーズ名>
- <1行要約>: <発生したエラー or 成功パターン>
```

前回のセッションで蓄積された Phase 0〜3 の教訓が既にこのファイルに存在する。それを参照しながら進めること。

---

## Debt Map

**凡例 — Authority**: `IMPLEMENT` = このブリーフの範囲内で安全に実施してよい; `PROPOSE-ONLY` = 設計案を lessons log に書くが、人間の承認なしにコードを変更しないこと。

### N1 — FakeHealthService が requestPermissions をオーバーライドしていない（テスト非密閉）

| 項目 | 内容 |
|------|------|
| **ファイル/箇所** | `test/energy_provider_test.dart:14-27` |
| **問題** | `FakeHealthService` は `getTodaySteps` のみをオーバーライドし、`requestPermissions` は未オーバーライドのまま。`EnergyProvider.syncStepsFromHealth` は `requestPermissions()` を先に呼ぶため、テスト実行時に本物の `Health().requestAuthorization()` が起動し、macOS ホスト上のプラットフォームチャネル動作に依存している。 |
| **根拠** | `energy_provider_test.dart:21-27`（FakeHealthService の定義）+ `energy_provider.dart:51`（`requestPermissions()` の呼び出し順）|
| **影響範囲とリスク** | `health` パッケージの macOS 向け挙動変更または CI 環境変更で全 `syncStepsFromHealth` テストが突然失敗する可能性。現在たまたまパスしているのは環境依存。 |
| **改善案** | `FakeHealthService` に `@override Future<void> requestPermissions() async {}` を追加（常に成功する no-op）。「権限拒否」シナリオは `permissionError` フィールドを追加して `requestPermissions` 内で throw する形で表現する。 |
| **検証方法** | `flutter test` → 42 件（または追加テスト分を含む）全パス。環境非依存の確認として、`Health()` の mock が不要になることを確認。 |
| **Authority** | **IMPLEMENT** |

---

### N2 — TownScreen の buildBuilding が await されていない（サイレントエラー）

| 項目 | 内容 |
|------|------|
| **ファイル/箇所** | `lib/screens/town_screen.dart:47` |
| **問題** | `onPressed: canBuild ? () => townProvider.buildBuilding(type) : null` — `buildBuilding` は `Future<bool>` を返すが、コールバック内で await も結果チェックもしていない。ストレージ書き込み失敗・`consumeEnergy` の `success:false` 応答がユーザーに通知されない。 |
| **根拠** | `town_screen.dart:47`（非同期呼び出し）+ `town_provider.dart:40-58`（`Future<bool>` を返す `buildBuilding`） |
| **影響範囲とリスク** | ストレージエラーや予期せぬ残量不足（canBuild チェック通過後に残量が変わるレース）で UI が更新されないか不整合が生じ、ユーザーは理由を知れない。 |
| **改善案** | コールバックを async 化し、`await` した上で `result == false` または例外時に `SnackBar` を表示する。`TownScreen` を `StatefulWidget` 化して `context.mounted` チェックを行う。 |
| **検証方法** | `flutter analyze` クリーン（`unawaited_futures` lint が出ないことを確認）。`flutter test` 42 件全パス。 |
| **Authority** | **IMPLEMENT** |

---

### N3 — バージョン文字列がハードコード（リリースごとに手動修正が必要）

| 項目 | 内容 |
|------|------|
| **ファイル/箇所** | `lib/screens/settings_screen.dart:75` |
| **問題** | `'バージョン 0.9'` がリテラル文字列。`pubspec.yaml` の `version: 1.0.0+1` と乖離しており、リリースのたびに手動で合わせる必要がある。 |
| **根拠** | `settings_screen.dart:75`（リテラル）+ `pubspec.yaml:19`（バージョン定義） |
| **影響範囲とリスク** | 次バージョンリリース時に `settings_screen.dart` の更新を忘れるとバージョン表示が古いまま。`pubspec.yaml` との乖離が拡大する。 |
| **改善案** | `lib/constants/game_constants.dart` に `static const String appVersion = '0.9';` を追加する。`settings_screen.dart` で `'バージョン ${GameConstants.appVersion}'` に変更する。将来 `package_info_plus` で動的取得に移行する場合も、この 1 箇所の変更で済む。 |
| **検証方法** | `flutter analyze` クリーン。`flutter test` 全パス。`grep -rn "'バージョン 0.9'" lib/` で直接リテラルが残っていないことを確認。 |
| **Authority** | **IMPLEMENT** |

---

### N4 — setCoefficientSupplier による不完全な初期化（設計上の暗黙的順序依存）

| 項目 | 内容 |
|------|------|
| **ファイル/箇所** | `lib/app.dart:36-44`, `lib/providers/energy_provider.dart:36-38` |
| **問題** | `app.dart:initState` で `EnergyProvider` を生成 → `TownProvider` を生成 → `setCoefficientSupplier` 呼び出しという3ステップの順序が暗黙的な契約になっている。`setCoefficientSupplier` を呼び忘れた場合でも、`GameConstants.energyCoefficient`（デフォルト）が使われ、公園効果が無音でスキップされる。 |
| **根拠** | `app.dart:36-44`（生成順序）+ `energy_provider.dart:30-31`（コンストラクタのデフォルト値）|
| **影響範囲とリスク** | 今のコードでは同期 `initState` 内で連続して呼ばれるため安全。将来プロバイダ生成を移動・分割した際に公園効果が静かに無効化されるリスク。 |
| **改善案(A)** | `EnergyProvider.syncStepsFromHealth` に `assert` を追加し、公園が建設済みなのにデフォルト係数のまま同期が呼ばれた場合にデバッグビルドで早期検出する。**改善案(B)**: 現状のまま `app.dart` に初期化順序を明記したコメントを追加するのみ（最小変更）。 |
| **検証方法** | `flutter analyze` クリーン。`flutter test` 全パス。 |
| **Authority** | **PROPOSE-ONLY**（どちらの案を取るかプロダクト判断が必要） |

---

### N5 — LocalStorage.loadBatteryState() の隠れた loadTownState() 呼び出し

| 項目 | 内容 |
|------|------|
| **ファイル/箇所** | `lib/data/local_storage.dart:42-51` |
| **問題** | `loadBatteryState()` は内部で `loadTownState()` を暗黙的に呼ぶため、`SharedPreferences` の読み取りが2倍発生する。`EnergyProvider` コンストラクタでは `loadBatteryState()` と `TownProvider` 経由の `loadTownState()` が両方呼ばれ、起動時に `town_buildings` が3回読まれる。メソッド名が動作を正確に反映していない。 |
| **根拠** | `local_storage.dart:42-51`（`loadBatteryState` 内の `loadTownState` 呼び出し）+ `energy_provider.dart:32-34`（コンストラクタ）+ `town_provider.dart:18`（`loadTownState` 呼び出し） |
| **影響範囲とリスク** | 現状は性能上問題なし（SharedPreferences はメモリキャッシュ済み）。テスト・スタブ・将来の DI 導入の際に「なぜ battery ロードが town も読むのか」で混乱を招く。 |
| **改善案(A — 推奨)** | `loadBatteryState(List<Building> buildings)` にシグネチャを変更し、容量計算をメソッド内から除去。呼び出し元（`EnergyProvider` コンストラクタ・`refreshDisplay`）で `loadTownState().buildings` を先に取得してから渡す。**改善案(B)**: シグネチャはそのまま、メソッドに内部で `loadTownState()` を呼ぶことを示すコメントを追加するのみ。 |
| **検証方法** | `flutter test` 全パス（`local_storage_test.dart` の `BatteryState` グループが引き続きパスすることを重点確認）。Option A 実施後に失敗した場合は Option B にフォールバックして Stop-and-Ask。 |
| **Authority** | **IMPLEMENT（Option A）** |

---

### N6 — コールドスタート時に歩数が更新されない（UX ギャップ）

| 項目 | 内容 |
|------|------|
| **ファイル/箇所** | `lib/screens/home_screen.dart` |
| **問題** | `didChangeAppLifecycleState(resumed)` はアプリがバックグラウンドから復帰したときのみ発火する。コールドスタートでは「同期」ボタンを押すまで歩数が更新されない。 |
| **改善案** | `initState` 内の `addObserver` 直後に `WidgetsBinding.instance.addPostFrameCallback((_) => _sync(context))` を追加する。 |
| **Authority** | **PROPOSE-ONLY** — Q1 の回答待ち（初回起動で権限ダイアログを即表示することへの是非） |

---

### N7 — PlayerSettings.difficulty フィールドが未使用（Phase 4 待ちの死にコード）

| 項目 | 内容 |
|------|------|
| **ファイル/箇所** | `lib/domain/models/player_settings.dart:11`, `lib/data/local_storage.dart:27-38`, `lib/constants/game_constants.dart:25` |
| **問題** | `difficulty` フィールドは保存・読み込み・バリデーションされるが、どのロジックにも渡されない。`GameConstants.defaultDifficulty = 'normal'` も同様。仕様 §10 は Phase 4 として将来実装予定と明記。 |
| **Authority** | **PROPOSE-ONLY** — Q3 の回答待ち（Phase 4 まで保持 or 今すぐ除去） |

---

### N8 — Building.level フィールドが未使用（MVPのデッドフィールド）

| 項目 | 内容 |
|------|------|
| **ファイル/箇所** | `lib/domain/models/building.dart:5`, `toJson`, `fromJson` |
| **問題** | `level` は常に 1 で保存・復元されるが、`TownLogic` も `BuildingDefinitions` も参照しない。仕様 §4.4 で「MVPはアップグレードなし」と明記。 |
| **Authority** | **PROPOSE-ONLY** — Q3 の回答待ち。除去する場合 JSON から `"level"` キーが消えるが既存データは互換（`fromJson` は余剰キーを無視するため）。 |

---

### N9 — 古い日次記録が永遠に蓄積（ストレージリーク）

| 項目 | 内容 |
|------|------|
| **ファイル/箇所** | `lib/data/local_storage.dart` |
| **問題** | `daily_record_YYYY-MM-DD` キーが無限に増える。削除・上書き・TTL の仕組みがない。 |
| **改善案** | `pruneOldDailyRecords({int keepDays = 30})` を `LocalStorage` に追加し、日付ロールオーバー時（`EnergyProvider.syncStepsFromHealth` 内）に呼ぶ。 |
| **Authority** | **PROPOSE-ONLY** — Q2 の回答待ち（保存期間の定義） |

---

### N10 — main() の healthService.configure() が未ガード（クラッシュリスク）

| 項目 | 内容 |
|------|------|
| **ファイル/箇所** | `lib/main.dart:11` |
| **問題** | `await healthService.configure()` が例外を投げると `runApp` 前にアプリがクラッシュする。前回の `refactor-instructions.md` (D7) でも `PROPOSE-ONLY` として未解決のまま残っている。 |
| **改善案** | `try { await healthService.configure(); } catch (_) { /* 続行。同期時に HealthServiceException として処理される */ }` |
| **Authority** | **PROPOSE-ONLY** — 仕様 §7 の範囲外。仕様に明記されたら実施。 |

---

## Implementation Phases

各フェーズは完了次第 `flutter analyze` + `flutter test` を実行し、全パスを確認してコミットすること。コミットメッセージは日本語で `test:` / `refactor:` / `fix:` プレフィックスを付けること。

### Phase 0 — ベースライン記録（コード変更なし）

1. `git status` を実行し、未コミット変更を確認・記録する。
2. `flutter analyze` と `flutter test` を実行し、出力全体を `.claudelog/lessons-learned.md` に追記する。
   - 期待値: analyze クリーン、テスト 42 件全パス。
3. 期待値と異なる場合は即座に Stop-and-Ask。

### Phase 1 — テスト密閉化（N1）

**目標**: `FakeHealthService` が macOS ホストの HealthKit に触れないようにする。

1. `test/energy_provider_test.dart` の `FakeHealthService` クラスに追加:
   ```dart
   Object? permissionError;

   @override
   Future<void> requestPermissions() async {
     if (permissionError != null) throw permissionError!;
   }
   ```
2. 既存の `error` フィールドは `getTodaySteps` の失敗専用のまま維持する。
3. `flutter test` を実行し、42 件全パス（FakeHealthService の動作変更前後で同じ結果になることを確認）。
4. コミット: `test: FakeHealthService に requestPermissions の no-op オーバーライドを追加`

### Phase 2 — バージョン文字列の一元管理（N3）

**目標**: バージョン文字列を `GameConstants` に集約し、`settings_screen.dart` のリテラルを除去する。

1. `lib/constants/game_constants.dart` に追加:
   ```dart
   static const String appVersion = '0.9';
   ```
2. `lib/screens/settings_screen.dart:75` を変更:
   ```dart
   // 変更前
   'バージョン 0.9',
   // 変更後
   'バージョン ${GameConstants.appVersion}',
   ```
3. `flutter analyze` クリーン、`flutter test` 42 件全パス。
4. `grep -rn "'バージョン 0.9'" lib/` で直接リテラルが残っていないことを確認。
5. コミット: `refactor: バージョン文字列を GameConstants.appVersion に集約`

### Phase 3 — TownScreen のサイレントエラー修正（N2）

**目標**: `buildBuilding` の失敗がユーザーに通知されるようにする。

1. `lib/screens/town_screen.dart` を `StatefulWidget` に変換する（`context.mounted` チェックのため）。
2. `onPressed` コールバックを変更:
   ```dart
   onPressed: canBuild
       ? () async {
           final ok = await townProvider.buildBuilding(type);
           if (!context.mounted) return;
           if (!ok) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('エネルギーが不足しています')),
             );
           }
         }
       : null,
   ```
3. `flutter analyze` クリーン（`unawaited_futures` lint が出ないことを確認）、`flutter test` 42 件全パス。
4. コミット: `fix: 建設失敗時にエラーをユーザーに通知する`

### Phase 4 — LocalStorage.loadBatteryState の依存を明示化（N5）

**目標**: `loadBatteryState()` が内部で `loadTownState()` を呼ばないようにし、呼び出しコストを呼び出し元で制御できるようにする。

1. `lib/data/local_storage.dart` の `loadBatteryState` シグネチャを変更:
   ```dart
   BatteryState loadBatteryState(List<Building> buildings) {
     return BatteryState(
       storedWh: _prefs.getDouble(_keyBatteryStored) ??
           GameConstants.initialBatteryStoredWh,
       capacityWh: TownLogic.effectiveCapacity(
         GameConstants.initialBatteryCapacityWh,
         buildings,
       ),
     );
   }
   ```
2. `lib/providers/energy_provider.dart` のコンストラクタ initializer list を変更:
   ```dart
   // 変更前
   _battery = _storage.loadBatteryState(),
   // 変更後
   _battery = _storage.loadBatteryState(_storage.loadTownState().buildings),
   ```
3. `lib/providers/energy_provider.dart` の `refreshDisplay()` を変更:
   ```dart
   void refreshDisplay() {
     final town = _storage.loadTownState();
     _battery = _storage.loadBatteryState(town.buildings);
     _today = _storage.loadDailyStepRecord(_dateKey(_now()));
     notifyListeners();
   }
   ```
4. `test/local_storage_test.dart` の `loadBatteryState` 呼び出し箇所を新シグネチャに合わせて更新:
   ```dart
   // 例: buildings なし
   final battery = storage.loadBatteryState(const []);
   // 例: 発電所あり
   final battery = storage.loadBatteryState(const [Building(type: BuildingType.powerPlant)]);
   ```
5. `flutter test` を実行し、42 件全パス。失敗した場合は Option B（コメント追加のみ）に切り替えて Stop-and-Ask。
6. コミット: `refactor: LocalStorage.loadBatteryState の buildings 依存を呼び出し元で明示化`

### Phase 5 — PROPOSE-ONLY 事項の設計案作成（コード変更なし）

`.claudelog/lessons-learned.md` の `## Phase 5 — 提案事項` セクションに以下を追記する：

- **N4（setCoefficientSupplier の契約）**: `app.dart` への初期化順序コメント追加案と、`assert` による契約明示案を文書化する。
- **N6（コールドスタート同期）**: Q1 が承認された場合の変更箇所（`initState` の `addPostFrameCallback` 追加と `widget_test.dart` の修正案）を記載する。
- **N7/N8（デッドフィールド）**: Q3 が「今すぐ削除」となった場合の変更箇所と JSON 互換性の影響分析を記載する。
- **N9（日次記録クリーンアップ）**: Q2 が確定した場合の `pruneOldDailyRecords` 実装案と呼び出しタイミングを記載する。
- **N10（main の未ガード）**: `try-catch` ラップ案と degraded mode の振る舞いを記載する。

---

## Verification Requirements

### 各フェーズ完了時

- `flutter analyze` → `"No issues found!"`
- `flutter test` → 全テスト通過（テスト数 ≥ 42）

### 全フェーズ完了時（追加確認）

- エネルギー計算の検証: `flutter test test/energy_calculator_test.dart` → 7 件全パス（10.0 Wh / 72.0 Wh のケースを含む）。
- ストレージの検証: `flutter test test/local_storage_test.dart` → 全パス（Phase 4 実施後は `loadBatteryState` の新シグネチャで呼ぶテストが全パスすること）。
- `grep -rn "FakeHealthService" test/` → `requestPermissions` のオーバーライドが存在すること。
- `grep -rn "'バージョン 0.9'" lib/` → 結果が 0 件（リテラルが除去済み）であること。
- `grep -rn "unawaited" lib/screens/town_screen.dart` → 結果が 0 件であること。

---

## Out-of-scope Items

以下は今回のリファクタリング対象外とする。発見しても変更せず、最大でも提案として lessons log に記載するにとどめること：

- `lib/constants/game_constants.dart` と `building_definitions.dart` の数値調整（ゲームバランス変更は別途要承認）。
- Phase 3/4 の機能（日次履歴 UI・7日連続ボーナス・難易度切替 UI・GPS速度取得）の実装。
- `android/` と `ios/` 配下のネイティブ設定（AndroidManifest.xml・Info.plist・Podfile・build.gradle.kts）。
- `pubspec.yaml` の依存バージョン変更。
- `doc/` 配下のすべてのドキュメント（読み取り専用参照のみ）。
- Riverpod / Bloc への移行、ネットワーク・認証・課金の追加（仕様 §0.3 禁止事項）。
- `doc/設計書.md`（旧React版。現在は `doc/ai-implementation-spec.md` が正典）。
- `test/widget_test.dart` の `HealthService()` 実インスタンス問題（スコープを超えるウィジェットテスト基盤の変更になるため、今回は対象外）。

---

## Reporting Format

フェーズ完了時、または中断・Stop-and-Ask 時に以下の形式で報告すること：

```
## 報告

### 最後に実行したコマンドと結果
<flutter analyze の出力>
<flutter test の出力（テスト数・パス/失敗）>

### git status --short
<出力>

### コミット一覧（新規分）
- <コミット SHA 7桁> <コミットメッセージ>
- ...

### フェーズ状況
- Phase 0: [完了 / 未着手]
- Phase 1: [完了 / 未着手 / 中断]
- Phase 2: [完了 / 未着手 / 中断]
- Phase 3: [完了 / 未着手 / 中断]
- Phase 4: [完了 / 未着手 / 中断（Option B フォールバック理由を記載）]
- Phase 5: [完了 / 未着手]

### ブロック中の Stop-and-Ask（あれば）
<具体的な判断内容と必要な情報を記載>

### .claudelog/lessons-learned.md 追記内容（Phase 0 以降分）
<追記した全内容をここにコピー>
```
