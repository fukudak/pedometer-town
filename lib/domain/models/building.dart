/// 建物の種類（Phase 2 MVP 3種）
enum BuildingType { house, powerPlant, park }

/// 建設済みの建物
class Building {
  final BuildingType type;

  const Building({required this.type});

  Map<String, dynamic> toJson() => {'type': type.name};

  factory Building.fromJson(Map<String, dynamic> json) => Building(
        type: BuildingType.values.byName(json['type'] as String),
      );
}
