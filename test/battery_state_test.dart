import 'package:flutter_test/flutter_test.dart';
import 'package:pedometer_town/constants/game_constants.dart';
import 'package:pedometer_town/domain/models/battery_state.dart';

void main() {
  group('BatteryState.initial', () {
    test('初期蓄積は0、初期容量は10000Wh', () {
      final battery = BatteryState.initial();
      expect(battery.storedWh, GameConstants.initialBatteryStoredWh);
      expect(battery.capacityWh, GameConstants.initialBatteryCapacityWh);
    });
  });

  group('BatteryState.addEnergy', () {
    test('容量内であれば加算され、満タンにはならない', () {
      const battery = BatteryState(storedWh: 100, capacityWh: 1000);
      final result = battery.addEnergy(50);
      expect(result.state.storedWh, 150);
      expect(result.state.capacityWh, 1000);
      expect(result.batteriesFilled, 0);
    });

    test('ちょうど容量に達すると満タン1回・残量は0に折り返る', () {
      const battery = BatteryState(storedWh: 950, capacityWh: 1000);
      final result = battery.addEnergy(50);
      expect(result.state.storedWh, 0);
      expect(result.batteriesFilled, 1);
    });

    test('容量を超えた分は次の蓄電池の蓄積として残る', () {
      const battery = BatteryState(storedWh: 950, capacityWh: 1000);
      final result = battery.addEnergy(100);
      expect(result.state.storedWh, closeTo(50, 1e-9));
      expect(result.batteriesFilled, 1);
    });

    test('1回の加算で複数回満タンになる場合も正しく折り返る', () {
      const battery = BatteryState(storedWh: 0, capacityWh: 1000);
      final result = battery.addEnergy(2500);
      expect(result.state.storedWh, closeTo(500, 1e-9));
      expect(result.batteriesFilled, 2);
    });
  });

  group('BatteryState.consumeEnergy', () {
    test('残量が十分なら成功し減算される', () {
      const battery = BatteryState(storedWh: 1000, capacityWh: 1000);
      final result = battery.consumeEnergy(300);
      expect(result.success, isTrue);
      expect(result.state.storedWh, 700);
    });

    test('残量不足なら失敗し状態は変化しない', () {
      const battery = BatteryState(storedWh: 100, capacityWh: 1000);
      final result = battery.consumeEnergy(300);
      expect(result.success, isFalse);
      expect(result.state.storedWh, 100);
    });
  });
}
