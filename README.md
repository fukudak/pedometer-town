# 万歩計タウン

歩いて発電し、蓄電した電気で夜の地球に灯りをともす万歩計アプリ。ISS から見た夜の地球をイメージし、正面は常に夜側・地球は自転し、投入するほど街の明かりが増えます。

## 主な機能

- **歩数連動の発電** — iOS（HealthKit）/ Android（ハードウェアセンサー）から歩数を取得し、体重・速度・係数を考慮してエネルギー(Wh)に変換
- **蓄電池と地球への投入** — 蓄電池が満タンになるとストックされ、まち画面の「投入」で1個消費して地球の灯りが広がる
- **夜の地球儀** — 正面は夜側、ゆっくり自転。電力が増えると街の明かりが増える（NASA ISS / Black Marble 由来）
- **稼働状態** — 直近の投入からの経過時間で灯りの雰囲気が変化
- **GPS 歩行速度計測** — 設定画面から実際の歩行速度を計測し、発電計算に反映
- **履歴** — 日次の歩数・発電量の記録
- **カスタム設定** — 体重・歩行速度・発電変換係数・まちの名前を調整可能

## 画面構成

| 画面 | 内容 |
|------|------|
| ホーム | 蓄電池・今日の歩数/発電量（起動時・復帰時に自動同期） |
| まち | 夜の地球儀・電池投入・まちスコア |
| 履歴 | 日次の歩数・発電量 |
| 設定 | 体重・速度・発電係数・GPS 速度計測・まちの名前 |

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

過去の計画書（旧町ビルド・相棒育成への移行など）は [doc/archive/](doc/archive/) に保管しています。

## ストア公開準備

公開に向けた進捗・チェックリストは [docs/store-release-checklist.md](docs/store-release-checklist.md)、
具体的な操作手順は [docs/release-procedures.md](docs/release-procedures.md) を参照してください。
プライバシーポリシーは [docs/privacy.html](docs/privacy.html) で公開しています。
