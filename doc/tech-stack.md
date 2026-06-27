# 万歩計タウン 技術スタック

**バージョン**: 1.0  
**日付**: 2026-06-27

---

## 確定スタック

| 項目 | 技術 | 備考 |
|------|------|------|
| フレームワーク | Flutter + Dart | SDK ^3.12.1 |
| 状態管理 | `provider` ^6.1.0 | ChangeNotifier ベース |
| ローカル保存 | `shared_preferences` ^2.3.0 | 全ゲームデータの永続化 |
| UI | Material Design 3 | Expressive テーマ（角丸・tonal カラー） |
| iOS 歩数 | `health` ^13.0.0 | HealthKit 経由 |
| Android 歩数 | `pedometer` ^4.2.0 | ハードウェアステップカウンターセンサー |
| Android 権限 | `permission_handler` ^12.0.3 | ACTIVITY_RECOGNITION |
| GPS 速度 | `geolocator` ^13.0.0 | 歩行速度計測（設定画面） |
| アイコン | `flutter_launcher_icons` ^0.14.3 | dev 依存 |

---

## プラットフォーム別の歩数取得

| OS | 方式 | 補足 |
|----|------|------|
| iOS | HealthKit（`health` パッケージ） | 今日 0:00〜現在の歩数合計 |
| Android | センサー直読み（`pedometer`） | 端末起動からの累積値をベースライン正規化して今日分を算出 |

---

## ディレクトリ構成（概要）

```
lib/
├── main.dart / app.dart
├── constants/     # 数値定数・建物定義・発展段階・実績
├── domain/        # 純粋ロジック・モデル
├── data/          # LocalStorage（SharedPreferences）
├── services/      # HealthService, SpeedMeasurementService
├── providers/     # Settings, Energy, Town, History
└── screens/       # Home, Town, History, Settings

doc/               # 設計・仕様ドキュメント
docs/              # ストア公開・プライバシーポリシー
test/              # ユニットテスト（仕様の正典の一部）
```

---

## 将来検討事項

- 状態管理の移行（Riverpod / Bloc）
- より高度な UI（CustomPainter / Flame）
- バックエンド導入の是非
