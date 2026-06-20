import 'package:flutter_test/flutter_test.dart';
import 'package:pedometer_town/constants/game_constants.dart';
import 'package:pedometer_town/domain/models/battery_state.dart';
import 'package:pedometer_town/domain/models/building.dart';
import 'package:pedometer_town/domain/town_logic.dart';

void main() {
  group('TownLogic.effectiveCapacity', () {
    test('発電所がなければベース容量のまま', () {
      final result = TownLogic.effectiveCapacity(10000, const []);
      expect(result, 10000);
    });

    test('発電所1棟につき+2000Wh', () {
      final result = TownLogic.effectiveCapacity(10000, const [
        Building(type: BuildingType.powerPlant, x: 0, y: 0),
      ]);
      expect(result, 12000);
    });

    test('発電所2棟なら+4000Wh', () {
      final result = TownLogic.effectiveCapacity(10000, const [
        Building(type: BuildingType.powerPlant, x: 0, y: 0),
        Building(type: BuildingType.powerPlant, x: 0, y: 0),
      ]);
      expect(result, 14000);
    });
  });

  group('TownLogic.effectiveCoefficient', () {
    test('公園がなければベース係数のまま', () {
      final result = TownLogic.effectiveCoefficient(0.01, const []);
      expect(result, closeTo(0.01, 1e-12));
    });

    test('公園1棟につき×1.1', () {
      final result = TownLogic.effectiveCoefficient(0.01, const [
        Building(type: BuildingType.park, x: 0, y: 0),
      ]);
      expect(result, closeTo(0.011, 1e-12));
    });

    test('公園2棟なら×1.1×1.1', () {
      final result = TownLogic.effectiveCoefficient(0.01, const [
        Building(type: BuildingType.park, x: 0, y: 0),
        Building(type: BuildingType.park, x: 1, y: 0),
      ]);
      expect(result, closeTo(0.01 * 1.1 * 1.1, 1e-12));
    });
  });

  group('TownLogic.costOf', () {
    test('住宅は500Wh', () {
      expect(TownLogic.costOf(BuildingType.house), 500.0);
    });

    test('発電所は1000Wh', () {
      expect(TownLogic.costOf(BuildingType.powerPlant), 1000.0);
    });

    test('公園は800Wh', () {
      expect(TownLogic.costOf(BuildingType.park), 800.0);
    });
  });

  group('TownLogic.canBuild', () {
    test('残量がコスト以上かつ座標が空いていれば建設可能', () {
      const battery = BatteryState(storedWh: 500, capacityWh: 10000);
      expect(
        TownLogic.canBuild(battery, BuildingType.house, const [], 0, 0),
        isTrue,
      );
    });

    test('残量がコスト未満なら建設不可', () {
      const battery = BatteryState(
        storedWh: 499,
        capacityWh: GameConstants.initialBatteryCapacityWh,
      );
      expect(
        TownLogic.canBuild(battery, BuildingType.house, const [], 0, 0),
        isFalse,
      );
    });

    test('座標が既に埋まっていれば残量があっても建設不可', () {
      const battery = BatteryState(storedWh: 500, capacityWh: 10000);
      const buildings = [Building(type: BuildingType.house, x: 0, y: 0)];
      expect(
        TownLogic.canBuild(battery, BuildingType.house, buildings, 0, 0),
        isFalse,
      );
    });

    test('座標がグリッド範囲外（負の値）なら残量があっても建設不可', () {
      const battery = BatteryState(storedWh: 500, capacityWh: 10000);
      expect(
        TownLogic.canBuild(battery, BuildingType.house, const [], -1, 0),
        isFalse,
      );
    });

    test('座標がグリッド範囲外（上限超過）なら残量があっても建設不可', () {
      const battery = BatteryState(storedWh: 500, capacityWh: 10000);
      expect(
        TownLogic.canBuild(
          battery,
          BuildingType.house,
          const [],
          GameConstants.townGridSize,
          0,
        ),
        isFalse,
      );
    });
  });

  group('TownLogic.isWithinGrid', () {
    test('範囲内の座標は true', () {
      expect(TownLogic.isWithinGrid(0, 0), isTrue);
      expect(
        TownLogic.isWithinGrid(
          GameConstants.townGridSize - 1,
          GameConstants.townGridSize - 1,
        ),
        isTrue,
      );
    });

    test('負の座標は false', () {
      expect(TownLogic.isWithinGrid(-1, 0), isFalse);
      expect(TownLogic.isWithinGrid(0, -1), isFalse);
    });

    test('グリッドサイズ以上の座標は false', () {
      expect(TownLogic.isWithinGrid(GameConstants.townGridSize, 0), isFalse);
      expect(TownLogic.isWithinGrid(0, GameConstants.townGridSize), isFalse);
    });
  });

  group('TownLogic.isOccupied', () {
    test('座標に建物があれば true', () {
      const buildings = [Building(type: BuildingType.house, x: 2, y: 3)];
      expect(TownLogic.isOccupied(buildings, 2, 3), isTrue);
      expect(TownLogic.isOccupied(buildings, 0, 0), isFalse);
    });
  });
}
