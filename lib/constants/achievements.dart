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
      title: 'はじめてのごはん',
      description: '初めてごはんをあげた',
      icon: Icons.restaurant,
      isUnlocked: (companion, sparkleMoments) => companion.mealCount >= 1,
    ),
    Achievement(
      id: 'first_booster',
      title: 'げんきの素デビュー',
      description: '初めてげんきの素をあげた',
      icon: Icons.bolt,
      isUnlocked: (companion, sparkleMoments) => companion.boosterCount >= 1,
    ),
    Achievement(
      id: 'first_toy',
      title: '一緒に遊ぶ道具',
      description: '初めておもちゃをあげた',
      icon: Icons.toys,
      isUnlocked: (companion, sparkleMoments) => companion.toyCount >= 1,
    ),
    Achievement(
      id: 'ten_feeds',
      title: 'すっかりなついた',
      description: '合計10回お世話した',
      icon: Icons.favorite,
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
