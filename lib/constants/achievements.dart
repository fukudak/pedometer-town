import 'package:flutter/material.dart';

import '../domain/models/building.dart';
import '../domain/models/town_state.dart';

/// 実績の定義
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool Function(TownState town, int rocketLaunches) isUnlocked;

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
      id: 'first_house',
      title: '最初の住宅',
      description: '初めて住宅を建てた',
      icon: Icons.house,
      isUnlocked: (town, launches) =>
          town.buildings.any((b) => b.type == BuildingType.house),
    ),
    Achievement(
      id: 'first_power_plant',
      title: '電力供給開始',
      description: '初めて発電所を建てた',
      icon: Icons.bolt,
      isUnlocked: (town, launches) =>
          town.buildings.any((b) => b.type == BuildingType.powerPlant),
    ),
    Achievement(
      id: 'first_park',
      title: '緑のある暮らし',
      description: '初めて公園を建てた',
      icon: Icons.park,
      isUnlocked: (town, launches) =>
          town.buildings.any((b) => b.type == BuildingType.park),
    ),
    Achievement(
      id: 'ten_buildings',
      title: '発展する町',
      description: '建物が10棟に到達した',
      icon: Icons.location_city,
      isUnlocked: (town, launches) => town.townLevel >= 10,
    ),
    Achievement(
      id: 'first_rocket',
      title: '宇宙への第一歩',
      description: '初めてロケットを発射した',
      icon: Icons.rocket_launch,
      isUnlocked: (town, launches) => launches >= 1,
    ),
    Achievement(
      id: 'five_rockets',
      title: '宇宙開発の常連',
      description: 'ロケットを5回発射した',
      icon: Icons.rocket_launch,
      isUnlocked: (town, launches) => launches >= 5,
    ),
  ];

  static Achievement of(String id) => all.firstWhere((a) => a.id == id);
}
