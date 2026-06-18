import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pedometer_town/constants/game_constants.dart';
import 'package:pedometer_town/data/local_storage.dart';
import 'package:pedometer_town/domain/models/battery_state.dart';
import 'package:pedometer_town/domain/models/building.dart';
import 'package:pedometer_town/domain/models/daily_step_record.dart';
import 'package:pedometer_town/domain/models/player_settings.dart';
import 'package:pedometer_town/domain/models/town_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PlayerSettings', () {
    test('未保存時はデフォルト値を返す', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      final settings = storage.loadPlayerSettings();
      expect(settings.weightKg, GameConstants.defaultWeightKg);
      expect(settings.defaultSpeedKmh, GameConstants.defaultSpeedKmh);
      expect(settings.difficulty, GameConstants.defaultDifficulty);
    });

    test('保存した値が読み込める', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      await storage.savePlayerSettings(
        const PlayerSettings(
          weightKg: 84,
          defaultSpeedKmh: 6.0,
          difficulty: 'normal',
        ),
      );
      final loaded = storage.loadPlayerSettings();
      expect(loaded.weightKg, 84);
      expect(loaded.defaultSpeedKmh, 6.0);
      expect(loaded.difficulty, 'normal');
    });
  });

  group('BatteryState', () {
    test('未保存時はデフォルト値を返す', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      final battery = storage.loadBatteryState(const []);
      expect(battery.storedWh, GameConstants.initialBatteryStoredWh);
      expect(battery.capacityWh, GameConstants.initialBatteryCapacityWh);
    });

    test('蓄積量は保存して復元できる', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      await storage.saveBatteryState(
        const BatteryState(storedWh: 123.5, capacityWh: 12000),
      );
      final loaded = storage.loadBatteryState(const []);
      expect(loaded.storedWh, 123.5);
    });

    test('容量は建物リストから算出される（発電所1棟で+2000Wh）', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      const buildings = [Building(type: BuildingType.powerPlant)];
      await storage.saveTownState(const TownState(buildings: buildings));
      final loaded = storage.loadBatteryState(buildings);
      expect(loaded.capacityWh, GameConstants.initialBatteryCapacityWh + 2000);
    });
  });

  group('TownState', () {
    test('未保存時は空の町を返す', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      final town = storage.loadTownState();
      expect(town.buildings, isEmpty);
    });

    test('建物リストを保存して復元できる', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      const town = TownState(buildings: [
        Building(type: BuildingType.house),
        Building(type: BuildingType.powerPlant),
      ]);
      await storage.saveTownState(town);
      final loaded = storage.loadTownState();
      expect(loaded.buildings.length, 2);
      expect(loaded.buildings[0].type, BuildingType.house);
      expect(loaded.buildings[1].type, BuildingType.powerPlant);
    });
  });

  group('DailyStepRecord', () {
    test('未保存時は空のレコードを返す', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      final record = storage.loadDailyStepRecord('2026-06-15');
      expect(record.date, '2026-06-15');
      expect(record.totalSteps, 0);
      expect(record.totalEnergyWh, 0.0);
      expect(record.lastSyncedSteps, 0);
    });

    test('保存して復元できる(日付ごとに別キー)', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      const record = DailyStepRecord(
        date: '2026-06-15',
        totalSteps: 3000,
        totalEnergyWh: 30.0,
        lastSyncedSteps: 3000,
      );
      await storage.saveDailyStepRecord(record);

      final loaded = storage.loadDailyStepRecord('2026-06-15');
      expect(loaded.totalSteps, 3000);
      expect(loaded.totalEnergyWh, 30.0);
      expect(loaded.lastSyncedSteps, 3000);

      final other = storage.loadDailyStepRecord('2026-06-14');
      expect(other.totalSteps, 0);
    });
  });
}
