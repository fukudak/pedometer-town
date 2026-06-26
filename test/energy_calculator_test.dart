import 'package:flutter_test/flutter_test.dart';
import 'package:pedometer_town/domain/energy_calculator.dart';

void main() {
  group('EnergyCalculator.calculateEnergyWh', () {
    test('70kg, 5km/h, 1000歩 → 1000.0 Wh', () {
      final result = EnergyCalculator.calculateEnergyWh(
        steps: 1000,
        weightKg: 70,
        speedKmh: 5,
      );
      expect(result, closeTo(1000.0, 1e-9));
    });

    test('84kg, 6km/h, 5000歩 → 7200.0 Wh', () {
      final result = EnergyCalculator.calculateEnergyWh(
        steps: 5000,
        weightKg: 84,
        speedKmh: 6,
      );
      expect(result, closeTo(7200.0, 1e-9));
    });

    test('0歩は0Whになる', () {
      final result = EnergyCalculator.calculateEnergyWh(
        steps: 0,
        weightKg: 70,
        speedKmh: 5,
      );
      expect(result, 0.0);
    });

    test('大量の歩数でも上限なく計算される（1日の上限は撤廃）', () {
      final result = EnergyCalculator.calculateEnergyWh(
        steps: 1000000,
        weightKg: 70,
        speedKmh: 5,
      );
      expect(result, closeTo(1000000.0, 1e-6));
    });
  });
}
