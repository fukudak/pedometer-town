import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pedometer_town/data/local_storage.dart';
import 'package:pedometer_town/domain/models/battery_state.dart';
import 'package:pedometer_town/domain/models/building.dart';
import 'package:pedometer_town/providers/energy_provider.dart';
import 'package:pedometer_town/providers/settings_provider.dart';
import 'package:pedometer_town/providers/town_provider.dart';
import 'package:pedometer_town/services/health_service.dart';

void main() {
  late LocalStorage storage;
  late SettingsProvider settingsProvider;
  late EnergyProvider energyProvider;
  late TownProvider townProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorage(await SharedPreferences.getInstance());
    settingsProvider = SettingsProvider(storage);
    energyProvider = EnergyProvider(storage, HealthService(), settingsProvider);
    townProvider = TownProvider(storage, energyProvider, settingsProvider);
  });

  group('TownProvider.buildBuilding', () {
    test('発電所を建設するとコスト分が消費され、容量が+2000Whされる', () async {
      await energyProvider.applyBatteryState(
        const BatteryState(storedWh: 1000, capacityWh: 10000),
      );

      final result =
          await townProvider.buildBuilding(BuildingType.powerPlant, 0, 0);

      expect(result, isTrue);
      expect(energyProvider.battery.storedWh, 0);
      expect(energyProvider.battery.capacityWh, 12000);
      expect(townProvider.town.buildings.length, 1);
      expect(townProvider.town.buildings.first.type, BuildingType.powerPlant);
    });

    test('エネルギー不足の場合は建設に失敗し状態は変化しない', () async {
      await energyProvider.applyBatteryState(
        const BatteryState(storedWh: 100, capacityWh: 10000),
      );

      final result = await townProvider.buildBuilding(BuildingType.house, 0, 0);

      expect(result, isFalse);
      expect(energyProvider.battery.storedWh, 100);
      expect(townProvider.town.buildings, isEmpty);
    });

    test('座標が既に埋まっている場合は建設に失敗する', () async {
      await energyProvider.applyBatteryState(
        const BatteryState(storedWh: 2000, capacityWh: 10000),
      );

      final first = await townProvider.buildBuilding(BuildingType.house, 1, 1);
      final second = await townProvider.buildBuilding(BuildingType.house, 1, 1);

      expect(first, isTrue);
      expect(second, isFalse);
      expect(townProvider.town.buildings.length, 1);
    });
  });

  group('TownProvider.canBuild', () {
    test('残量がコスト以上かつ座標が空いていれば建設可能と判定する', () async {
      await energyProvider.applyBatteryState(
        const BatteryState(storedWh: 500, capacityWh: 10000),
      );
      expect(townProvider.canBuild(BuildingType.house, 0, 0), isTrue);
    });

    test('残量がコスト未満なら建設不可と判定する', () async {
      await energyProvider.applyBatteryState(
        const BatteryState(storedWh: 100, capacityWh: 10000),
      );
      expect(townProvider.canBuild(BuildingType.house, 0, 0), isFalse);
    });
  });
}
