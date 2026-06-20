import 'package:flutter/material.dart';

/// 建物数に応じた町の発展段階
class TownStage {
  final String name;
  final IconData icon;
  final int minLevel;

  const TownStage({
    required this.name,
    required this.icon,
    required this.minLevel,
  });
}

class TownStages {
  TownStages._();

  static const List<TownStage> stages = [
    TownStage(name: '開拓地', icon: Icons.grass, minLevel: 0),
    TownStage(name: '村', icon: Icons.holiday_village, minLevel: 1),
    TownStage(name: '町', icon: Icons.location_city, minLevel: 4),
    TownStage(name: '都市', icon: Icons.apartment, minLevel: 8),
  ];

  /// 現在の建物数に対応する発展段階
  static TownStage forLevel(int level) {
    var current = stages.first;
    for (final stage in stages) {
      if (level >= stage.minLevel) current = stage;
    }
    return current;
  }

  /// 次の発展段階（最終段階なら null）
  static TownStage? next(int level) {
    for (final stage in stages) {
      if (level < stage.minLevel) return stage;
    }
    return null;
  }
}
