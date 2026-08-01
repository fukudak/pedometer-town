import 'package:flutter/material.dart';

import 'game_constants.dart';

/// 発展度に応じた町の段階（正面図）。
/// 家 → 街 → 工業化 → ロケット打ち上げまで育つ。
/// ロケット到達後は段階は固定で、人口・建物数だけが増え続ける。
class CompanionStage {
  final String id;
  final String name;
  final IconData? icon;
  final int minLevel;

  const CompanionStage({
    required this.id,
    required this.name,
    this.icon,
    required this.minLevel,
  });
}

class CompanionStages {
  CompanionStages._();

  static const List<CompanionStage> stages = [
    CompanionStage(id: 'egg', name: 'まっさらな土地', minLevel: 0),
    CompanionStage(id: 'crack', name: '小さな家', icon: Icons.cottage, minLevel: 1),
    CompanionStage(id: 'hatch', name: '電灯の村', icon: Icons.lightbulb, minLevel: 2),
    CompanionStage(id: 'kid', name: 'にぎわう街', icon: Icons.home_work, minLevel: 4),
    CompanionStage(id: 'charged', name: 'ビルの街', icon: Icons.apartment, minLevel: 7),
    CompanionStage(id: 'reliable', name: '工業地帯', icon: Icons.factory, minLevel: 10),
    CompanionStage(id: 'radiant', name: '宇宙基地', icon: Icons.satellite_alt, minLevel: 13),
    CompanionStage(id: 'star', name: 'ロケット打ち上げ', icon: Icons.rocket_launch, minLevel: 17),
  ];

  static CompanionStage forLevel(int level) {
    var current = stages.first;
    for (final stage in stages) {
      if (level >= stage.minLevel) current = stage;
    }
    return current;
  }

  static CompanionStage? next(int level) {
    for (final stage in stages) {
      if (level < stage.minLevel) return stage;
    }
    return null;
  }

  /// 次の段階までの残り建設回数と、到達時の町の様子。
  static ({
    CompanionStage stage,
    int remaining,
    int buildings,
    int population,
    String hint,
  })? nextMilestone(int level) {
    final next = CompanionStages.next(level);
    if (next == null) return null;
    final remaining = next.minLevel - level;
    final story = _hintFor(next.id);
    return (
      stage: next,
      remaining: remaining,
      buildings: TownStats.buildingCount(next.minLevel),
      population: TownStats.population(next.minLevel),
      hint: story,
    );
  }

  static String _hintFor(String stageId) {
    switch (stageId) {
      case 'crack':
        return '小さな家が建つ';
      case 'hatch':
        return '電灯がともり村になる';
      case 'kid':
        return '商店のある街になる';
      case 'charged':
        return '高層ビルが立ち並ぶ';
      case 'reliable':
        return '工場が現れ工業化する';
      case 'radiant':
        return '宇宙基地になる';
      case 'star':
        return 'ロケットが打ち上がる';
      default:
        return 'まちが次の姿になる';
    }
  }

  static bool isAtFinalStage(int level) => level >= stages.last.minLevel;

  /// ロケット到達後の追加成長量（0以上）。見た目の段階は変えず、数だけ増やす。
  static int postRocketGrowth(int level) {
    final last = stages.last.minLevel;
    return level <= last ? 0 : level - last;
  }

  static List<CompanionStage> reachedStages(int level) =>
      stages.where((stage) => level >= stage.minLevel).toList();

  static int sparkleCount(int level) {
    if (!isAtFinalStage(level)) return 0;
    final beyond = level - stages.last.minLevel;
    return 1 + beyond ~/ GameConstants.sparkleMomentInterval;
  }
}

/// 発展度から導出する町の人口・建物数。
class TownStats {
  TownStats._();

  /// 建物数（ロケット到達後も発展度に応じて増え続ける）
  static int buildingCount(int level) {
    if (level <= 0) return 0;
    const marks = <(int, int)>[
      (1, 1),
      (2, 3),
      (4, 8),
      (7, 18),
      (10, 32),
      (13, 48),
      (17, 72),
    ];
    if (level >= 17) {
      return 72 + (level - 17) * 5;
    }
    for (var i = marks.length - 1; i >= 0; i--) {
      if (level >= marks[i].$1) {
        if (i == marks.length - 1 || level == marks[i].$1) {
          return marks[i].$2;
        }
        final (l0, b0) = marks[i];
        final (l1, b1) = marks[i + 1];
        final t = (level - l0) / (l1 - l0);
        return (b0 + (b1 - b0) * t).round();
      }
    }
    return marks.first.$2;
  }

  /// 人口（建物の密集度が発展とともに上がる）
  static int population(int level) {
    if (level <= 0) return 0;
    final buildings = buildingCount(level);
    final density = level < 4
        ? 4
        : level < 7
            ? 10
            : level < 10
                ? 20
                : level < 13
                    ? 40
                    : level < 17
                        ? 70
                        : 100 + (level - 17) * 8;
    return buildings * density;
  }
}
