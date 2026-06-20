import 'building.dart';

/// 町全体の状態
class TownState {
  final List<Building> buildings;

  const TownState({this.buildings = const []});

  factory TownState.initial() => const TownState();

  /// 建物数に連動する町レベル
  int get townLevel => buildings.length;

  TownState copyWith({List<Building>? buildings}) {
    return TownState(buildings: buildings ?? this.buildings);
  }

  TownState addBuilding(Building building) {
    return copyWith(buildings: [...buildings, building]);
  }

  /// 指定座標に建設済みの建物があれば返す。
  Building? buildingAt(int x, int y) {
    for (final b in buildings) {
      if (b.x == x && b.y == y) return b;
    }
    return null;
  }

  List<Map<String, dynamic>> toJson() =>
      buildings.map((b) => b.toJson()).toList();

  factory TownState.fromJson(List<dynamic> json) => TownState(
        buildings: json
            .map((e) => Building.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
