import '../constants/game_constants.dart';

/// 移動エネルギーの算出（純粋関数）
class EnergyCalculator {
  EnergyCalculator._();

  /// 歩数差分から Wh を計算する。
  ///
  /// `energyWh = steps × (weightKg / 70) × (speedKmh / 5) × coefficient`
  ///
  /// 結果は [GameConstants.dailyEnergyCapWh] でキャップする。
  static double calculateEnergyWh({
    required int steps,
    required double weightKg,
    required double speedKmh,
    double coefficient = GameConstants.energyCoefficient,
  }) {
    final raw = steps *
        (weightKg / GameConstants.referenceWeightKg) *
        (speedKmh / GameConstants.referenceSpeedKmh) *
        coefficient;
    return raw.clamp(0.0, GameConstants.dailyEnergyCapWh);
  }

  /// 当日既存エネルギー [alreadyEarnedTodayWh] を考慮し、
  /// 追加可能な Wh を返す（0以上、1日上限を超えない）。
  static double clampDailyEnergy({
    required double newEnergyWh,
    required double alreadyEarnedTodayWh,
  }) {
    final remaining =
        GameConstants.dailyEnergyCapWh - alreadyEarnedTodayWh;
    if (remaining <= 0) {
      return 0.0;
    }
    return newEnergyWh.clamp(0.0, remaining);
  }
}
