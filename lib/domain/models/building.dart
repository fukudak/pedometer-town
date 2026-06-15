/// 建物の種類（Phase 2 MVP 3種）
enum BuildingType { house, powerPlant, park }

/// 建設済みの建物
class Building {
  final BuildingType type;
  final int level;

  const Building({required this.type, this.level = 1});

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'level': level,
      };

  factory Building.fromJson(Map<String, dynamic> json) => Building(
        type: BuildingType.values.byName(json['type'] as String),
        level: json['level'] as int,
      );
}
