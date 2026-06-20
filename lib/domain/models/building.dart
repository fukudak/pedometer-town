/// 建物の種類（Phase 2 MVP 3種）
enum BuildingType { house, powerPlant, park }

/// 建設済みの建物（草原グリッド上の座標 x, y を持つ）
class Building {
  final BuildingType type;
  final int x;
  final int y;

  const Building({required this.type, required this.x, required this.y});

  Map<String, dynamic> toJson() => {'type': type.name, 'x': x, 'y': y};

  factory Building.fromJson(Map<String, dynamic> json) => Building(
        type: BuildingType.values.byName(json['type'] as String),
        x: json['x'] as int,
        y: json['y'] as int,
      );
}
