import 'package:flutter/material.dart';

import 'game_constants.dart';

/// 建物数に応じた町の発展段階。icon が null の段階（最初の「何もない地平線」）は
/// まだ何も建っていない状態を表す。
class TownStage {
  final String name;
  final IconData? icon;
  final int minLevel;

  const TownStage({
    required this.name,
    this.icon,
    required this.minLevel,
  });
}

class TownStages {
  TownStages._();

  static const List<TownStage> stages = [
    TownStage(name: '何もない地平線', minLevel: 0),
    TownStage(name: '豆電球がつく', icon: Icons.lightbulb, minLevel: 1),
    TownStage(name: '電灯がつく', icon: Icons.wb_incandescent, minLevel: 2),
    TownStage(name: '家の明かりが付く', icon: Icons.house, minLevel: 4),
    TownStage(name: '工場が稼働する', icon: Icons.factory, minLevel: 7),
    TownStage(name: '街が広がる', icon: Icons.holiday_village, minLevel: 10),
    TownStage(name: '都市になる', icon: Icons.apartment, minLevel: 13),
    TownStage(name: 'ロケット建設する', icon: Icons.rocket_launch, minLevel: 17),
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

  /// 最終段階（ロケット建設）に到達しているかどうか
  static bool isAtFinalStage(int level) => level >= stages.last.minLevel;

  /// ロケット建設段階に到達後、何回ロケットを発射したか
  /// （到達直後に1回目が発射され、以降 [GameConstants.rocketLaunchInterval] 棟ごとに1回増える）
  static int rocketLaunchCount(int level) {
    if (!isAtFinalStage(level)) return 0;
    final beyond = level - stages.last.minLevel;
    return 1 + beyond ~/ GameConstants.rocketLaunchInterval;
  }
}
