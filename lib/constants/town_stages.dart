import 'package:flutter/material.dart';

import 'game_constants.dart';

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
    TownStage(name: 'たき火', icon: Icons.local_fire_department, minLevel: 0),
    TownStage(name: '小さな家', icon: Icons.cottage, minLevel: 1),
    TownStage(name: '大きな家', icon: Icons.home_work, minLevel: 3),
    TownStage(name: '工場', icon: Icons.factory, minLevel: 6),
    TownStage(name: '発電所', icon: Icons.bolt, minLevel: 9),
    TownStage(name: 'ロケット建造', icon: Icons.rocket_launch, minLevel: 13),
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

  /// 最終段階（ロケット建造）に到達しているかどうか
  static bool isAtFinalStage(int level) => level >= stages.last.minLevel;

  /// ロケット建造段階に到達後、何回ロケットを発射したか
  /// （到達直後に1回目が発射され、以降 [GameConstants.rocketLaunchInterval] 棟ごとに1回増える）
  static int rocketLaunchCount(int level) {
    if (!isAtFinalStage(level)) return 0;
    final beyond = level - stages.last.minLevel;
    return 1 + beyond ~/ GameConstants.rocketLaunchInterval;
  }
}
