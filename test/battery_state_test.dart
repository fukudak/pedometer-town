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
    test('容量内であれば加算される', () {
      const battery = BatteryState(storedWh: 100, capacityWh: 1000);
      final result = battery.addEnergy(50);
      expect(result.storedWh, 150);
      expect(result.capacityWh, 1000);
    });

    test('容量を超える分はロストする', () {
      const battery = BatteryState(storedWh: 950, capacityWh: 1000);
      final result = battery.addEnergy(100);
      expect(result.storedWh, 1000);
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
