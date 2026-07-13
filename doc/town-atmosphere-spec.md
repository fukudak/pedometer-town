# 町の情緒・見た目強化 — AI 実装仕様書

**バージョン**: 1.0  
**日付**: 2026-07-13  
**対象**: Phase 1〜6（見た目・情緒）  
**進捗管理**: [town-atmosphere-plan.md](town-atmosphere-plan.md)  
**前提**: `requirements.md`, `tech-stack.md`, `ai-implementation-spec.md`

> 本書は他の AI エージェントが **追加の口頭指示なしで実装できる** ことを目的とする。  
> 迷ったら本書と既存テストを優先し、ゲーム数値は変更しない。

---

## 0. 共通制約（必読）

### 0.1 ゴール

町画面（`TownScreen`）の見た目と情緒を強化する。  
歩く → 発電 → 建設、という既存ループは維持し、**建設結果と町の時間が「感じられる」ようにする**。

### 0.2 禁止事項

- オンライン通信・天気 API・バックエンド
- Flame / Custom game engine の導入
- 建物コスト・容量・係数・グリッドサイズなど **ゲームバランス数値の変更**
- 手動配置・隣接ボーナス・アップグレードなど **戦略系機能**（別計画）
- 既存の歩数同期・蓄電池ストック・`buildChosen` のコスト消費ロジックの破壊的変更
- 本書にない SharedPreferences キーの乱立（必要なキーは各 Phase で明示）

### 0.3 ディレクトリ方針

```
lib/
├── constants/
│   └── town_atmosphere.dart      # Phase 2〜 で追加可（時間帯・物語テキスト等）
├── domain/
│   └── models/
│       ├── construction_event.dart   # Phase 1
│       └── town_stage_event.dart     # Phase 4（任意・履歴用）
├── widgets/
│   └── town/                         # 新規ディレクトリ
│       ├── town_grid_map.dart        # town_screen から抽出推奨
│       ├── construction_fx.dart      # Phase 1
│       ├── time_of_day_theme.dart    # Phase 2
│       ├── building_lights.dart      # Phase 2
│       ├── town_residents.dart       # Phase 3
│       └── weather_overlay.dart      # Phase 5
└── screens/
    └── town_screen.dart              # 組み立て役に留める
```

`_TownGridMap` は現状 `town_screen.dart` 内の private クラス。Phase 1 着手時に `lib/widgets/town/town_grid_map.dart` へ抽出してよい（挙動互換を維持）。

### 0.4 検証コマンド（各 Phase 共通）

```bash
flutter analyze
flutter test
```

両方パスすること。

### 0.5 進捗更新義務

Phase 完了後、[town-atmosphere-plan.md](town-atmosphere-plan.md) の:

1. 進捗サマリー表の状態・完了日
2. 当該 Phase のタスクチェックリスト

を更新すること。

---

## Phase 1: 建設の手応え

### 1.1 目的

`buildChosen` 成功直後に、どの建物がどこに建ったかを体感できるようにする。

### 1.2 現状の流れ（変更してはいけない核）

1. 町画面「使う」→ ボトムシートで `BuildingType` 選択
2. `EnergyProvider.consumeStockedBatteries(cost)`
3. `TownProvider.buildChosen(type)` → `_placeBuilding` で空き座標へ追加
4. 実績チェック・ロケット発射記録

### 1.3 追加仕様

#### 1.3.1 ConstructionEvent（一時状態・非永続）

```dart
class ConstructionEvent {
  final BuildingType type;
  final int x;
  final int y;
  final DateTime createdAt;
}
```

- `TownProvider` が直近 1 件（または短いキュー）を保持
- UI が表示したら `clearConstructionEvent()` で消費
- SharedPreferences には保存しない
- アプリ再起動後に再表示してはならない

#### 1.3.2 UI 演出（必須）

| 演出 | 詳細 |
|------|------|
| バウンド | 新建物アイコンを `scale 0.3 → 1.0`、`Curves.elasticOut`、約 500–700ms |
| ハイライト | 該当マスを 2–3 秒、枠線または背景強調 |
| パーティクル | 該当地点中心に短いキラキラ（`CustomPainter` または複数 `Icon` の Opacity アニメで可）。重い物理演算は不要 |
| 触覚 | `HapticFeedback.mediumImpact()`（建設成功時 1 回） |
| トースト | SnackBar またはオーバーレイで 2–3 秒:  
  `「{displayName}が完成しました」` + 効果文言 |

効果文言の例:

| type | 文言 |
|------|------|
| house | `人口 +{population}` |
| powerPlant | `蓄電池容量 +{powerPlantCapacityBonusWh} Wh` |
| park | `発電効率 ×{parkCoefficientMultiplier}` |

数値は `BuildingDefinitions` / 定数から取得し、ハードコードしない。

#### 1.3.3 実装ヒント

- `buildChosen` 成功時に `ConstructionEvent` をセットして `notifyListeners`
- `TownScreen` または `TownGridMap` が `watch` / `listen` して演出開始
- 演出中に別の建設が起きた場合は最新を優先、またはキュー（最大 3）

### 1.4 テスト要件

| テスト | 内容 |
|--------|------|
| Provider | `buildChosen` 成功後に event が非 null、clear 後に null |
| Provider | グリッド満杯で `buildChosen` 失敗時は event を立てない |
| （任意）Widget | SnackBar / テキストに建物名が含まれる |

### 1.5 完了条件

- [ ] 建設成功時にバウンド・ハイライト・触覚・完成メッセージが出る
- [ ] 再起動後に同じ建設演出が再生されない
- [ ] ゲーム数値・建設コストロジックが変わっていない
- [ ] `flutter analyze` / `flutter test` パス
- [ ] 計画書の Phase 1 を完了更新

---

## Phase 2: 時間帯と町の灯り

### 2.1 目的

端末の現在時刻で町マップの雰囲気を変える。データ移行不要。

### 2.2 TownTimeOfDay

```dart
enum TownTimeOfDay { morning, day, evening, night }
```

判定（端末ローカル時刻）:

| 区分 | 時刻 |
|------|------|
| morning | 5:00 ≦ t < 11:00 |
| day | 11:00 ≦ t < 17:00 |
| evening | 17:00 ≦ t < 20:00 |
| night | それ以外（20:00–5:00） |

`DateTime Function() now` を注入可能にし、テストで固定時刻を渡せるようにする。

### 2.3 パレット（推奨値）

実装で微調整可。コントラストを落とさないこと。

| 区分 | マップ外枠/空 | マス（草地） | 備考 |
|------|---------------|--------------|------|
| morning | `#87CEEB` 寄り | `#9CCC65` | 明るめ |
| day | 現状に近い緑青 | `#8FCE52`（現行マス色に近い） | 現行 `#7CB342` 系をベースに可 |
| evening | `#FF8A65` / `#7E57C2` グラデーション可 | `#AED581` | 暖色 |
| night | `#1A237E` / `#0D1B2A` | `#33691E` 暗め | 星は任意（軽量ドット） |

現行の固定色:

- マップ背景: `Color(0xFF7CB342)`
- マス: `Color(0xFF8FCE52)`

### 2.4 建物ライト

| 建物 | 演出 |
|------|------|
| house | **night / evening** のみ窓ライト（小さな矩形や点灯アイコン重ね） |
| powerPlant | 全時間帯でゆっくり明滅（1.5–2.5 秒周期） |
| park | **night** のみ街灯（小さな黄点） |
| （ロケット段階） | `TownStages.isAtFinalStage` のとき警告灯の点滅（任意だが推奨） |

AnimationController は State で管理し、`dispose` 必須。画面非表示時は `TickerMode` / ライフサイクルで止めてよい。

### 2.5 永続化

なし。時刻は表示時に計算。

### 2.6 テスト要件

| テスト | 内容 |
|--------|------|
| 純関数 | 各境界時刻（5:00, 11:00, 17:00, 20:00, 4:59）の区分 |
| （任意） | パレットが null にならない |

### 2.7 完了条件

- [ ] 朝昼夕夜で背景色が変わる
- [ ] 夜に住宅の灯りが見える
- [ ] 発電所が明滅する
- [ ] Controller リークがない（画面離脱で dispose）
- [ ] `flutter analyze` / `flutter test` パス
- [ ] 計画書 Phase 2 を完了更新

---

## Phase 3: 住民の気配

### 3.1 目的

人口を数値だけでなく、マップ上の小さな生活感として見せる。

### 3.2 描画ルール

```
displayCount = min(maxResidents, max(0, houseCount)) をベースに調整
```

推奨:

- `maxResidents = 8`
- `night` のときは `displayCount = max(0, displayCount ~/ 2)` または最大 3
- 住宅 0 なら住民 0

住民は **見た目専用**。`TownLogic.totalPopulation` や文明スコアに影響させない。

### 3.3 挙動

- グリッド座標上をゆっくり移動（1 マス移動に数秒）
- 建物マスの「上」を完全に塞がない（角や通路側にオフセット）
- 公園がある場合、一定確率で公園マス付近に滞在
- 位置・ルートは **永続化しない**（毎回起動で初期配置してよい）
- タップ対象にしない（`IgnorePointer` 推奨）

### 3.4 吹き出し（任意だが推奨）

- 数分に 1 回程度、ランダムな短文を 2 秒表示
- 例: `いい天気` / `公園まで散歩` / `町が明るくなったね`
- ゲーム進行・乱数シードはセーブに影響させない

### 3.5 テスト要件

| テスト | 内容 |
|--------|------|
| 純関数 | houseCount / timeOfDay → displayCount |
| 上限 | displayCount ≤ maxResidents |

### 3.6 完了条件

- [ ] 住宅が増えると住民が見える
- [ ] 夜間は減る
- [ ] 位置がセーブされない
- [ ] 操作（使うボタン等）を阻害しない
- [ ] `flutter analyze` / `flutter test` パス
- [ ] 計画書 Phase 3 を完了更新

---

## Phase 4: 発展段階の祝福演出

### 4.1 目的

`TownStages` の段階に初めて到達したとき、短い物語付きで祝福する。実績ダイアログとは別系統でよい（共存可）。

### 4.2 永続化（必須）

SharedPreferences キー:

```
town_celebrated_stage_ids  // StringList: 例 ["horizon", "lightbulb", ...]
```

段階 ID は安定した文字列にすること（表示名変更に耐える）:

| minLevel | id | 表示名（既存） |
|----------|-----|----------------|
| 0 | `empty` | 何もない地平線 |
| 1 | `lightbulb` | 豆電球がつく |
| 2 | `lamp` | 電灯がつく |
| 4 | `house_lights` | 家の明かりが付く |
| 7 | `factory` | 工場が稼働する |
| 10 | `town` | 街が広がる |
| 13 | `city` | 都市になる |
| 17 | `rocket` | ロケット建設する |

`TownStages` に `id` フィールドを追加してよい（破壊的でなければ）。

### 4.3 マイグレーション（必須）

初回ロード時:

- `town_celebrated_stage_ids` が未設定
- かつ既に建物がある（または stage > empty）

→ **現在到達済みの全段階 ID を「演出済み」として保存**し、過去分の祝福を連続表示しない。

### 4.4 物語テキスト（推奨文）

| id | タイトル | 本文 |
|----|----------|------|
| lightbulb | 最初の灯り | 暗い地平線に、豆電球がひとつ灯った。 |
| lamp | 道が見える | 電灯がつき、足元が少し安心になった。 |
| house_lights | 誰かの夜 | 窓から明かりが漏れ、人が住みはじめた気配がする。 |
| factory | 動き出す町 | 工場が息を吹き返し、エネルギーが町を巡りはじめる。 |
| town | 街の輪郭 | 家並みが増え、ここが「街」と呼べるようになった。 |
| city | 都市の鼓動 | 夜景が広がり、文明の灯りが空に届きそうだ。 |
| rocket | 空へ | ロケットが立つ。歩いて蓄えた力が、空を目指す。 |

`empty` は祝福不要。

### 4.5 UI

- 到達検知は `_placeBuilding` / `buildChosen` 後（棟数増加時）
- 既存の実績 `pendingCelebrations` と同様、キューで順に表示してよい
- ダイアログ内容: アイコン・タイトル・本文・「つづきを歩く」等の閉じるボタン
- 履歴: `HistoryScreen` に「町の記録」セクションを追加し、到達日を表示

履歴用モデル例:

```dart
class TownStageEvent {
  final String stageId;
  final String date; // YYYY-MM-DD
}
```

キー例: `town_stage_events` (JSON array)

### 4.6 テスト要件

| テスト | 内容 |
|--------|------|
| マイグレーション | 既存 10 棟セーブ相当で初回は全到達済みになり、ダイアログキュー空 |
| 新規到達 | level 0→1 で lightbulb が pending になり、保存後は再発しない |
| 永続化 | save/load 往復 |

### 4.7 完了条件

- [ ] 新段階到達で一度だけ祝福が出る
- [ ] 既存ユーザーに過去分が連続再生されない
- [ ] 履歴で読み返せる
- [ ] `flutter analyze` / `flutter test` パス
- [ ] 計画書 Phase 4 を完了更新

---

## Phase 5: 天気と季節

### 5.1 目的

外部 API なしで、日ごとに少し違う景色にする。

### 5.2 天気

```dart
enum TownWeather { clear, cloudy, rainy }
```

- シード: `YYYYMMDD`（端末ローカル日付）のハッシュまたは簡易 LCG
- **同じ日付 → 同じ天気**（純関数でテスト可能）
- 分布目安: clear 50% / cloudy 30% / rainy 20%（調整可）

### 5.3 季節

| 月 | 季節 | 軽い演出 |
|----|------|----------|
| 3–5 | spring | 花びらパーティクル（稀疏） |
| 6–8 | summer | 演出控えめ（緑濃く） |
| 9–11 | autumn | 落ち葉 |
| 12–2 | winter | 雪（稀疏） |

雨・雪は Overlay でグリッド上に降らせる。ゲームロジック非影響。

### 5.4 設定

`PlayerSettings` または単独キー:

```
town_weather_fx_enabled  // bool, default true
```

設定画面に「町の天気演出」スイッチを追加。

### 5.5 完了条件

- [ ] 日付が同じなら天気が同じ
- [ ] 季節演出が出る
- [ ] オフにできる
- [ ] API を呼ばない
- [ ] `flutter analyze` / `flutter test` パス
- [ ] 計画書 Phase 5 を完了更新

---

## Phase 6: 町の愛着機能

### 6.1 町の名前（必須寄りの優先）

- キー: `town_name` (String)
- デフォルト: `わたしの町` または空（空なら「町」と表示）
- 設定画面または町画面の編集アイコンで変更
- AppBar / マップ下タイトルに表示

### 6.2 初ロケット記念碑（推奨）

- 初回 `RocketLaunchEvent` がある場合、マップ隅または専用チップで  
  `初ロケット: YYYY-MM-DD` を表示
- 新規建物タイプは増やさない（表示のみで可）

### 6.3 スクリーンショットモード（推奨）

- 町画面にトグル（アイコン）
- ON 時: ストックカード・統計・ボタン類を隠し、マップ＋町名＋段階名のみ
- 永続化不要（セッション限りで可）

### 6.4 任意バックログ

- 「今日の町」カード（時間帯＋天気＋段階の一文）
- 建物アイコンの色違い（`Building` に colorSeed を足す場合は fromJson 互換必須）

### 6.5 完了条件

- [ ] 町名が表示・変更できる
- [ ] （実装した場合）記念碑・スクショモードが動作する
- [ ] 既存セーブが壊れる変更がない
- [ ] `flutter analyze` / `flutter test` パス
- [ ] 計画書 Phase 6 を完了更新

---

## 付録 A: 既存コードの重要ポイント

### 建設

- UI: `lib/screens/town_screen.dart` → `_useStock`
- ロジック: `TownProvider.buildChosen` / `_placeBuilding`
- コスト: `BuildingDefinitions.*.batteryCost`（個数）
- 空き座標: `_nextAvailablePosition`（左上から走査）

### グリッド

- サイズ: `GameConstants.townGridSize` (= 5)
- 表示: `_TownGridMap`

### 発展段階

- `TownStages.stages` / `forLevel` / `next` / `isAtFinalStage` / `rocketLaunchCount`

### 実績（共存）

- `TownProvider.pendingCelebrations` — 祝福ダイアログ済み
- Phase 4 はこれと別キューでも、統合しても可。統合する場合は差分を計画書備考に書くこと

---

## 付録 B: 他 AI への引き継ぎテンプレ

新しいセッションで実装を頼むとき、次を渡せばよい。

```
万歩計タウンの町情緒強化を実装してください。

1. 必ず読む:
   - doc/town-atmosphere-plan.md（進捗の正典。未完了 Phase のみ着手）
   - doc/town-atmosphere-spec.md（実装詳細）
2. 今回やること: Phase X（計画書の推奨リリースに従う）
3. 完了後: analyze/test パス、計画書のチェックリスト更新
4. 禁止: 戦略系・数値変更・Flame・外部天気 API
```

第一弾を一気に頼む場合:

```
doc/town-atmosphere-plan.md の第一弾（Phase 1 + 2 + 4）を
doc/town-atmosphere-spec.md に従って実装し、
完了後に計画書の進捗を更新してください。
```

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-07-13 | 初版。Phase 1〜6 の実装仕様を定義 |
