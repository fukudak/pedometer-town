/// 万歩計タウン 数値定数（仕様書 ai-implementation-spec.md §3 準拠）
class GameConstants {
  GameConstants._();

  /// 難易度係数（MVP: normal のみ）
  static const double energyCoefficient = 0.01;

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

  /// 1日のエネルギー上限 (Wh)
  static const double dailyEnergyCapWh = 5000.0;

  /// 蓄電池 初期容量 (Wh)
  static const double initialBatteryCapacityWh = 10000.0;

  /// 蓄電池 初期蓄積量 (Wh)
  static const double initialBatteryStoredWh = 0.0;
}
