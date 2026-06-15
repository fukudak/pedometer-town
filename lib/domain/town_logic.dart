import 'dart:math' as math;

import '../constants/building_definitions.dart';
import 'models/battery_state.dart';
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

  /// 建物の建設コスト (Wh)
  static double costOf(BuildingType type) =>
      BuildingDefinitions.of(type).costWh;

  /// 現在の蓄電池残量で建設可能かどうか
  static bool canBuild(BatteryState battery, BuildingType type) {
    return battery.storedWh >= costOf(type);
  }
}
