# Refactoring Instructions

## Objective

第1・第2ラウンド（前回の `refactor-instructions.md` と `.claudelog/lessons-learned.md` の Round 1〜2 を参照）のリファクタリングは完了済みで、現在のコードベースは **53 テスト全パス・`flutter analyze` クリーン** の状態にある。Round 2 以降、GPS歩行速度計測、建物の座標配置・発展演出、履歴画面、Android歩数ロールオーバー修正、発電量バランス調整などの新機能が追加された。本書はその**第3ラウンド**として、これらの新機能領域に新たに見つかった技術的負債を解消する：

1. ドメイン層（`TownLogic`）が建物の座標 (x, y) をグリッド範囲外でも受理してしまう（境界値検証の欠落）
2. 履歴画面の `deleteHistoryRecord` 呼び出しが await されず失敗が握り潰される（建設失敗時と同種のサイレントエラー）
3. `HealthService` が `LocalStorage` を経由せず `SharedPreferences.getInstance()` を直接呼び出し、ストレージ責務が分散している
4. `EnergyProvider` が蓄電池・歩数・履歴・生涯統計の4責務を1クラスに抱えている
5. Round 2 で未解決のまま残った `main()` の `healthService.configure()` 未ガード

上記5項目はいずれも人間との確認の結果、**今回のラウンドで実施することが承認済み**（全て `IMPLEMENT` 権限）。目標状態：ドメイン層が自身の不変条件（座標範囲）を自律的に守り、UIから入力された値を信頼しなくても安全であること。履歴削除の失敗がサイレントに消えないこと。ストレージ責務が `LocalStorage` に一元化されていること。履歴管理が専用の `HistoryProvider` に分離されていること。`main()` がヘルスサービス初期化失敗時にクラッシュしないこと。数値定数・ゲームバランス・ストレージキー形式・既存の公開挙動は一切変更しない。

---

## Project Understanding

- **Overview**: 完全オフラインの Flutter アプリ。実際の歩数（iOS: HealthKit / Android: ハードウェアセンサー直読み）を移動エネルギー(Wh)に変換し蓄電池に蓄積し、エネルギーで建物を5x5の草原グリッド上に座標指定で建設して町を発展させる。仕様の正典: `doc/ai-implementation-spec.md`（ただし `dailyEnergyCapWh` 等の数値は Round 2 以降に変更されているため、**コード(`lib/constants/game_constants.dart`)とテストが最新の正典**であり、ドキュメントより優先する）。
- **Key Workflows & Data Flow**:
  1. **Sync**: `HomeScreen._sync()` → `EnergyProvider.syncStepsFromHealth()` → `HealthService.requestPermissions()` + `HealthService.getTodaySteps()`（Android はセンサー累積値をベースライン差分で正規化、再起動検出時は現在値をそのまま今日の歩数とする）→ delta steps → `EnergyCalculator.calculateEnergyWh` + `clampDailyEnergy`（日次10000Wh上限）→ `BatteryState.addEnergy` → `LocalStorage` 永続化（蓄電池・当日記録・最終同期時刻・生涯発電量）。
  2. **Build**: `TownScreen` → 建物種別選択（ボトムシート）→ グリッドタイルタップで座標指定 → `TownProvider.buildBuilding(type, x, y)` → `TownLogic.isOccupied` チェック → `BatteryState.consumeEnergy(cost)` → `Building(x, y)` 追加 → 容量再計算 → `EnergyProvider.applyBatteryState` → `TownState` 永続化。
  3. **History**: `HistoryScreen` → `EnergyProvider.loadHistory()`（全日次記録を新しい順）→ スワイプで個別削除（`deleteHistoryRecord`）/ 一括削除（`clearHistory`）。
  4. **Settings**: `SettingsScreen` → `SettingsProvider.updateWeight/updateSpeed/updateCoefficient`（範囲バリデーション付き）→ `PlayerSettings` 永続化。歩行速度は `SpeedMeasurementService`（GPS, 30秒平均計測）でも設定可能。
- **Entry Points & Modules**:
  - `lib/main.dart` — `HealthService.configure()` → `SharedPreferences` 初期化 → `runApp`。
  - `lib/app.dart` — `StatefulWidget` + `initState` でプロバイダを順番に生成 (`SettingsProvider` → `EnergyProvider` → `TownProvider`) + `setCoefficientSupplier` 呼び出し → `MultiProvider` + `MaterialApp`（Material 3 Expressive テーマ）。
  - `lib/domain/` — 純粋ロジック (`EnergyCalculator`, `TownLogic`) + イミュータブルモデル (`battery_state`, `building`, `daily_step_record`, `player_settings`, `town_state`)。**テストの正典。**
  - `lib/data/local_storage.dart` — `SharedPreferences` ラッパー。「全モデルの save / load」を担う設計意図（ファイル冒頭コメント）。
  - `lib/services/health_service.dart` — プラットフォーム分岐（iOS: HealthKit / Android: `pedometer` センサー直読み + 自前のベースライン正規化）。例外: `HealthServiceException`。
  - `lib/services/speed_measurement_service.dart` — GPS (`geolocator`) で歩行速度をサンプリングし平均を返す。例外: `SpeedMeasurementException`。
  - `lib/providers/` — `SettingsProvider`, `EnergyProvider`（インジェクタブルクロック・係数サプライヤー付き、蓄電池/歩数/履歴/生涯統計を保持）, `TownProvider`。
  - `lib/screens/` — `HomeScreen`（`WidgetsBindingObserver`）, `SettingsScreen`（GPS計測シート含む）, `TownScreen`（座標タップ建設・グリッドアニメーション）, `HistoryScreen`（スワイプ削除）。
  - `lib/constants/` — `game_constants.dart`（数値定数）, `building_definitions.dart`（建物コスト・効果・アイコン）, `town_stages.dart`（建物数に応じた発展段階表示）。
- **External Dependencies**:
  - `health ^13.0.0` (HealthKit / Health Connect)
  - `pedometer ^4.2.0` (Android ハードウェアセンサー)
  - `permission_handler ^12.0.3` (Android `ACTIVITY_RECOGNITION` 権限)
  - `geolocator` (GPS歩行速度計測、位置情報権限)
  - `provider ^6.1.0` (状態管理)
  - `shared_preferences ^2.3.0` (永続化)
  - ネットワーク・認証・課金なし（オフライン仕様 §0.3 による）

---

## Baseline Commands

リファクタリング前後・各フェーズ完了後に必ず実行し結果を記録すること：

```bash
flutter analyze        # 期待: "No issues found!"
flutter test            # 期待: 53 テスト全パス（フェーズが進むにつれ増加してよい）
```

`pubspec.yaml` の依存関係は変更しないこと（`flutter pub get` 不要）。
新しいビルドツール・lintツールを追加しないこと。

---

## Behaviors To Preserve

以下は絶対に変更・破壊してはならない：

- **エネルギー計算式と例示値**（`test/energy_calculator_test.dart` が正典）: `70kg, 5km/h, 1000歩 → 1000.0 Wh`; `84kg, 6km/h, 5000歩 → 7200.0 Wh`; 日次上限 `GameConstants.dailyEnergyCapWh`(10000.0 Wh)。
- **蓄電池の初期値と動作**: 初期蓄積 0 Wh、初期容量 10000 Wh（建物効果で加算、永続化はしない・建物リストから都度算出）、オーバーフローはロスト、`consumeEnergy` は残量不足時 `success:false` + 状態変化なし。
- **建物コストと効果**: house 500 Wh / powerPlant 1000 Wh（容量 +2000 Wh）/ park 800 Wh（係数 ×1.1 累積乗算）。グリッドは 5x5（`GameConstants.townGridSize`）。
- **建物の座標**: 1座標に1棟まで（`TownLogic.isOccupied`）。座標は建設時に確定し、JSON にも保存される。
- **Android歩数の正規化ロジック**（`HealthService.normalizeAndroidSteps`、`test/health_service_test.dart` が正典）: 日付が変わるとベースラインリセット、センサー値がベースラインより小さければ端末再起動と判定し現在値をそのまま今日の歩数とする。
- **SharedPreferences のキー名と JSON 形状**: `player_weight_kg`, `player_default_speed_kmh`, `player_energy_coefficient`, `battery_stored_wh`, `town_buildings`（`type`/`x`/`y`）, `daily_record_YYYY-MM-DD`, `last_synced_at`, `lifetime_energy_wh`, `health_android_baseline_date`, `health_android_baseline_steps`。キーや JSON 形状の変更は必ず Stop-and-Ask。
- **`test/` 配下の全テスト**: 53 件すべて緑のまま・意図も変更しないこと。テストが仕様の正典。
- **`HealthService` / `SpeedMeasurementService` の公開インターフェース**: `configure()`, `requestPermissions()`, `getTodaySteps()`, `normalizeAndroidSteps()`, `HealthServiceException` / `requestPermission()`, `measureAverageSpeed()`, `SpeedMeasurementException`。
- **HomeScreen / TownScreen の SnackBar エラー UX**: 同期失敗・建設失敗時にメッセージを `SnackBar` で表示する既存挙動。
- **履歴の無期限保持**: `loadAllDailyRecords()` は全件返す（7日プルーニングは「同期時の古いレコード削除」のみで、表示・取得自体は制限しない）。

---

## Non-Negotiables & Constraints (Boundaries)

実装モデルは以下の制約を厳格に遵守すること：

- 最初に `git status` を確認し、未コミットの既存変更と自身の変更を混ぜないこと。
- 編集前にベースラインの検証結果（`flutter analyze` + `flutter test` の出力）を `.claudelog/lessons-learned.md` に記録すること。
- 変更は小さく戻しやすい単位（1フェーズ = 1コミット）に分割すること。コミットメッセージは日本語で `test:` / `refactor:` / `fix:` プレフィックスを付けること。
- 無関係なコード整形や目的外の「ついでのリファクタリング」は一切行わないこと。
- 既存の数値定数（`lib/constants/` 以下）を一切変更しないこと。
- 💡【要求されていない自発的アクションの禁止】: 指示されていないファイルの作成（防御的 git バックアップ、未依頼ドキュメント等）は一切行わないこと。
- 各フェーズ完了後に必ずベースラインコマンドを実行すること。
- SharedPreferences のキー名・JSON 形状の変更は発見しても実施せず、即座に Stop-and-Ask に移行すること。

---

## Stop And Ask Conditions

以下の3条件のいずれかに直面した場合のみ作業を即座に中断して人間に指示を仰ぐこと。それ以外は自律的に進行せよ：

1. **破壊的または取り返しのつかない操作**が必要になった場合（SharedPreferences キー変更・JSON 形状変更など、既存インストールデータを破壊する操作）。
2. **リファクタリングのスコープ（目的）の真の変更**が必要であると判明した場合（M3・M4・M5 は既に人間の承認済みのため、これ以上の確認は不要。それ以外の新たなスコープ変更が必要になった場合のみ該当）。
3. **人間本人にしか出せない情報**が不足している場合。

---

## Memory System (Lessons Log)

`.claudelog/lessons-learned.md` に以下の形式で随時追記すること（上書き・削除禁止。Round 1〜2 の既存内容はそのまま残す）：

```
## Round 3 — Phase N — <フェーズ名>
- <1行要約>: <発生したエラー or 成功パターン>
```

---

## Debt Map

**凡例 — Authority**: `IMPLEMENT` = このブリーフの範囲内で安全に実施してよい; `PROPOSE-ONLY` = 設計案を lessons log に書くが、人間の承認なしにコードを変更しないこと。

### M1 — TownLogic がグリッド範囲外の座標を拒否しない

| 項目 | 内容 |
|------|------|
| **ファイル/箇所** | `lib/domain/town_logic.dart:42-52`（`canBuild`/`isOccupied`）, `lib/providers/town_provider.dart:53-76`（`buildBuilding`） |
| **問題** | `TownLogic.canBuild`/`isOccupied` は座標の重複チェックのみ行い、`x`/`y` が `[0, GameConstants.townGridSize)` の範囲内かを検証しない。現在の唯一の呼び出し元 `TownScreen._onTileTap`（`town_screen.dart:194-195`）は `GridView.builder` の `index % gridSize` / `index ~/ gridSize` から座標を計算するため範囲外の値は発生しないが、これは呼び出し元の偶然の安全性であり、ドメイン層自身は不変条件を守っていない。 |
| **根拠** | `town_logic.dart:42-52`（範囲チェック皆無）+ `town_provider.dart:53-76`（`buildBuilding` も範囲チェックなしでそのまま永続化）+ `town_screen.dart:194-202`（唯一の呼び出し元が範囲内に限定している実態） |
| **影響範囲とリスク** | 将来 API 経由・デバッグ機能・別画面から `buildBuilding`/`canBuild` を呼ぶコードが追加された場合、範囲外座標がそのまま永続化されうる。`TownState.buildingAt`/グリッド描画は範囲外データを想定しておらず、表示崩れや無限に増え続ける非表示建物のリスク。 |
| **改善案** | `TownLogic` に `static bool isWithinGrid(int x, int y) => x >= 0 \&\& x < GameConstants.townGridSize \&\& y >= 0 \&\& y < GameConstants.townGridSize;` を追加。`canBuild` の先頭で `if (!isWithinGrid(x, y)) return false;` を追加。`TownProvider.buildBuilding` の先頭でも同様に範囲外なら `false` を返すガードを追加（`isOccupied` チェックの前）。 |
| **検証方法** | `flutter test` 全パス。`test/town_logic_test.dart` に「範囲外座標 (-1, 0) / (5, 0) は `canBuild` が false を返す」テストを追加。 |
| **Authority** | **IMPLEMENT** |

---

### M2 — HistoryScreen の削除操作が await されていない（サイレントエラー）

| 項目 | 内容 |
|------|------|
| **ファイル/箇所** | `lib/screens/history_screen.dart:94-96`（`onDismissed`） |
| **問題** | `onDismissed: (_) { context.read<EnergyProvider>().deleteHistoryRecord(record.date); }` — `deleteHistoryRecord` は `Future<void>` を返すが await も例外処理もしていない。Round 2 の N2（`TownScreen` の建設失敗サイレントエラー）と同種のパターンが履歴削除にも存在する。 |
| **根拠** | `history_screen.dart:94-96`（非同期呼び出し）+ `energy_provider.dart:114-120`（`Future<void>` を返す `deleteHistoryRecord`） |
| **影響範囲とリスク** | `Dismissible` は呼び出し前に楽観的にUIから項目を消すため、ストレージ書き込み失敗時にユーザーには削除成功したように見えるが実際は失敗している可能性がある（次回起動時に項目が復活する）。リスクは低い（`SharedPreferences.remove` はほぼ失敗しない）が、既存の対処パターンとの一貫性がない。 |
| **改善案** | `onDismissed` 内で `unawaited(...)` ではなく、明示的に `.catchError` でログ（既存に統一されたログ機構がないため、最小実装として `debugPrint` での記録に留める）するか、`confirmDismiss` 側で先に `await` してから `true` を返す形に変える（後者は確認ダイアログ後・スワイプ確定前に削除を完了させるため、より既存パターン（建設失敗時に通知）と一貫する）。**推奨**: `confirmDismiss` 内で削除確認ダイアログが `true` を返した直後に `await context.read<EnergyProvider>().deleteHistoryRecord(record.date);` を実行してから `true` を返すよう変更し、`onDismissed` は空にする。 |
| **検証方法** | `flutter analyze` クリーン。`flutter test` 全パス。 |
| **Authority** | **IMPLEMENT** |

---

### M3 — HealthService が LocalStorage を経由せず SharedPreferences を直接操作している

| 項目 | 内容 |
|------|------|
| **ファイル/箇所** | `lib/services/health_service.dart:44-45`（キー定数）, `:86`（`SharedPreferences.getInstance()` 直接呼び出し）, `:91-92, 95-96`（直接読み書き） |
| **問題** | `LocalStorage`（`local_storage.dart:13` のコメントで「全モデルの save / load」を担うと明記）以外に、`HealthService` が独自に `health_android_baseline_date` / `health_android_baseline_steps` キーで `SharedPreferences` を直接読み書きしている。ストレージキーの所有権が2箇所に分散している。 |
| **根拠** | `health_service.dart:44-45`（独自キー定義）+ `:86,91-92,95-96`（直接アクセス）+ `local_storage.dart:13-26`（本来の一元管理場所） |
| **影響範囲とリスク** | 中〜大。`main.dart:10-13` は `HealthService` を `SharedPreferences` 取得**前**に生成しているため、`HealthService` に `SharedPreferences`（または `LocalStorage`）を注入するには `main.dart` の初期化順序を入れ替える必要がある。さらに `HealthService()` を直接コンストラクトしているテスト（`test/widget_test.dart`）にも影響する可能性があり、ストレージ層の責務統一という設計判断と起動シーケンス変更を伴うため、単純な「今すぐ直せる」負債ではない。 |
| **改善案** | `main.dart` で `SharedPreferences.getInstance()` を `HealthService` 生成前に呼び、`HealthService` のコンストラクタに `SharedPreferences` を渡す。内部のキー定数を `LocalStorage` に移すか、`HealthService` 専用のままでも `LocalStorage` 経由でアクセスするメソッドを追加する。 |
| **検証方法** | `flutter test` 全パス（`health_service_test.dart` は純粋関数のみテストのため影響なし、`widget_test.dart` の `HealthService()` 呼び出し箇所の更新が必要）。 |
| **Authority** | **IMPLEMENT**（人間確認済み・起動シーケンス変更を含めて今回実施する） |

---

### M4 — EnergyProvider の責務過多（蓄電池・歩数・履歴・生涯統計）

| 項目 | 内容 |
|------|------|
| **ファイル/箇所** | `lib/providers/energy_provider.dart:12-147` |
| **問題** | `EnergyProvider` が「蓄電池の状態」「当日の歩数/エネルギー」「日次履歴の読込・削除」「生涯発電量」という4つの異なる関心事を1つの `ChangeNotifier` に集約している。`HistoryScreen` は履歴管理だけが必要なのに `EnergyProvider` 全体に依存している。 |
| **根拠** | `energy_provider.dart:44-47`（4種類のgetter）+ `:110-127`（履歴専用メソッド群）+ `history_screen.dart:36`（`loadHistory()` のみ使うが `EnergyProvider` 全体を watch） |
| **影響範囲とリスク** | 機能的には正しく動作しており、テストも全てパスしている。分割は「設計の改善」であり「不具合の修正」ではないため、`app.dart` のプロバイダ構成変更・既存コードの広範な書き換えを伴う。 |
| **改善案** | `HistoryProvider`（`loadHistory`/`deleteHistoryRecord`/`clearHistory` を移管）を新設し、`EnergyProvider` は蓄電池・当日記録・生涯統計に専念させる案。あるいは現状維持し、メソッドのグルーピング（コメントでの章立て）のみ行う最小案。 |
| **検証方法** | `flutter test` 全パス。`HistoryScreen` の `context.watch` 先が新Providerに変わることを確認。 |
| **Authority** | **IMPLEMENT**（人間確認済み・`HistoryProvider` に分割する） |

---

### M5 — main() の healthService.configure() が未ガード（Round 2 N10 持ち越し・未解決）

| 項目 | 内容 |
|------|------|
| **ファイル/箇所** | `lib/main.dart:11` |
| **問題** | `await healthService.configure()` が例外を投げると `runApp` 前にアプリがクラッシュする。Round 2 でも `PROPOSE-ONLY` のまま未解決。 |
| **根拠** | `main.dart:7-16` |
| **改善案** | `try { await healthService.configure(); } catch (_) { /* 続行。同期時に HealthServiceException として処理される */ }` |
| **検証方法** | `flutter analyze` クリーン。`flutter test` 全パス。 |
| **Authority** | **IMPLEMENT**（人間確認済み・今回 try-catch でラップする） |

---

## Implementation Phases

各フェーズは完了次第 `flutter analyze` + `flutter test` を実行し、全パスを確認してコミットすること。

### Phase 0 — ベースライン記録（コード変更なし）

1. `git status` を実行し、未コミット変更を確認・記録する。
2. `flutter analyze` と `flutter test` を実行し、出力全体を `.claudelog/lessons-learned.md` に追記する。
   - 期待値: analyze クリーン、テスト 53 件全パス。
3. 期待値と異なる場合は即座に Stop-and-Ask。

### Phase 1 — 座標の範囲検証をドメイン層に追加（M1）

**目標**: `TownLogic` が自身の不変条件（座標はグリッド範囲内）を呼び出し元に依存せず保証する。

1. `lib/domain/town_logic.dart` に `isWithinGrid(int x, int y)` を追加し、`canBuild` の先頭で範囲外なら `false` を返すガードを追加。
2. `lib/providers/town_provider.dart` の `buildBuilding` 冒頭にも同様の範囲外ガードを追加（`isOccupied` チェックより前）。
3. `test/town_logic_test.dart` に範囲外座標のテストケースを追加。
4. `flutter analyze` クリーン、`flutter test` 全パス（54件以上）。
5. コミット: `refactor: TownLogic にグリッド範囲外座標の検証を追加`

### Phase 2 — HistoryScreen の削除失敗を確実に反映する（M2）

**目標**: 履歴削除がストレージ書き込みの完了を待ってからUIに反映されるようにする。

1. `lib/screens/history_screen.dart` の `confirmDismiss` ハンドラ内で、確認ダイアログが `true` を返した直後に `await context.read<EnergyProvider>().deleteHistoryRecord(record.date);` を実行してから `true` を返すよう変更する。
2. `onDismissed` ハンドラは空（または削除）にする。
3. `flutter analyze` クリーン、`flutter test` 全パス。
4. コミット: `fix: 履歴削除がストレージ書き込み完了後に確定するよう修正`

### Phase 3 — HealthService のストレージ責務を LocalStorage に統合（M3）

**目標**: `HealthService` が `SharedPreferences` を直接操作せず、`LocalStorage` を経由してアクセスするようにし、ストレージキーの所有権を一元化する。

1. `lib/data/local_storage.dart` に Android ベースラインの save/load メソッドを追加する（キー名 `health_android_baseline_date` / `health_android_baseline_steps` は変更しない）:
   ```dart
   static const _keyAndroidBaselineDate = 'health_android_baseline_date';
   static const _keyAndroidBaselineSteps = 'health_android_baseline_steps';

   ({String? date, int? steps}) loadAndroidStepBaseline() => (
         date: _prefs.getString(_keyAndroidBaselineDate),
         steps: _prefs.getInt(_keyAndroidBaselineSteps),
       );

   Future<void> saveAndroidStepBaseline(String date, int steps) async {
     await _prefs.setString(_keyAndroidBaselineDate, date);
     await _prefs.setInt(_keyAndroidBaselineSteps, steps);
   }
   ```
2. `lib/services/health_service.dart` のコンストラクタに `LocalStorage` を受け取る引数を追加し（既存の `health` 引数と同様の named 引数）、`_getStepsFromSensor` 内の `SharedPreferences.getInstance()` 呼び出しと直接読み書きを `LocalStorage` 経由に置き換える。
3. `lib/main.dart` の初期化順序を入れ替える：`SharedPreferences.getInstance()` → `LocalStorage` 生成 → `HealthService(storage: ...)` 生成 → `configure()`。
4. `test/widget_test.dart` の `HealthService()` 呼び出し箇所を新しいコンストラクタ引数に対応させる（テスト用 `LocalStorage` を渡す）。
5. `flutter analyze` クリーン、`flutter test` 全パス。
6. コミット: `refactor: HealthService の Android ベースライン永続化を LocalStorage に統合`

### Phase 4 — EnergyProvider から履歴管理を HistoryProvider に分離（M4）

**目標**: 履歴の読込・削除・全削除を専用の `HistoryProvider` に分離し、`HistoryScreen` の依存を絞る。

1. `lib/providers/history_provider.dart` を新規作成し、`EnergyProvider` から `loadHistory()` / `deleteHistoryRecord()` / `clearHistory()` のロジックを移管する（`LocalStorage` を直接受け取る `ChangeNotifier`）。
2. `lib/providers/energy_provider.dart` から該当メソッドを削除する。`deleteHistoryRecord` が今日の記録をリセットする副作用（`_today.date == date` の分岐）がある場合、`HistoryProvider` と `EnergyProvider` 間の整合性をどう保つか確認すること（例: `HistoryProvider` がコールバックで `EnergyProvider.refreshDisplay()` を呼ぶ、または `EnergyProvider` も併せて watch する）。挙動が変わらないことを最優先する。
3. `lib/app.dart` に `ChangeNotifierProvider` for `HistoryProvider` を追加する。
4. `lib/screens/history_screen.dart` の `context.watch<EnergyProvider>()` / `context.read<EnergyProvider>()` を `HistoryProvider` に変更する。
5. 既存の `test/energy_provider_test.dart` の履歴関連テストを `test/history_provider_test.dart` に移す（テストの意図は変更しない）。
6. `flutter analyze` クリーン、`flutter test` 全パス。
7. コミット: `refactor: 履歴管理を HistoryProvider に分離`

### Phase 5 — main() の healthService.configure() をガードする（M5）

**目標**: `configure()` が例外を投げても `runApp` 前にクラッシュしないようにする。

1. `lib/main.dart` の `await healthService.configure();` を `try { await healthService.configure(); } catch (_) { }` でラップする（コメントで「同期時に HealthServiceException として処理される」旨を記す）。
2. `flutter analyze` クリーン、`flutter test` 全パス。
3. コミット: `fix: healthService.configure() の失敗でアプリ起動がクラッシュしないようにする`

---

## Verification Requirements

### 各フェーズ完了時

- `flutter analyze` → `"No issues found!"`
- `flutter test` → 全テスト通過（テスト数 ≥ 53）

### 全フェーズ完了時（追加確認）

- `flutter test test/town_logic_test.dart` → 範囲外座標のテストを含め全パス。
- `flutter test test/energy_calculator_test.dart` → 既存4件（+ clampDailyEnergy 3件）全パス、値が変化していないこと。
- `grep -rn "onDismissed" lib/screens/history_screen.dart` → 削除処理が残っていないか、または空であることを確認。
- 既存の `test/widget_test.dart` / `test/local_storage_test.dart` / `test/energy_provider_test.dart` がすべてパスし、ストレージキー・JSON 形状に変更がないこと。
- `grep -rn "SharedPreferences.getInstance()" lib/services/health_service.dart` → 結果が0件であること（M3完了確認）。
- `grep -rn "health_android_baseline" lib/data/local_storage.dart` → キー定数と save/load メソッドが存在すること。
- `grep -rn "HistoryProvider" lib/app.dart lib/screens/history_screen.dart` → 新Providerへの差し替えが完了していること（M4完了確認）。
- `grep -n "try" lib/main.dart` → `healthService.configure()` が try-catch で囲まれていること（M5完了確認）。

---

## Out-of-scope Items

以下は今回のリファクタリング対象外とする。発見しても変更せず、最大でも提案として lessons log に記載するにとどめること：

- `lib/constants/game_constants.dart` と `building_definitions.dart` の数値調整（ゲームバランス変更は別途要承認）。
- `android/` と `ios/` 配下のネイティブ設定（AndroidManifest.xml・Info.plist・Podfile・build.gradle.kts）。
- `pubspec.yaml` の依存バージョン変更。
- `doc/` 配下のすべてのドキュメント（読み取り専用参照のみ。数値が古い場合も今回は更新しない）。
- Riverpod / Bloc への移行、ネットワーク・認証・課金の追加（仕様 §0.3 禁止事項）。
- テーマ・配色・アニメーション等のUI/UXデザイン変更。

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
- Phase 4: [完了 / 未着手 / 中断]
- Phase 5: [完了 / 未着手 / 中断]

### ブロック中の Stop-and-Ask（あれば）
<具体的な判断内容と必要な情報を記載>

### .claudelog/lessons-learned.md 追記内容（Round 3 分）
<追記した全内容をここにコピー>
```
