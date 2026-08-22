import 'package:flutter/material.dart';

import '../domain/models/companion_state.dart';

/// 実績の定義
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool Function(CompanionState companion) isUnlocked;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
  });
}

class Achievements {
  Achievements._();

  static final List<Achievement> all = [
    Achievement(
      id: 'first_meal',
      title: 'はじめての投入',
      description: '初めて電池を投入した',
      icon: Icons.battery_charging_full,
      isUnlocked: (companion) => companion.level >= 1,
    ),
    Achievement(
      id: 'first_booster',
      title: '電力が回りはじめた',
      description: '合計5回投入した',
      icon: Icons.bolt,
      isUnlocked: (companion) => companion.level >= 5,
    ),
    Achievement(
      id: 'first_toy',
      title: '灯りが広がりはじめた',
      description: '発展度2に到達した',
      icon: Icons.lightbulb,
      isUnlocked: (companion) => companion.level >= 2,
    ),
    Achievement(
      id: 'ten_feeds',
      title: '夜の星が輝く',
      description: '合計10回投入した',
      icon: Icons.public,
      isUnlocked: (companion) => companion.level >= 10,
    ),
  ];

  static Achievement of(String id) => all.firstWhere((a) => a.id == id);
}
