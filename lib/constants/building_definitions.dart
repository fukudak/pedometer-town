import 'package:flutter/material.dart';

import '../domain/models/building.dart';

/// 建物の静的定義（コスト・表示名・アイコン・効果値）
class BuildingDefinition {
  final BuildingType type;
  final String displayName;
  final double costWh;
  final IconData icon;

  const BuildingDefinition({
    required this.type,
    required this.displayName,
    required this.costWh,
    required this.icon,
  });
}

class BuildingDefinitions {
  BuildingDefinitions._();

  /// 発電所1棟あたりの蓄電池容量増加 (Wh)
  static const double powerPlantCapacityBonusWh = 2000.0;

  /// 公園1棟あたりのエネルギー係数倍率
  static const double parkCoefficientMultiplier = 1.1;

  static const Map<BuildingType, BuildingDefinition> all = {
    BuildingType.house: BuildingDefinition(
      type: BuildingType.house,
      displayName: '住宅',
      costWh: 500.0,
      icon: Icons.house,
    ),
    BuildingType.powerPlant: BuildingDefinition(
      type: BuildingType.powerPlant,
      displayName: '発電所',
      costWh: 1000.0,
      icon: Icons.bolt,
    ),
    BuildingType.park: BuildingDefinition(
      type: BuildingType.park,
      displayName: '公園',
      costWh: 800.0,
      icon: Icons.park,
    ),
  };

  static BuildingDefinition of(BuildingType type) => all[type]!;
}
