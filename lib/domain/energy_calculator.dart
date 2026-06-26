import '../constants/game_constants.dart';

/// 移動エネルギーの算出（純粋関数）
class EnergyCalculator {
  EnergyCalculator._();

  /// 歩数差分から Wh を計算する。1日の上限はなく、歩いた分だけ発電する。
  ///
  /// `energyWh = steps × (weightKg / 70) × (speedKmh / 5) × coefficient`
  static double calculateEnergyWh({
    required int steps,
    required double weightKg,
    required double speedKmh,
    double coefficient = GameConstants.energyCoefficient,
  }) {
    return steps *
        (weightKg / GameConstants.referenceWeightKg) *
        (speedKmh / GameConstants.referenceSpeedKmh) *
        coefficient;
  }
}
