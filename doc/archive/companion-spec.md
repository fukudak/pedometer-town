# 相棒育成モード — 実装仕様書

**バージョン**: 1.0
**日付**: 2026-07-30
**対象**: Phase 1〜6（コアループ置き換え〜仕上げ）
**進捗管理**: [companion-plan.md](companion-plan.md)
**前提**: `../requirements.md`, `../tech-stack.md`, `../ai-implementation-spec.md`

> 本書は他の AI エージェントが **追加の口頭指示なしで実装できる** ことを目的とする。
> 迷ったら本書と既存テストを優先する。歩数→エネルギー→蓄電池のコア計算式は変更しない。

---

## 0. 共通制約（必読）

### 0.1 ゴール

「蓄電池が満タンになったら町の建物を建てる」ループを、
「蓄電池が満タンになったら相棒にごはんを与える」ループへ置き換える。

歩く → 発電 → 蓄電池満タン → **消費（給餌）** → 相棒が育つ、という一連の流れが「感じられる」ようにする。

### 0.2 禁止事項

- `EnergyCalculator.calculateEnergyWh` の計算式・`BatteryState` の折り返しロジックの変更
- オンライン通信・バックエンド・Flame 等のゲームエンジン導入
- 給餌に「空きがない」等の失敗ケースを設けること（グリッド概念は廃止するため、給餌は常に成功する）
- `battery_stored_wh` / `lifetime_energy_wh` / `pending_batteries` の永続化キー名・意味の変更

### 0.3 ディレクトリ方針

```
lib/
├── constants/
│   ├── game_constants.dart          # 既存。townGridSize 削除、rocketLaunchInterval→sparkleMomentInterval
│   ├── feed_item_definitions.dart   # 新規（旧 building_definitions.dart）
│   ├── companion_stages.dart        # 新規（旧 town_stages.dart）
│   ├── companion_atmosphere.dart    # 新規（旧 town_atmosphere.dart）
│   └── achievements.dart            # 既存を全面差し替え
├── domain/
│   ├── models/
│   │   ├── feed_item_type.dart      # 新規（旧 building.dart の enum 部分）
│   │   ├── companion_state.dart     # 新規（旧 town_state.dart）
│   │   ├── feed_event.dart          # 新規（旧 construction_event.dart）
│   │   ├── companion_stage_event.dart # 新規（旧 town_stage_event.dart）
│   │   └── sparkle_event.dart       # 新規（旧 rocket_launch_event.dart）
│   └── companion_logic.dart         # 新規（旧 town_logic.dart）
├── providers/
│   └── companion_provider.dart      # 新規（旧 town_provider.dart）
├── screens/
│   └── companion_screen.dart        # 新規（旧 town_screen.dart）
└── widgets/
    └── companion/
        └── companion_weather_overlay.dart  # 新規（旧 widgets/town/weather_overlay.dart）
```

旧ファイル（`town_*` / `building*` / `widgets/town/`）は Phase 6 で削除する。

### 0.4 検証コマンド（各 Phase 共通）

```bash
flutter analyze
flutter test
```

両方パスすること。

---

## Phase 1: コアループ置き換え

### 1.1 FeedItemType（旧 BuildingType）

```dart
// lib/domain/models/feed_item_type.dart
enum FeedItemType { meal, booster, toy }
```

座標(x, y)は持たない。グリッド概念そのものを廃止する。

### 1.2 FeedItemDefinitions（旧 BuildingDefinitions）

```dart
// lib/constants/feed_item_definitions.dart
class FeedItemDefinition {
  final FeedItemType type;
  final String displayName;
  final int batteryCost;
  final IconData icon;
}
```

| type | 表示名 | コスト(満タン蓄電池個数) | 効果 |
|------|--------|--------------------------|------|
| meal | ごはん | 1 | なつき度 +1（数値効果なし。給餌回数=なつき度のため加算のみ） |
| booster | げんきの素 | 2 | 蓄電池容量 +2,000 Wh（累積加算） |
| toy | おもちゃ | 1 | 発電効率 ×1.1（累積乗算） |

数値は `../ai-implementation-spec.md` §5 の house/powerPlant/park と完全一致させる（コスト・効果とも）。
`boosterCapacityBonusWh = 2000.0`、`toyCoefficientMultiplier = 1.1` を定数として保持する。

### 1.3 CompanionState（旧 TownState）

```dart
// lib/domain/models/companion_state.dart
class CompanionState {
  final int mealCount;
  final int boosterCount;
  final int toyCount;

  int get level => mealCount + boosterCount + toyCount;
  int countOf(FeedItemType type);
  CompanionState addFeed(FeedItemType type); // 該当カウントを+1
  Map<String, dynamic> toJson();
  factory CompanionState.fromJson(Map<String, dynamic> json);
  factory CompanionState.initial(); // 全カウント0
}
```

座標・グリッドの概念は持たない。旧 `TownState.buildings`（List）に対し、種類別カウントのみを保持する
シンプルな構造にする（グリッド管理が不要になったため）。

### 1.4 CompanionLogic（旧 TownLogic）

```dart
// lib/domain/companion_logic.dart
class CompanionLogic {
  static double effectiveCapacity(double baseCapacity, CompanionState companion);
  static double effectiveCoefficient(double baseCoefficient, CompanionState companion);
  static int bondScore({
    required int level,
    required double lifetimeEnergyWh,
    required int sparkleMoments,
  });
  static CompanionMood moodFor({required DateTime now, required DateTime? lastFedAt});
}

enum CompanionMood { none, happy, normal, lonely }
```

- `effectiveCapacity` = `baseCapacity + boosterCount * 2000.0`（旧 powerPlant と同一式）
- `effectiveCoefficient` = `baseCoefficient * pow(1.1, toyCount)`（旧 park と同一式）
- `bondScore` = `level * 10 + (lifetimeEnergyWh / 100).floor() + sparkleMoments * 50`（旧 civilizationScore と同一式。呼称のみ「愛着スコア」に変更）
- `moodFor`:
  - `lastFedAt == null` → `CompanionMood.none`（まだ一度も給餌していない＝卵状態の演出用）
  - `now.difference(lastFedAt) <= 24時間` → `happy`
  - `<= 72時間`（3日） → `normal`
  - それ以外 → `lonely`
  - 境界値は `<=` を使い、ちょうど24時間/72時間は `happy`/`normal` 側に含める

グリッド判定（`isOccupied` / `isWithinGrid`）は削除する（呼び出し元が存在しなくなるため）。

### 1.5 CompanionStages（旧 TownStages）

```dart
// lib/constants/companion_stages.dart
class CompanionStage {
  final String id;
  final String name;
  final IconData? icon;
  final int minLevel;
}
```

閾値は旧 `TownStages` と完全に同じ（0, 1, 2, 4, 7, 10, 13, 17）にする。

| minLevel | id | 表示名 | icon |
|----------|-----|--------|------|
| 0 | `egg` | まっさらな土地 | null |
| 1 | `crack` | 小さな家 | `Icons.cottage` |
| 2 | `hatch` | 電灯の村 | `Icons.lightbulb` |
| 4 | `kid` | にぎわう街 | `Icons.home_work` |
| 7 | `charged` | ビルの街 | `Icons.apartment` |
| 10 | `reliable` | 工業地帯 | `Icons.factory` |
| 13 | `radiant` | 宇宙基地 | `Icons.satellite_alt` |
| 17 | `star` | ロケット打ち上げ | `Icons.rocket_launch` |

`forLevel` / `next` / `isAtFinalStage` / `reachedStages` は旧 `TownStages` と同じシグネチャで実装する。
`rocketLaunchCount` は `sparkleCount` にリネームし、`GameConstants.sparkleMomentInterval`（旧 `rocketLaunchInterval`、値2は据え置き）を使う。

### 1.6 CompanionAtmosphere（旧 TownAtmosphere）

`companion_atmosphere.dart` に以下を実装する。時間帯・天気・季節の判定ロジックは旧 `TownAtmosphere` と**完全に同じ**（式・閾値とも変更しない）。型名のみ変更する。

```dart
enum CompanionTimeOfDay { morning, day, evening, night }
enum CompanionWeather { clear, cloudy, rainy }
enum CompanionSeason { spring, summer, autumn, winter }

class CompanionAtmospherePalette { final Color skyColor; final Color tileColor; }

class CompanionAtmosphere {
  static CompanionTimeOfDay timeOfDay(DateTime now);       // 旧と同じ閾値
  static CompanionAtmospherePalette paletteOf(CompanionTimeOfDay t); // 旧と同じ色
  static CompanionWeather weatherOf(DateTime date);        // 旧と同じシード式
  static CompanionSeason seasonOf(DateTime date);          // 旧と同じ月判定
  static CompanionAtmospherePalette applyWeatherAndSeason(...); // 旧と同じ
  static ({String title, String description}) stageStory(String stageId); // 進化物語に差し替え
  static IconData stageIcon(CompanionStage stage);
}
```

`residentDisplayCount` は削除する（住民概念を廃止するため）。

進化物語文言（`stageStory`）:

| id | タイトル | 本文 |
|----|----------|------|
| crack | 家が建った | まっさらな土地に、小さな家がひとつ建った。 |
| hatch | 電灯の村へ | 家が並び、歩いて集めたエネルギーで窓に灯りがついた。 |
| kid | にぎわう街へ | 商店や家が増え、街らしくなってきた。 |
| charged | ビルの街へ | 高層ビルが立ち、夜のスカイラインが形づくられた。 |
| reliable | 工業地帯へ | 工場と煙突が現れ、町が産業の力で動きだした。 |
| radiant | 宇宙基地へ | 研究棟と発射台が整備され、空を目指す準備が整った。 |
| star | ロケット打ち上げ | 歩いて集めたエネルギーが、ロケットを空へ押し上げた。 |

### 1.7 Achievements（全面差し替え）

```dart
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool Function(CompanionState companion, int sparkleMoments) isUnlocked;
}
```

| id | タイトル | 条件 |
|----|----------|------|
| `first_meal` | はじめてのごはん | `mealCount >= 1` |
| `first_booster` | げんきの素デビュー | `boosterCount >= 1` |
| `first_toy` | 一緒に遊ぶ道具 | `toyCount >= 1` |
| `ten_feeds` | すっかりなついた | `level >= 10` |
| `first_sparkle` | はじめてのきらめき | `sparkleMoments >= 1` |
| `five_sparkles` | きらめきの常連 | `sparkleMoments >= 5` |

### 1.8 イベントモデル

```dart
// feed_event.dart（非永続・UI演出専用。旧 ConstructionEvent の x,y を削除）
class FeedEvent { final FeedItemType type; final DateTime createdAt; }

// companion_stage_event.dart（旧 TownStageEvent と同一構造）
class CompanionStageEvent { final String stageId; final String date; }

// sparkle_event.dart（旧 RocketLaunchEvent と同一構造）
class SparkleEvent { final int number; final String date; }
```

### 1.9 テストケース（Phase 1）

`test/companion_logic_test.dart`（旧 `town_logic_test.dart` を置き換え）:

- `effectiveCapacity`: booster 0個→ベース据え置き / 1個→+2000 / 2個→+4000
- `effectiveCoefficient`: toy 0個→ベース据え置き / 1個→×1.1 / 2個→×1.1×1.1
- `bondScore`: level×10 + lifetimeEnergyWh/100(floor) + sparkleMoments×50 の合成値を検証
- `moodFor`: `lastFedAt == null` → `none` / 24時間以内 → `happy` / 3日以内 → `normal` / それ超 → `lonely`（境界値ちょうど24h・72hも検証）

`test/companion_atmosphere_test.dart`（旧 `town_atmosphere_test.dart` から住民系を除いて移植）:

- `timeOfDay` の境界値（5:00 morning / 11:00 day / 17:00 evening / 20:00 night / 4:59 night）
- `weatherOf` の同日同一性
- `seasonOf` の月境界（春3-5, 夏6-8, 秋9-11, 冬12-2）
- `applyWeatherAndSeason` で夏はタイル色が変わる

---

## Phase 2: LocalStorage 更新・マイグレーション

### 2.1 新規キー

| キー | 型 | 内容 |
|------|-----|------|
| `companion_meal_count` | int | ごはん給餌回数 |
| `companion_booster_count` | int | げんきの素給餌回数 |
| `companion_toy_count` | int | おもちゃ給餌回数 |
| `companion_last_fed_at` | String(ISO8601) | 最終給餌日時（きげん計算用） |
| `companion_celebrated_stage_ids` | List\<String\> | 演出済み進化段階ID |
| `companion_stage_events` | JSON配列 | 進化段階到達履歴 |
| `sparkle_events` | JSON配列 | きらめきタイム履歴 |
| `companion_achievement_events` | JSON配列 | 実績解除履歴（新規、旧 `achievement_events` は使わない） |
| `companion_name` | String | 相棒の名前（デフォルト空文字） |
| `companion_weather_fx_enabled` | bool | 背景演出のON/OFF（デフォルトtrue） |

`battery_stored_wh` / `lifetime_energy_wh` / `pending_batteries` / `player_weight_kg` /
`player_default_speed_kmh` / `player_energy_coefficient` は**キー名・意味とも変更しない**。

### 2.2 マイグレーション（`loadCompanionState`）

`companion_meal_count` 系のキーが一つも存在しない場合のみ、旧 `town_buildings`（JSON配列、`type`フィールドを持つ）を読み取り、
`type` ごとの件数をカウントして初期値とする（`house→meal`, `powerPlant→booster`, `park→toy`）。
旧キーが存在しない場合は全カウント0から開始する。

### 2.3 演出済み段階IDのマイグレーション

`companion_celebrated_stage_ids` が未設定（`null`）の場合、移行済みの `CompanionState.level` から
`CompanionStages.reachedStages(level)` を計算し、`egg` を除く全IDを「演出済み」として保存する
（Phase 4 で新規到達した段階だけが祝福ダイアログ対象になるようにするため）。

### 2.4 テストケース（Phase 2）

`test/local_storage_test.dart` に以下を追加（旧 TownState/Building 関連のテストは削除）:

- 未保存時、`loadCompanionState()` は全カウント0を返す
- 保存して復元できる（各カウント）
- 旧 `town_buildings`（house×2, powerPlant×1, park×1）が存在する状態から初回 `loadCompanionState()` を呼ぶと、
  `mealCount=2, boosterCount=1, toyCount=1` に変換される
- 旧データが存在しない場合、変換は発生せず全カウント0のまま
- `companion_celebrated_stage_ids` 未設定時は `null` を返す（未マイグレーション判定用）
- `CompanionStageEvent` / `SparkleEvent` の保存・復元

---

## Phase 3: CompanionProvider 実装

### 3.1 API

```dart
class CompanionProvider extends ChangeNotifier {
  CompanionState get companion;
  double get effectiveCapacityWh;
  double get effectiveCoefficient;
  int get bondScore;
  DateTime? get lastFedAt;
  CompanionMood get mood; // now() 基準
  String? get firstSparkleDate;
  List<Achievement> get pendingCelebrations;
  List<CompanionStage> get pendingStageCelebrations;
  FeedEvent? get pendingFeedEvent;

  Future<void> feedChosen(FeedItemType type); // 常に成功（グリッド判定なし）
  Future<void> feedAuto(int count); // テスト・旧advanceTown相当。meal→booster→toyを順に繰り返す
  void clearPendingCelebrations();
  void clearPendingStageCelebrations();
  void clearFeedEvent();
  bool isStageCelebrated(String stageId);
}
```

### 3.2 feedChosen の処理順序

1. `EnergyProvider.consumeStockedBatteries(cost)` は **呼び出し元（画面）の責務**（旧 `buildChosen` と同じ責務分担）
2. `companion = companion.addFeed(type)` して `companion_*_count` を永続化
3. `companion_last_fed_at` を現在時刻で更新・永続化
4. 新しい `effectiveCapacityWh` を計算し `EnergyProvider.applyBatteryState` に反映
5. 進化段階を新たに跨いだら `companion_stage_events` に記録し `pendingStageCelebrations` に積む。`companion_celebrated_stage_ids` も更新
6. 最終進化段階到達後、`sparkleCount` が増えていれば `sparkle_events` に記録
7. 実績を再チェックし、新規解除分を `companion_achievement_events` に記録して `pendingCelebrations` に積む
8. `pendingFeedEvent` をセットして `notifyListeners()`

グリッド満杯による失敗ケースは存在しない（`feedChosen` は必ず `Future<void>` で完了する）。

### 3.3 EnergyProvider との連携

`EnergyProvider` のコンストラクタ・`refreshDisplay` が参照する「建物リストから容量を算出する」処理を、
`CompanionState` から算出するように差し替える（`LocalStorage.loadBatteryState` の引数を `CompanionState` に変更）。
`EnergyProvider.setCoefficientSupplier` の呼び出し元は `app.dart` で `CompanionProvider.effectiveCoefficient` に差し替える。

### 3.4 マイグレーション時の祝福再演出防止

Phase 2.3 の演出済みIDマイグレーションにより、既存ユーザーが初回起動時に大量の進化祝福ダイアログを
連続表示されることはない（旧 Phase 4 と同じ設計）。

### 3.5 テストケース（Phase 3）

`test/companion_provider_test.dart`（旧 `town_provider_test.dart` を置き換え）:

- `feedAuto(1)` で `mealCount` が1増える（種類は meal→booster→toy の順で割り当てられる）
- `feedAuto(3)` で meal, booster, toy がそれぞれ1ずつ増える
- booster を与えると蓄電池容量が+2000Whされる
- `feedChosen` 成功後に `pendingFeedEvent` がセットされ、`clearFeedEvent` 後は null になる
- `feedChosen` はグリッドという概念がないため何度呼んでも失敗しない（旧「グリッド満杯」テストは削除）
- 初回きらめき発生日を取得できる（`firstSparkleDate`）
- 最終進化段階(17回目)到達で `sparkle_events` に1件記録される
- 最終進化段階到達後、interval(2)回ごとにきらめき回数が増える
- 愛着スコアが `level×10 + ...` で算出される
- 実績: 初回 meal 給餌で `first_meal` が解除される。`clearPendingCelebrations` 後は空になる。二重解除されない
- 実績: 17回目で `first_sparkle` が解除される
- 進化段階祝福: level 0→1 で `crack` が pending になり保存される
- 進化段階祝福: 旧 `town_buildings`（10棟相当）からのマイグレーション後は過去分の段階祝福が pending にならない

---

## Phase 4: 画面・ウィジェット実装

### 4.1 CompanionScreen

`lib/screens/companion_screen.dart`（`town_screen.dart` を置き換え）。グリッド描画は行わない。

構成:

- AppBar: 相棒の名前（未設定なら「あいぼう」）、スクリーンショットモードトグル
- 相棒表示エリア: `CompanionStages.forLevel(level).icon`（null の場合は卵アイコン代替）を中央に大きく表示。
  アイドルアニメーション（軽いバウンド、`AnimationController` 使用、`dispose`必須）。
  背景に `CompanionWeatherOverlay` と時間帯パレットを適用（Phase 2/5 相当の情緒演出を踏襲）
- タップで「なでる」演出（ハートアイコンのフェード+ハプティック、非永続）
- 進化段階名 + 次の段階までの進捗バー（旧 `TownStages` 表示と同一構成）
- きげん表示（`CompanionMood` に応じたテキスト・色。例: happy=「ごきげん」, normal=「ふつう」, lonely=「さみしそう」, none=「まだ生まれていない」）
- ストックカード（`BatteryStockDisplay` 再利用）+「ごはんをあげる」ボタン → ボトムシートで `FeedItemType` を選択（旧 `_useStock` と同じ構成。ただし「空きマスがありません」の分岐は削除）
- 統計行: 愛着スコア（旧 文明スコア。人口統計は削除）
- 与えた回数チップ（種類別）
- 初きらめき日チップ・きらめき回数（最終進化後のみ）

### 4.2 なでる演出

- 相棒画像をタップ → `HapticFeedback.lightImpact()` + 小さなハートパーティクルを1〜2秒表示
- 状態は非永続（アプリ再起動でリセットされてよい）
- 連続タップ時は演出をリスタートしてよい（クールダウン必須ではない）

### 4.3 きげん表示

`CompanionLogic.moodFor(now: DateTime.now(), lastFedAt: companionProvider.lastFedAt)` を都度計算し、
永続化しない（`lastFedAt` のみ永続化し、きげんは表示のたびに算出する導出値）。

### 4.4 CompanionWeatherOverlay

`widgets/town/weather_overlay.dart` を `widgets/companion/companion_weather_overlay.dart` に移動し、
`TownWeather`/`TownSeason` への参照を `CompanionWeather`/`CompanionSeason` に、クラス名を `CompanionWeatherOverlay` に変更する。
描画ロジック（パーティクル生成・降らせ方）は変更しない。

### 4.5 town_residents.dart 削除

単体の相棒を育てるモードに住民の概念はないため、`lib/widgets/town/town_residents.dart` と
`test/weather_overlay_test.dart` 以外で参照している箇所（`town_screen.dart` の `TownResidentsOverlay` 呼び出し）を削除する。

### 4.6 他画面の更新

- `home_screen.dart`: 「町」ボタン→「相棒」（`Icons.pets`）、遷移先を `CompanionScreen` に変更
- `app.dart`: `TownProvider`→`CompanionProvider` に差し替え
- `history_screen.dart`: セクション見出しを「🌟 相棒の記録」「きらめきタイム履歴」に変更。データソースは `HistoryProvider` の該当メソッドをリネームして接続
- `how_to_play_screen.dart`: 給餌ループの説明・ごはん3種の効果・進化段階一覧に全面差し替え
- `settings_screen.dart`: 「町の表示」セクション→「相棒の表示」、「町の名前」→「相棒の名前」、「町の天気演出」→「背景の天気演出」

### 4.7 テストケース（Phase 4）

`test/companion_weather_overlay_test.dart`（旧 `weather_overlay_test.dart` を移設）:

- 天気演出オフ時はオーバーレイを置かない
- 天気演出オン時は `CustomPaint` を描画する

`test/widget_test.dart` 更新:

- ホーム画面に蓄電池と同期ボタンが表示される（既存アサーションを維持。文言変更があれば追従）

---

## Phase 5: 実績・進化祝福・履歴連携

Phase 3/4 で実装済みの内容を UI 経由で確認する。追加のユニットテストは Phase 3 に含める。

- [x] 実績解除ダイアログが `CompanionScreen` で表示される
- [x] 進化段階到達ダイアログが表示される
- [x] `HistoryScreen` に「🌟 相棒の記録」「きらめきタイム履歴」「実績」セクションが表示される

---

## Phase 6: 旧町コードの削除・仕上げ

### 6.1 削除対象ファイル

```
lib/screens/town_screen.dart
lib/providers/town_provider.dart
lib/domain/town_logic.dart
lib/domain/models/building.dart
lib/domain/models/town_state.dart
lib/domain/models/construction_event.dart
lib/domain/models/town_stage_event.dart
lib/domain/models/rocket_launch_event.dart
lib/constants/town_stages.dart
lib/constants/building_definitions.dart
lib/constants/town_atmosphere.dart
lib/widgets/town/  (ディレクトリごと)
test/town_logic_test.dart
test/town_provider_test.dart
test/town_atmosphere_test.dart
test/weather_overlay_test.dart  (companion_weather_overlay_test.dart に置き換え済みなら削除)
```

### 6.2 完了条件

- [ ] 上記ファイルがすべて削除されている
- [ ] `grep -ri "town" lib/` で `pedometer_town`（パッケージ名・アプリタイトル・doc内の歴史的記述）以外のヒットがない
- [ ] README / requirements.md / tech-stack.md / ai-implementation-spec.md が相棒育成モードの内容に更新されている
- [ ] `flutter analyze` / `flutter test` が全パスする
- [ ] `companion-plan.md` の進捗表がすべて完了になっている

---

## 付録: 用語対応表

| 旧用語 | 新用語 |
|--------|--------|
| 町 | 相棒 |
| 建物を建てる | ごはんをあげる（給餌） |
| 町レベル・建物数 | なつき度レベル |
| 発展段階 | 進化段階 |
| 文明スコア | 愛着スコア |
| ロケット発射 | きらめきタイム |
| 人口 | （廃止） |
