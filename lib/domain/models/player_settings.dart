import '../../constants/game_constants.dart';

/// プレイヤー設定（体重・デフォルト速度・難易度）
class PlayerSettings {
  final double weightKg;
  final double defaultSpeedKmh;
  final String difficulty;

  const PlayerSettings({
    this.weightKg = GameConstants.defaultWeightKg,
    this.defaultSpeedKmh = GameConstants.defaultSpeedKmh,
    this.difficulty = GameConstants.defaultDifficulty,
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
    String? difficulty,
  }) {
    return PlayerSettings(
      weightKg: weightKg ?? this.weightKg,
      defaultSpeedKmh: defaultSpeedKmh ?? this.defaultSpeedKmh,
      difficulty: difficulty ?? this.difficulty,
    );
  }
}
