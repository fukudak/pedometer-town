# 万歩計タウン

歩いて発電し、町を育てるシミュレーションゲーム。歩数から発電したエネルギーを使って草原に建物を建設し、町を発展させます。

## 主な機能

- iOS（HealthKit）/ Android（ハードウェアセンサー）から歩数を取得し、エネルギーに変換
- 5×5の草原グリッドに住宅・発電所・公園を配置して町を発展させる
- GPS による歩行速度の計測
- 過去の歩数・発電量の履歴表示
- 体重・歩行速度・発電変換係数のカスタム設定

## 開発

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## ストア公開準備

公開に向けた進捗・チェックリストは [docs/store-release-checklist.md](docs/store-release-checklist.md)、
具体的な操作手順は [docs/release-procedures.md](docs/release-procedures.md) を参照してください。
プライバシーポリシーは [docs/privacy.html](docs/privacy.html) で公開しています。
