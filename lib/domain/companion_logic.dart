import 'dart:math' as math;

import '../constants/feed_item_definitions.dart';
import 'models/companion_state.dart';

/// 相棒のきげん（直近の給餌からの経過時間で決まる）
enum CompanionMood { none, happy, normal, lonely }

/// 給餌の効果計算（純粋関数）
class CompanionLogic {
  CompanionLogic._();

  static const Duration happyThreshold = Duration(hours: 24);
  static const Duration normalThreshold = Duration(days: 3);

  /// げんきの素の回数に応じて蓄電池容量を加算する。
  static double effectiveCapacity(
    double baseCapacity,
    CompanionState companion,
  ) {
    return baseCapacity +
        companion.boosterCount * FeedItemDefinitions.boosterCapacityBonusWh;
  }

  /// おもちゃの回数に応じてエネルギー係数を乗算する（累積乗算）。
  static double effectiveCoefficient(
    double baseCoefficient,
    CompanionState companion,
  ) {
    return baseCoefficient *
        math.pow(FeedItemDefinitions.toyCoefficientMultiplier, companion.toyCount);
  }

  /// なつき度レベル・累積発電量・きらめきタイム回数を合成した愛着スコア
  static int bondScore({
    required int level,
    required double lifetimeEnergyWh,
    required int sparkleMoments,
  }) {
    return level * 10 +
        (lifetimeEnergyWh / 100).floor() +
        sparkleMoments * 50;
  }

  /// 直近の給餌からの経過時間で相棒のきげんを判定する。
  static CompanionMood moodFor({
    required DateTime now,
    required DateTime? lastFedAt,
  }) {
    if (lastFedAt == null) return CompanionMood.none;
    final elapsed = now.difference(lastFedAt);
    if (elapsed <= happyThreshold) return CompanionMood.happy;
    if (elapsed <= normalThreshold) return CompanionMood.normal;
    return CompanionMood.lonely;
  }
}
