import 'package:flutter/material.dart';

import 'game_constants.dart';

/// 発展度に応じた「夜の地球の灯り」段階。
/// 暗い地球 → 都市の光帯 → 大陸が輝く → 軌道から見た地球、と育つ。
/// 最終段階到達後は見た目の段階は固定で、灯りの密度（統計）だけ増え続ける。
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
    CompanionStage(id: 'egg', name: '暗い地球', minLevel: 0),
    CompanionStage(id: 'crack', name: '最初の灯り', icon: Icons.nightlight, minLevel: 1),
    CompanionStage(id: 'hatch', name: '村の灯り', icon: Icons.lightbulb, minLevel: 2),
    CompanionStage(id: 'kid', name: '街の光帯', icon: Icons.location_city, minLevel: 4),
    CompanionStage(id: 'charged', name: '大都市が輝く', icon: Icons.apartment, minLevel: 7),
    CompanionStage(id: 'reliable', name: '大陸の光網', icon: Icons.public, minLevel: 10),
    CompanionStage(id: 'radiant', name: '夜の地球が浮かぶ', icon: Icons.travel_explore, minLevel: 13),
    CompanionStage(id: 'star', name: '軌道から見た地球', icon: Icons.satellite_alt, minLevel: 17),
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

  /// 次の段階までの残り投入回数と、到達時の様子。
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
        return '地表に最初の灯りがともる';
      case 'hatch':
        return '小さな集落の灯りが点在する';
      case 'kid':
        return '街の光帯が線になって見える';
      case 'charged':
        return '大都市圏が白く輝く';
      case 'reliable':
        return '大陸を横断する光の網が見える';
      case 'radiant':
        return '夜の地球のかたちがはっきり浮かぶ';
      case 'star':
        return '軌道から見た夜の地球になる';
      default:
        return '地球の灯りが広がる';
    }
  }

  static bool isAtFinalStage(int level) => level >= stages.last.minLevel;

  /// 最終段階到達後の追加成長量（0以上）。見た目の段階は変えず、数だけ増やす。
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

/// 発展度から導出する「灯り都市」と「照らされた人口」の目安。
class TownStats {
  TownStats._();

  /// 灯り都市の数（最終段階後も発展度に応じて増え続ける）
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

  /// 照らされた人口の目安（灯りの密集度が発展とともに上がる）
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
