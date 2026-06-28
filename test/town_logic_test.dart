import 'package:flutter_test/flutter_test.dart';
import 'package:pedometer_town/constants/game_constants.dart';
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
