import 'package:flutter/material.dart';

/// 発展度に応じた「夜の星の灯り」段階。
/// 暗い星 → 都市の光帯 → 大陸が輝く → 軌道から見た星、と育つ。
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
    CompanionStage(id: 'egg', name: '暗い星', minLevel: 0),
    CompanionStage(id: 'spark', name: '最初の灯り', icon: Icons.nightlight, minLevel: 1),
    CompanionStage(id: 'flicker', name: '小さな灯り', icon: Icons.wb_incandescent, minLevel: 2),
    CompanionStage(id: 'hamlet', name: '集落の灯り', icon: Icons.home_work, minLevel: 3),
    CompanionStage(id: 'village', name: '村の灯り', icon: Icons.lightbulb, minLevel: 4),
    CompanionStage(id: 'crossroads', name: '灯りの村道', icon: Icons.route, minLevel: 6),
    CompanionStage(id: 'town', name: '小さな街', icon: Icons.storefront, minLevel: 8),
    CompanionStage(id: 'district', name: '街の光帯', icon: Icons.location_city, minLevel: 10),
    CompanionStage(id: 'suburb', name: '郊外へ広がる灯り', icon: Icons.holiday_village, minLevel: 12),
    CompanionStage(id: 'metro', name: '大きな街が灯る', icon: Icons.business, minLevel: 15),
    CompanionStage(id: 'megacity', name: '大都市が輝く', icon: Icons.apartment, minLevel: 18),
    CompanionStage(id: 'region', name: '広がる都市圏', icon: Icons.domain, minLevel: 21),
    CompanionStage(id: 'corridor', name: '地方を結ぶ光の道', icon: Icons.alt_route, minLevel: 24),
    CompanionStage(id: 'continent', name: '大陸の光網', icon: Icons.public, minLevel: 28),
    CompanionStage(id: 'farshore', name: '大陸を越える灯り', icon: Icons.language, minLevel: 32),
    CompanionStage(id: 'nightland', name: '夜の大陸が輝く', icon: Icons.terrain, minLevel: 36),
    CompanionStage(id: 'hemisphere', name: '半球が輝く', icon: Icons.brightness_2, minLevel: 40),
    CompanionStage(id: 'radiant', name: '夜の星が浮かぶ', icon: Icons.travel_explore, minLevel: 45),
    CompanionStage(id: 'luminous', name: '満天の灯り', icon: Icons.nights_stay, minLevel: 50),
    CompanionStage(id: 'star', name: '軌道から見た星', icon: Icons.satellite_alt, minLevel: 55),
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
      case 'spark':
        return '地表に最初の灯りがともる';
      case 'flicker':
        return '灯りがもうひとつ増える';
      case 'hamlet':
        return '小さな集落に灯りが集まる';
      case 'village':
        return '村の灯りが夜を照らす';
      case 'crossroads':
        return '村をつなぐ道に灯りが伸びる';
      case 'town':
        return '小さな街灯りが並ぶ';
      case 'district':
        return '街の光帯が線になって見える';
      case 'suburb':
        return '郊外まで灯りが広がる';
      case 'metro':
        return '大きな街が夜に浮かぶ';
      case 'megacity':
        return '大都市圏が白く輝く';
      case 'region':
        return '都市圏が広がり続ける';
      case 'corridor':
        return '地方をつなぐ光の道ができる';
      case 'continent':
        return '大陸を横断する光の網が見える';
      case 'farshore':
        return '大陸を越えて灯りが届く';
      case 'nightland':
        return '夜の大陸全体が輝く';
      case 'hemisphere':
        return '半球全体に灯りが満ちる';
      case 'radiant':
        return '夜の星のかたちがはっきり浮かぶ';
      case 'luminous':
        return '満天の灯りが夜を埋め尽くす';
      case 'star':
        return '軌道から見た夜の星になる';
      default:
        return '星の灯りが広がる';
    }
  }

  /// 現在の発展度が全stages.length段階中の何段階目か（1-based）。
  static int stageNumber(int level) => stages.indexOf(forLevel(level)) + 1;

  static bool isAtFinalStage(int level) => level >= stages.last.minLevel;

  /// 最終段階到達後の追加成長量（0以上）。見た目の段階は変えず、数だけ増やす。
  static int postRocketGrowth(int level) {
    final last = stages.last.minLevel;
    return level <= last ? 0 : level - last;
  }

  /// 最終段階到達後に積み上がる「完成した地球」の数。
  /// 最終段階に到達した時点で1個目が完成し、以降は最終段階到達に必要だった
  /// 投入回数と同じ回数だけ追加投入するたびに1個ずつ増える。
  static int earthCount(int level) {
    if (!isAtFinalStage(level)) return 0;
    final cycle = stages.last.minLevel;
    return 1 + postRocketGrowth(level) ~/ cycle;
  }

  /// 次の地球が完成するまでの残り投入回数（最終段階未到達なら null）。
  static int? remainingForNextEarth(int level) {
    if (!isAtFinalStage(level)) return null;
    final cycle = stages.last.minLevel;
    final progress = postRocketGrowth(level) % cycle;
    return cycle - progress;
  }

  static List<CompanionStage> reachedStages(int level) =>
      stages.where((stage) => level >= stage.minLevel).toList();
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
      (3, 5),
      (4, 8),
      (6, 12),
      (8, 17),
      (10, 22),
      (12, 28),
      (15, 36),
      (18, 45),
      (21, 54),
      (24, 63),
      (28, 75),
      (32, 87),
      (36, 99),
      (40, 110),
      (45, 122),
      (50, 133),
      (55, 145),
    ];
    if (level >= 55) {
      return 145 + (level - 55) * 5;
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
    final density = level < 13
        ? 4
        : level < 23
            ? 10
            : level < 32
                ? 20
                : level < 42
                    ? 40
                    : level < 55
                        ? 70
                        : 100 + (level - 55) * 8;
    return buildings * density;
  }
}
