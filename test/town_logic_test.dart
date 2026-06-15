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
        Building(type: BuildingType.powerPlant),
      ]);
      expect(result, 12000);
    });

    test('発電所2棟なら+4000Wh', () {
      final result = TownLogic.effectiveCapacity(10000, const [
        Building(type: BuildingType.powerPlant),
        Building(type: BuildingType.powerPlant),
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
        Building(type: BuildingType.park),
      ]);
      expect(result, closeTo(0.011, 1e-12));
    });

    test('公園2棟なら×1.1×1.1', () {
      final result = TownLogic.effectiveCoefficient(0.01, const [
        Building(type: BuildingType.park),
        Building(type: BuildingType.park),
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
    test('残量がコスト以上なら建設可能', () {
      const battery = BatteryState(storedWh: 500, capacityWh: 10000);
      expect(TownLogic.canBuild(battery, BuildingType.house), isTrue);
    });

    test('残量がコスト未満なら建設不可', () {
      const battery = BatteryState(
        storedWh: 499,
        capacityWh: GameConstants.initialBatteryCapacityWh,
      );
      expect(TownLogic.canBuild(battery, BuildingType.house), isFalse);
    });
  });
}
