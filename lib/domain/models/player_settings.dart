import '../../constants/game_constants.dart';

/// プレイヤー設定（体重・デフォルト速度）
class PlayerSettings {
  final double weightKg;
  final double defaultSpeedKmh;

  const PlayerSettings({
    this.weightKg = GameConstants.defaultWeightKg,
    this.defaultSpeedKmh = GameConstants.defaultSpeedKmh,
  });

  static bool isValidWeight(double weightKg) =>
      weightKg >= GameConstants.minWeightKg &&
      weightKg <= GameConstants.maxWeightKg;

  static bool isValidSpeed(double speedKmh) =>
      speedKmh >= GameConstants.minSpeedKmh &&
      speedKmh <= GameConstants.maxSpeedKmh;

  PlayerSettings copyWith({
    double? weightKg,
    double? defaultSpeedKmh,
  }) {
    return PlayerSettings(
      weightKg: weightKg ?? this.weightKg,
      defaultSpeedKmh: defaultSpeedKmh ?? this.defaultSpeedKmh,
    );
  }
}
