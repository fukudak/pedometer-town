import 'package:flutter/material.dart';

import '../domain/models/companion_state.dart';

/// 実績の定義
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool Function(CompanionState companion, int sparkleMoments) isUnlocked;

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
      isUnlocked: (companion, sparkleMoments) => companion.level >= 1,
    ),
    Achievement(
      id: 'first_booster',
      title: '電力が回りはじめた',
      description: '合計5回投入した',
      icon: Icons.bolt,
      isUnlocked: (companion, sparkleMoments) => companion.level >= 5,
    ),
    Achievement(
      id: 'first_toy',
      title: 'まちが動きだした',
      description: '電灯の村に到達した',
      icon: Icons.lightbulb,
      isUnlocked: (companion, sparkleMoments) => companion.level >= 2,
    ),
    Achievement(
      id: 'ten_feeds',
      title: '立派なまち',
      description: '合計10回投入した',
      icon: Icons.location_city,
      isUnlocked: (companion, sparkleMoments) => companion.level >= 10,
    ),
    Achievement(
      id: 'first_sparkle',
      title: 'はじめてのきらめき',
      description: '初めてきらめきタイムが起きた',
      icon: Icons.auto_awesome,
      isUnlocked: (companion, sparkleMoments) => sparkleMoments >= 1,
    ),
    Achievement(
      id: 'five_sparkles',
      title: 'きらめきの常連',
      description: 'きらめきタイムを5回見た',
      icon: Icons.stars,
      isUnlocked: (companion, sparkleMoments) => sparkleMoments >= 5,
    ),
  ];

  static Achievement of(String id) => all.firstWhere((a) => a.id == id);
}
