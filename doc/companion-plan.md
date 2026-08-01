# 相棒育成モード — 全体計画書

**バージョン**: 1.0
**日付**: 2026-07-30
**方針**: 「町を建設する」コアループを白紙にし、「蓄電した電気で相棒を育てる」に置き換える
**前提ドキュメント**:
- [requirements.md](requirements.md)
- [tech-stack.md](tech-stack.md)
- [ai-implementation-spec.md](ai-implementation-spec.md)
- **実装詳細**: [companion-spec.md](companion-spec.md)

---

## 0. AIへの指示（必読）

1. 本書は **進捗の正典** である。作業開始前に進捗表を確認し、完了した Phase を飛ばすこと。
2. 実装の詳細仕様・テストケースは [companion-spec.md](companion-spec.md) を正典とする。
3. 歩数→エネルギー→蓄電池のコアループ（`EnergyCalculator` / `BatteryState` / `EnergyProvider.syncStepsFromHealth`）は **変更しない**。
4. 「町・建物・グリッド配置」に関するコードは本計画で **完全に置き換える**（一旦白紙）。5×5グリッドや建物の座標管理は廃止する。
5. 各 Phase 完了時に、本書の進捗表を `[x]` に更新し、完了日を記入すること。
6. `flutter analyze` / `flutter test` を **すべてパス** させてから次 Phase へ進むこと。

---

## 1. コンセプト決定の経緯

検討した方向性（ユーザーへの提示・選定結果）:

| 案 | 概要 | 採否 |
|----|------|------|
| 育成ペット/相棒 | 電気を「エサ」として相棒に与え、育てる | **採用** |
| ガチャ&コレクション | 電気でガチャを回しアイテム収集 | 見送り |
| アーケード部屋（ミニゲーム） | 電気を消費してミニゲームで遊ぶ | 見送り |
| 探検/クエスト消費型 | 電気で探検隊を派遣し結果を受け取る | 見送り |

**採用理由**: 既存の「歩数→エネルギー→蓄電池→満タン消費」というループと最も自然に接続でき、
「町の建物を選ぶ」→「相棒に与える食べ物を選ぶ」という置き換えだけで既存コードの構造
（Provider・数値効果・実績・発展段階・履歴）をそのまま転用できるため、実装リスクが最小。

## 2. コンセプト

> 歩いて貯めた電気で、電気で動く相棒を育てる。

- 満タン蓄電池 = 相棒への「ごはん」
- ごはんの種類（3種）を選んで相棒に与える（旧: 建物3種を選んで建設）
- 与えた回数の合計が「なつき度レベル」となり、8段階で見た目が進化する（旧: 建物数で町が発展）
- ごはんの種類によって蓄電池容量・発電効率が変化する（旧: 発電所・公園の効果と同じ数値をそのまま流用）
- 最終進化後は一定間隔で「きらめきタイム」という祝福演出が発生する（旧: ロケット発射）
- 相棒をタップすると「なでる」演出が出る（無償・電気を消費しない軽い触れ合い）
- 直近の給餌からの経過時間で相棒の機嫌（きげん）が変化する（新規要素）
- 相棒に名前を付けられる（旧: 町の名前）

**やらないこと（本計画の範囲外）**:

- 5×5グリッドでの配置・空きマス管理（廃止。給餌回数に上限はない）
- ミニゲーム・ガチャ・探検要素
- オンライン要素・バックエンド
- Flame 等のゲームエンジン導入

## 3. 現状（ベースライン）と置き換え対象

| 旧概念 | 新概念 | 備考 |
|--------|--------|------|
| `Building` / `BuildingType`（house/powerPlant/park） | `FeedItemType`（meal/booster/toy） | 座標(x,y)は廃止 |
| `TownState`（buildings リスト・グリッド） | `CompanionState`（種類別カウント） | グリッド廃止によりロジック簡素化 |
| `TownLogic`（容量・係数・人口・文明スコア・グリッド判定） | `CompanionLogic`（容量・係数・愛着スコア・きげん） | 人口・グリッド判定は削除 |
| `TownStages`（建物数で8段階） | `CompanionStages`（給餌回数で8段階、卵→星） | 閾値(0,1,2,4,7,10,13,17)は据え置き |
| `TownProvider` | `CompanionProvider` | `buildChosen`→`feedChosen`、グリッド満杯の失敗ケースは削除 |
| `TownScreen` + `_TownGridMap` | `CompanionScreen` + 相棒表示ウィジェット | グリッド描画は廃止 |
| `town_residents.dart`（住民の気配） | 削除 | 単体の相棒なので住民概念は不要 |
| `town_atmosphere.dart` | `companion_atmosphere.dart` | 時間帯・天気・季節ロジックは流用、進化物語文言に差し替え |
| `weather_overlay.dart` | `companion_weather_overlay.dart` | ロジックそのまま、型名のみ変更 |
| `RocketLaunchEvent` / ロケット発射 | `SparkleEvent` / きらめきタイム | 発生間隔ロジックは流用 |
| `achievements.dart`（建物・ロケット基準） | 給餌・きらめき基準に全面差し替え | 実績IDが変わるため履歴キーは刷新 |

関連コード（実装時の起点）:

- `lib/screens/town_screen.dart` → `lib/screens/companion_screen.dart`
- `lib/providers/town_provider.dart` → `lib/providers/companion_provider.dart`
- `lib/domain/town_logic.dart` → `lib/domain/companion_logic.dart`
- `lib/constants/town_stages.dart` / `building_definitions.dart` → `companion_stages.dart` / `feed_item_definitions.dart`

## 4. 進捗サマリー

| Phase | 名称 | 状態 | 完了日 | 備考 |
|-------|------|------|--------|------|
| 0 | ベースライン確認・ドキュメント作成 | ✅ 完了 | 2026-07-30 | 本計画書・仕様書作成 |
| 1 | コアループ置き換え（データモデル・ドメインロジック） | ✅ 完了 | 2026-07-30 | |
| 2 | LocalStorage 更新・マイグレーション | ✅ 完了 | 2026-07-30 | |
| 3 | CompanionProvider 実装 | ✅ 完了 | 2026-07-30 | |
| 4 | 画面・ウィジェット実装 | ✅ 完了 | 2026-07-30 | |
| 5 | 実績・進化祝福・履歴連携 | ✅ 完了 | 2026-07-30 | Phase 3/4 に含めて実装 |
| 6 | 旧町コードの削除・仕上げ | ✅ 完了 | 2026-07-30 | |

## 5. Phase 詳細と進捗チェックリスト

### Phase 0: ベースライン確認・ドキュメント作成 — ✅ 完了 (2026-07-30)

- [x] 全体計画書（本書）を作成
- [x] 実装仕様書 `companion-spec.md` を作成

### Phase 1: コアループ置き換え — ✅ 完了 (2026-07-30)

| # | タスク | 状態 |
|---|--------|------|
| 1.1 | `FeedItemType` enum 作成 | ✅ |
| 1.2 | `FeedItemDefinitions`（旧 `BuildingDefinitions`）作成 | ✅ |
| 1.3 | `CompanionState`（種類別カウント）作成 | ✅ |
| 1.4 | `CompanionLogic`（容量・係数・愛着スコア・きげん）作成 | ✅ |
| 1.5 | `CompanionStages`（8段階）作成 | ✅ |
| 1.6 | `CompanionAtmosphere`（旧 `TownAtmosphere`）作成 | ✅ |
| 1.7 | `Achievements` を新実績セットに差し替え | ✅ |
| 1.8 | `FeedEvent` / `CompanionStageEvent` / `SparkleEvent` モデル作成 | ✅ |
| 1.9 | ユニットテスト作成 | ✅ |

**完了条件** → [仕様書 §Phase 1](companion-spec.md#phase-1-コアループ置き換え)

### Phase 2: LocalStorage 更新・マイグレーション — ✅ 完了 (2026-07-30)

| # | タスク | 状態 |
|---|--------|------|
| 2.1 | `companion_*` キーの save/load 実装 | ✅ |
| 2.2 | 旧 `town_buildings` からのカウント移行（house→meal 等） | ✅ |
| 2.3 | 実績履歴キーの刷新（`companion_achievement_events`） | ✅ |
| 2.4 | ユニットテスト作成 | ✅ |

**完了条件** → [仕様書 §Phase 2](companion-spec.md#phase-2-localstorage-更新マイグレーション)

### Phase 3: CompanionProvider 実装 — ✅ 完了 (2026-07-30)

| # | タスク | 状態 |
|---|--------|------|
| 3.1 | `feedChosen(FeedItemType)` 実装（グリッド判定なし・常に成功） | ✅ |
| 3.2 | `EnergyProvider` の蓄電池容量・係数供給元を差し替え | ✅ |
| 3.3 | 実績判定・進化段階祝福・きらめきタイム記録 | ✅ |
| 3.4 | 既存セーブのマイグレーション（段階祝福の再演出防止） | ✅ |
| 3.5 | ユニットテスト作成 | ✅ |

**完了条件** → [仕様書 §Phase 3](companion-spec.md#phase-3-companionprovider-実装)

### Phase 4: 画面・ウィジェット実装 — ✅ 完了 (2026-07-30)

| # | タスク | 状態 |
|---|--------|------|
| 4.1 | `CompanionScreen` 作成（相棒表示・給餌ボトムシート・統計） | ✅ |
| 4.2 | なでる演出（タップ・ハプティック・非永続） | ✅ |
| 4.3 | きげん表示（`CompanionLogic.moodFor`） | ✅ |
| 4.4 | `companion_weather_overlay.dart` へリネームし再利用 | ✅ |
| 4.5 | `town_residents.dart` 削除 | ✅ |
| 4.6 | `home_screen.dart` / `app.dart` / `history_screen.dart` / `how_to_play_screen.dart` / `settings_screen.dart` 更新 | ✅ |
| 4.7 | ウィジェットテスト作成 | ✅ |

**完了条件** → [仕様書 §Phase 4](companion-spec.md#phase-4-画面ウィジェット実装)

### Phase 5: 実績・進化祝福・履歴連携 — ✅ 完了 (2026-07-30)

Phase 3/4 に統合して実装済み。

- [x] 実績解除ダイアログが表示される
- [x] 進化段階到達ダイアログが表示される
- [x] 履歴画面で相棒の記録が確認できる

### Phase 6: 旧町コードの削除・仕上げ — ✅ 完了 (2026-07-30)

| # | タスク | 状態 |
|---|--------|------|
| 6.1 | `lib/screens/town_screen.dart` 削除 | ✅ |
| 6.2 | `lib/providers/town_provider.dart` 削除 | ✅ |
| 6.3 | `lib/domain/town_logic.dart` / `lib/domain/models/{building,town_state,construction_event,town_stage_event,rocket_launch_event}.dart` 削除 | ✅ |
| 6.4 | `lib/constants/{town_stages,building_definitions,town_atmosphere}.dart` 削除 | ✅ |
| 6.5 | `lib/widgets/town/` ディレクトリ削除 | ✅ |
| 6.6 | 対応する旧テストファイル削除 | ✅ |
| 6.7 | README / requirements.md / tech-stack.md / ai-implementation-spec.md 更新 | ✅ |
| 6.8 | `flutter analyze` / `flutter test` 全パス確認 | ✅ （analyze: No issues found、test: 94件全パス） |

**完了条件** → [仕様書 §Phase 6](companion-spec.md#phase-6-旧町コードの削除仕上げ)

---

## 6. データ移行方針（重要）

既存ユーザーの「歩いて貯めたエネルギー」は一切失われないようにする。

| 保存データ | 扱い |
|-----------|------|
| `battery_stored_wh` / `lifetime_energy_wh` / `pending_batteries` | **無変更**（キー名・意味とも維持） |
| `town_buildings`（建物リスト） | 初回起動時に1度だけ読み取り、house→meal・powerPlant→booster・park→toy の**個数**を `companion_*_count` に変換して引き継ぐ（座標・建設順は破棄） |
| `town_celebrated_stage_ids` | 引き継がない。`companion_celebrated_stage_ids` が未設定の場合、移行後の給餌数から到達済み段階を再計算し「演出済み」として保存する（既存の Phase 4 マイグレーションと同じ考え方） |
| `achievement_events` | 引き継がない（実績IDが総入れ替えのため）。`companion_achievement_events` として新規に記録開始 |
| `rocket_launch_events` / `town_stage_events` | 引き継がない（新規 `sparkle_events` / `companion_stage_events` として記録開始） |
| `town_name` | 引き継がない（相棒の名前は別概念のため空から開始） |

## 7. 技術・品質の共通ルール

- Flame 等は導入しない。Flutter 標準アニメーションのみ
- 見た目だけの状態は永続化しない（例外: 演出済み段階・相棒名など明示したもののみ）
- コア数値（発電変換式・蓄電池容量・満タン判定）は変更しない
- 新規ウィジェットは `lib/widgets/companion/` に置く
- 時刻・乱数は注入可能にしてテストする
- 各 Phase 完了時: `flutter analyze` / `flutter test` 全パス

## 8. 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-07-30 | 初版作成。町ビルド機能を白紙にし、相棒育成モードへの置き換えを計画 |
| 2026-07-30 | Phase 1〜6 実装完了。町関連コードを全削除し、相棒育成モードに全面移行。`flutter analyze` No issues found / `flutter test` 94件全パスを確認 |
| 2026-07-31 | 現行コードに合わせてストア掲載・公開手順・実装仕様・tech-stack を再同期 |
