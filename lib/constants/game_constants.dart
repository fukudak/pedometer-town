/// 万歩計タウン 数値定数（仕様書 ai-implementation-spec.md §3 準拠）
class GameConstants {
  GameConstants._();

  /// 発電変換係数（歩数→エネルギー変換の基準倍率）
  /// 基準体重・速度では 1歩 = 1Wh、1万歩で蓄電池1個分(初期容量10000Wh)を満たす。
  static const double energyCoefficient = 1.0;
  static const double minEnergyCoefficient = 0.1;
  static const double maxEnergyCoefficient = 5.0;

  /// 体重の基準値 (kg)
  static const double referenceWeightKg = 70.0;

  /// 速度の基準値 (km/h)
  static const double referenceSpeedKmh = 5.0;

  /// 体重の制約
  static const double minWeightKg = 30.0;
  static const double maxWeightKg = 200.0;
  static const double defaultWeightKg = 70.0;

  /// デフォルト速度の制約
  static const double minSpeedKmh = 0.5;
  static const double maxSpeedKmh = 15.0;
  static const double defaultSpeedKmh = 5.0;

  /// アプリのバージョン文字列（pubspec.yaml の version と合わせて管理）
  static const String appVersion = '0.9';

  /// 1日のエネルギー上限 (Wh)。蓄電池の初期容量(1万歩分)と一致させる。
  static const double dailyEnergyCapWh = 10000.0;

  /// 蓄電池 初期容量 (Wh)
  static const double initialBatteryCapacityWh = 10000.0;

  /// 蓄電池 初期蓄積量 (Wh)
  static const double initialBatteryStoredWh = 0.0;

  /// 草原グリッドの一辺のマス数（建物の座標管理に使用。画面表示はしない）
  static const int townGridSize = 5;

  /// ロケット建造段階に到達後、何棟ごとに1回ロケットが発射されるか
  static const int rocketLaunchInterval = 2;
}
