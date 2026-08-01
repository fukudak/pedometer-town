import 'package:flutter/material.dart';

import '../domain/models/feed_item_type.dart';

/// 改修アイテムの静的定義（コスト・表示名・アイコン・効果値）
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

  /// 配線キット1回あたりの蓄電池容量増加 (Wh)
  static const double boosterCapacityBonusWh = 2000.0;

  /// 設備アップ1回あたりのエネルギー係数倍率
  static const double toyCoefficientMultiplier = 1.1;

  static const Map<FeedItemType, FeedItemDefinition> all = {
    FeedItemType.meal: FeedItemDefinition(
      type: FeedItemType.meal,
      displayName: '建材',
      batteryCost: 1,
      icon: Icons.carpenter,
    ),
    FeedItemType.booster: FeedItemDefinition(
      type: FeedItemType.booster,
      displayName: '配線キット',
      batteryCost: 2,
      icon: Icons.electrical_services,
    ),
    FeedItemType.toy: FeedItemDefinition(
      type: FeedItemType.toy,
      displayName: '街灯アップ',
      batteryCost: 1,
      icon: Icons.lightbulb_outline,
    ),
  };

  static FeedItemDefinition of(FeedItemType type) => all[type]!;
}
