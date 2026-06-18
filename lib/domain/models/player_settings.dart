import '../../constants/game_constants.dart';

/// プレイヤー設定（体重・歩行速度・発電変換係数）
class PlayerSettings {
  final double weightKg;
  final double defaultSpeedKmh;
  final double energyCoefficient;

  const PlayerSettings({
    this.weightKg = GameConstants.defaultWeightKg,
    this.defaultSpeedKmh = GameConstants.defaultSpeedKmh,
    this.energyCoefficient = GameConstants.energyCoefficient,
  });

  static bool isValidWeight(double weightKg) =>
      weightKg >= GameConstants.minWeightKg &&
      weightKg <= GameConstants.maxWeightKg;

  static bool isValidSpeed(double speedKmh) =>
      speedKmh >= GameConstants.minSpeedKmh &&
      speedKmh <= GameConstants.maxSpeedKmh;

  static bool isValidCoefficient(double coefficient) =>
      coefficient >= GameConstants.minEnergyCoefficient &&
      coefficient <= GameConstants.maxEnergyCoefficient;

  PlayerSettings copyWith({
    double? weightKg,
    double? defaultSpeedKmh,
    double? energyCoefficient,
  }) {
    return PlayerSettings(
      weightKg: weightKg ?? this.weightKg,
      defaultSpeedKmh: defaultSpeedKmh ?? this.defaultSpeedKmh,
      energyCoefficient: energyCoefficient ?? this.energyCoefficient,
    );
  }
}
