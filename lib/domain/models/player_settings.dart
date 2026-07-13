import '../../constants/game_constants.dart';

/// プレイヤー設定（体重・歩行速度・発電変換係数）
class PlayerSettings {
  final double weightKg;
  final double defaultSpeedKmh;
  final double energyCoefficient;
  final bool townWeatherFxEnabled;
  final String townName;

  const PlayerSettings({
    this.weightKg = GameConstants.defaultWeightKg,
    this.defaultSpeedKmh = GameConstants.defaultSpeedKmh,
    this.energyCoefficient = GameConstants.energyCoefficient,
    this.townWeatherFxEnabled = true,
    this.townName = 'わたしの町',
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
    bool? townWeatherFxEnabled,
    String? townName,
  }) {
    return PlayerSettings(
      weightKg: weightKg ?? this.weightKg,
      defaultSpeedKmh: defaultSpeedKmh ?? this.defaultSpeedKmh,
      energyCoefficient: energyCoefficient ?? this.energyCoefficient,
      townWeatherFxEnabled:
          townWeatherFxEnabled ?? this.townWeatherFxEnabled,
      townName: townName ?? this.townName,
    );
  }
}
