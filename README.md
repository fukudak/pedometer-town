# 万歩計タウン

歩いて発電し、町を育てるシミュレーションゲーム。歩数から発電したエネルギーを蓄電池に溜め、満タンになった蓄電池を使って町を発展させます。

## 主な機能

- **歩数連動の発電** — iOS（HealthKit）/ Android（ハードウェアセンサー）から歩数を取得し、体重・速度・係数を考慮してエネルギー(Wh)に変換
- **蓄電池と町の発展** — 蓄電池が満タンになるとストックされ、町画面で消費して建物（住宅・発電所・公園）が自動建設される
- **発展段階** — 建物数に応じて地平線が変化（豆電球 → 都市 → ロケット建設）
- **GPS 歩行速度計測** — 設定画面から実際の歩行速度を計測し、発電計算に反映
- **履歴** — 日次の歩数・発電量、蓄電池満タン、ロケット発射、実績解除の記録
- **カスタム設定** — 体重・歩行速度・発電変換係数を調整可能

## 画面構成

| 画面 | 内容 |
|------|------|
| ホーム | 蓄電池・今日の歩数/発電量（起動時・復帰時に自動同期） |
| 町 | 発展段階の地平線・満タン蓄電池の消費・人口・文明スコア |
| 履歴 | 過去の記録とイベント一覧 |
| 設定 | 体重・速度・発電係数・GPS 速度計測 |

## 開発

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## ドキュメント

| パス | 内容 |
|------|------|
| [doc/requirements.md](doc/requirements.md) | 要件定義 |
| [doc/tech-stack.md](doc/tech-stack.md) | 技術スタック |
| [doc/ai-implementation-spec.md](doc/ai-implementation-spec.md) | 実装仕様（数値・挙動の詳細） |

## ストア公開準備

公開に向けた進捗・チェックリストは [docs/store-release-checklist.md](docs/store-release-checklist.md)、
具体的な操作手順は [docs/release-procedures.md](docs/release-procedures.md) を参照してください。
プライバシーポリシーは [docs/privacy.html](docs/privacy.html) で公開しています。
