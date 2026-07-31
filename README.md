# 万歩計タウン

歩いて発電し、蓄電した電気で相棒を育てる万歩計アプリ。歩数から発電したエネルギーを蓄電池に溜め、満タンになった蓄電池を相棒に与えて育てます。

## 主な機能

- **歩数連動の発電** — iOS（HealthKit）/ Android（ハードウェアセンサー）から歩数を取得し、体重・速度・係数を考慮してエネルギー(Wh)に変換
- **蓄電池と相棒育成** — 蓄電池が満タンになるとストックされ、相棒画面で消費してごはん（ごはん・げんきの素・おもちゃ）を与える
- **進化段階** — なつき度（給餌回数）に応じて相棒の姿が変化（でんきのたまご → 星のように輝く）
- **きげん** — 直近の給餌からの経過時間で相棒のきげんが変化
- **GPS 歩行速度計測** — 設定画面から実際の歩行速度を計測し、発電計算に反映
- **履歴** — 日次の歩数・発電量、蓄電池満タン、きらめきタイム、実績解除の記録
- **カスタム設定** — 体重・歩行速度・発電変換係数・相棒の名前を調整可能

## 画面構成

| 画面 | 内容 |
|------|------|
| ホーム | 蓄電池・今日の歩数/発電量（起動時・復帰時に自動同期） |
| 相棒 | 進化段階・きげん・満タン蓄電池の消費（給餌）・愛着スコア |
| 履歴 | 過去の記録とイベント一覧 |
| 設定 | 体重・速度・発電係数・GPS 速度計測・相棒の名前 |

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
| [doc/companion-plan.md](doc/companion-plan.md) | 相棒育成モードへの置き換え 全体計画と進捗 |
| [doc/companion-spec.md](doc/companion-spec.md) | 相棒育成モードの AI 実装仕様・テストケース |

過去の「町ビルド」機能（現在は廃止）の設計記録は
[doc/town-atmosphere-plan.md](doc/town-atmosphere-plan.md) / [doc/town-atmosphere-spec.md](doc/town-atmosphere-spec.md) に残しています。

## ストア公開準備

公開に向けた進捗・チェックリストは [docs/store-release-checklist.md](docs/store-release-checklist.md)、
具体的な操作手順は [docs/release-procedures.md](docs/release-procedures.md) を参照してください。
プライバシーポリシーは [docs/privacy.html](docs/privacy.html) で公開しています。
