import 'package:flutter/material.dart';

import '../domain/models/feed_item_type.dart';

/// ごはんの静的定義（コスト・表示名・アイコン・効果値）
class FeedItemDefinition {
  final FeedItemType type;
  final String displayName;
  final int batteryCost;
  final IconData icon;

  const FeedItemDefinition({
    required this.type,
    required this.displayName,
    required this.batteryCost,
    required this.icon,
  });
}

class FeedItemDefinitions {
  FeedItemDefinitions._();

  /// げんきの素1回あたりの蓄電池容量増加 (Wh)
  static const double boosterCapacityBonusWh = 2000.0;

  /// おもちゃ1回あたりのエネルギー係数倍率
  static const double toyCoefficientMultiplier = 1.1;

  static const Map<FeedItemType, FeedItemDefinition> all = {
    FeedItemType.meal: FeedItemDefinition(
      type: FeedItemType.meal,
      displayName: 'ごはん',
      batteryCost: 1,
      icon: Icons.restaurant,
    ),
    FeedItemType.booster: FeedItemDefinition(
      type: FeedItemType.booster,
      displayName: 'げんきの素',
      batteryCost: 2,
      icon: Icons.bolt,
    ),
    FeedItemType.toy: FeedItemDefinition(
      type: FeedItemType.toy,
      displayName: 'おもちゃ',
      batteryCost: 1,
      icon: Icons.toys,
    ),
  };

  static FeedItemDefinition of(FeedItemType type) => all[type]!;
}
