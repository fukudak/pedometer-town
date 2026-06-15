import 'package:flutter_test/flutter_test.dart';
import 'package:pedometer_town/constants/game_constants.dart';
import 'package:pedometer_town/domain/energy_calculator.dart';

void main() {
  group('EnergyCalculator.calculateEnergyWh', () {
    test('70kg, 5km/h, 1000歩 → 10.0 Wh', () {
      final result = EnergyCalculator.calculateEnergyWh(
        steps: 1000,
        weightKg: 70,
        speedKmh: 5,
      );
      expect(result, closeTo(10.0, 1e-9));
    });

    test('84kg, 6km/h, 5000歩 → 72.0 Wh', () {
      final result = EnergyCalculator.calculateEnergyWh(
        steps: 5000,
        weightKg: 84,
        speedKmh: 6,
      );
      expect(result, closeTo(72.0, 1e-9));
    });

    test('0歩は0Whになる', () {
      final result = EnergyCalculator.calculateEnergyWh(
        steps: 0,
        weightKg: 70,
        speedKmh: 5,
      );
      expect(result, 0.0);
    });

    test('1日の上限(5000Wh)でキャップされる', () {
      final result = EnergyCalculator.calculateEnergyWh(
        steps: 1000000,
        weightKg: 70,
        speedKmh: 5,
      );
      expect(result, GameConstants.dailyEnergyCapWh);
    });
  });

  group('EnergyCalculator.clampDailyEnergy', () {
    test('当日蓄積が0なら上限まで丸ごと加算可能', () {
      final result = EnergyCalculator.clampDailyEnergy(
        newEnergyWh: 100.0,
        alreadyEarnedTodayWh: 0.0,
      );
      expect(result, 100.0);
    });

    test('上限に近い場合は残り分のみ加算可能', () {
      final result = EnergyCalculator.clampDailyEnergy(
        newEnergyWh: 100.0,
        alreadyEarnedTodayWh: 4950.0,
      );
      expect(result, closeTo(50.0, 1e-9));
    });

    test('すでに上限到達済みなら0', () {
      final result = EnergyCalculator.clampDailyEnergy(
        newEnergyWh: 100.0,
        alreadyEarnedTodayWh: GameConstants.dailyEnergyCapWh,
      );
      expect(result, 0.0);
    });
  });
}
