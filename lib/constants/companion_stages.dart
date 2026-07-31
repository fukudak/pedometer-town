import 'package:flutter/material.dart';

import 'game_constants.dart';

/// なつき度レベルに応じた相棒の進化段階。icon が null の段階（最初の「でんきのたまご」）は
/// まだ孵化していない状態を表す。
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
    CompanionStage(id: 'egg', name: 'でんきのたまご', minLevel: 0),
    CompanionStage(id: 'crack', name: 'たまごがひかりだす', icon: Icons.egg, minLevel: 1),
    CompanionStage(id: 'hatch', name: '相棒が生まれた', icon: Icons.emoji_emotions, minLevel: 2),
    CompanionStage(id: 'kid', name: '元気に動き回る', icon: Icons.directions_run, minLevel: 4),
    CompanionStage(id: 'charged', name: '力がみなぎる', icon: Icons.flash_on, minLevel: 7),
    CompanionStage(id: 'reliable', name: '頼れる相棒になった', icon: Icons.shield, minLevel: 10),
    CompanionStage(id: 'radiant', name: '光をまといはじめた', icon: Icons.auto_awesome, minLevel: 13),
    CompanionStage(id: 'star', name: '星のように輝く', icon: Icons.stars, minLevel: 17),
  ];

  /// 現在のなつき度レベルに対応する進化段階
  static CompanionStage forLevel(int level) {
    var current = stages.first;
    for (final stage in stages) {
      if (level >= stage.minLevel) current = stage;
    }
    return current;
  }

  /// 次の進化段階（最終段階なら null）
  static CompanionStage? next(int level) {
    for (final stage in stages) {
      if (level < stage.minLevel) return stage;
    }
    return null;
  }

  /// 最終進化段階（星）に到達しているかどうか
  static bool isAtFinalStage(int level) => level >= stages.last.minLevel;

  static List<CompanionStage> reachedStages(int level) =>
      stages.where((stage) => level >= stage.minLevel).toList();

  /// 最終進化段階に到達後、何回きらめきタイムが発生したか
  /// （到達直後に1回目が発生し、以降 [GameConstants.sparkleMomentInterval] 回ごとに1回増える）
  static int sparkleCount(int level) {
    if (!isAtFinalStage(level)) return 0;
    final beyond = level - stages.last.minLevel;
    return 1 + beyond ~/ GameConstants.sparkleMomentInterval;
  }
}
