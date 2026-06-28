import 'dart:math' as math;

import '../constants/building_definitions.dart';
import '../constants/game_constants.dart';
import 'models/building.dart';

/// 建設・効果計算（純粋関数）
class TownLogic {
  TownLogic._();

  /// 発電所の数に応じて蓄電池容量を加算する。
  static double effectiveCapacity(
    double baseCapacity,
    List<Building> buildings,
  ) {
    final powerPlantCount =
        buildings.where((b) => b.type == BuildingType.powerPlant).length;
    return baseCapacity +
        powerPlantCount * BuildingDefinitions.powerPlantCapacityBonusWh;
  }

  /// 公園の数に応じてエネルギー係数を乗算する（累積乗算）。
  static double effectiveCoefficient(
    double baseCoefficient,
    List<Building> buildings,
  ) {
    final parkCount =
        buildings.where((b) => b.type == BuildingType.park).length;
    return baseCoefficient *
        math.pow(BuildingDefinitions.parkCoefficientMultiplier, parkCount);
  }

  /// 建物から算出される人口
  static int totalPopulation(List<Building> buildings) {
    return buildings
        .map((b) => BuildingDefinitions.of(b.type).population)
        .fold(0, (sum, p) => sum + p);
  }

  /// 棟数・累積発電量・ロケット発射数を合成した文明スコア
  static int civilizationScore({
    required List<Building> buildings,
    required double lifetimeEnergyWh,
    required int rocketLaunches,
  }) {
    return buildings.length * 10 +
        (lifetimeEnergyWh / 100).floor() +
        rocketLaunches * 50;
  }

  /// 指定座標に既に建物があるかどうか
  static bool isOccupied(List<Building> buildings, int x, int y) {
    return buildings.any((b) => b.x == x && b.y == y);
  }

  /// 指定座標が草原グリッドの範囲内かどうか
  static bool isWithinGrid(int x, int y) {
    return x >= 0 &&
        x < GameConstants.townGridSize &&
        y >= 0 &&
        y < GameConstants.townGridSize;
  }
}
