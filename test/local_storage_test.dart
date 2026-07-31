import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pedometer_town/constants/game_constants.dart';
import 'package:pedometer_town/data/local_storage.dart';
import 'package:pedometer_town/domain/models/achievement_event.dart';
import 'package:pedometer_town/domain/models/battery_state.dart';
import 'package:pedometer_town/domain/models/companion_state.dart';
import 'package:pedometer_town/domain/models/companion_stage_event.dart';
import 'package:pedometer_town/domain/models/daily_step_record.dart';
import 'package:pedometer_town/domain/models/full_battery_event.dart';
import 'package:pedometer_town/domain/models/player_settings.dart';
import 'package:pedometer_town/domain/models/sparkle_event.dart';

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
      expect(settings.companionWeatherFxEnabled, isTrue);
      expect(settings.companionName, '');
    });

    test('保存した値が読み込める', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      await storage.savePlayerSettings(
        const PlayerSettings(
          weightKg: 84,
          defaultSpeedKmh: 6.0,
          companionWeatherFxEnabled: false,
          companionName: 'ぴかり',
        ),
      );
      final loaded = storage.loadPlayerSettings();
      expect(loaded.weightKg, 84);
      expect(loaded.defaultSpeedKmh, 6.0);
      expect(loaded.companionWeatherFxEnabled, isFalse);
      expect(loaded.companionName, 'ぴかり');
    });
  });

  group('BatteryState', () {
    test('未保存時はデフォルト値を返す', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      final battery = storage.loadBatteryState(const CompanionState());
      expect(battery.storedWh, GameConstants.initialBatteryStoredWh);
      expect(battery.capacityWh, GameConstants.initialBatteryCapacityWh);
    });

    test('蓄積量は保存して復元できる', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      await storage.saveBatteryState(
        const BatteryState(storedWh: 123.5, capacityWh: 12000),
      );
      final loaded = storage.loadBatteryState(const CompanionState());
      expect(loaded.storedWh, 123.5);
    });

    test('容量は相棒の状態から算出される（げんきの素1回で+2000Wh）', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      const companion = CompanionState(boosterCount: 1);
      await storage.saveCompanionState(companion);
      final loaded = storage.loadBatteryState(companion);
      expect(loaded.capacityWh, GameConstants.initialBatteryCapacityWh + 2000);
    });
  });

  group('CompanionState', () {
    test('未保存時は全カウント0を返す', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      final companion = storage.loadCompanionState();
      expect(companion.level, 0);
    });

    test('保存して復元できる', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      const companion = CompanionState(mealCount: 2, boosterCount: 1, toyCount: 1);
      await storage.saveCompanionState(companion);
      final loaded = storage.loadCompanionState();
      expect(loaded.mealCount, 2);
      expect(loaded.boosterCount, 1);
      expect(loaded.toyCount, 1);
    });

    test('旧バージョンの町データ（house×2, powerPlant×1, park×1）から個数が移行される', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'town_buildings',
        '[{"type":"house","x":0,"y":0},{"type":"house","x":1,"y":0},'
        '{"type":"powerPlant","x":2,"y":0},{"type":"park","x":3,"y":0}]',
      );
      final storage = LocalStorage(prefs);

      final loaded = storage.loadCompanionState();

      expect(loaded.mealCount, 2);
      expect(loaded.boosterCount, 1);
      expect(loaded.toyCount, 1);
    });

    test('旧データが存在しない場合は移行されず全カウント0のまま', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      final loaded = storage.loadCompanionState();
      expect(loaded.mealCount, 0);
      expect(loaded.boosterCount, 0);
      expect(loaded.toyCount, 0);
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

    test('loadAllDailyRecords: 保存済みレコードを日付の新しい順に返す', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      await storage.saveDailyStepRecord(
        const DailyStepRecord(
            date: '2026-06-10',
            totalSteps: 100,
            totalEnergyWh: 1.0,
            lastSyncedSteps: 100),
      );
      await storage.saveDailyStepRecord(
        const DailyStepRecord(
            date: '2026-06-12',
            totalSteps: 300,
            totalEnergyWh: 3.0,
            lastSyncedSteps: 300),
      );
      await storage.saveDailyStepRecord(
        const DailyStepRecord(
            date: '2026-06-11',
            totalSteps: 200,
            totalEnergyWh: 2.0,
            lastSyncedSteps: 200),
      );

      final records = storage.loadAllDailyRecords();

      expect(records.map((r) => r.date).toList(),
          ['2026-06-12', '2026-06-11', '2026-06-10']);
    });

    test('deleteDailyRecord: 指定日の記録だけ削除される', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      await storage.saveDailyStepRecord(
        const DailyStepRecord(
            date: '2026-06-10',
            totalSteps: 100,
            totalEnergyWh: 1.0,
            lastSyncedSteps: 100),
      );
      await storage.saveDailyStepRecord(
        const DailyStepRecord(
            date: '2026-06-11',
            totalSteps: 200,
            totalEnergyWh: 2.0,
            lastSyncedSteps: 200),
      );

      await storage.deleteDailyRecord('2026-06-10');

      expect(storage.loadDailyStepRecord('2026-06-10').totalSteps, 0);
      expect(storage.loadDailyStepRecord('2026-06-11').totalSteps, 200);
    });

    test('clearAllDailyRecords: 全ての記録が削除される', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      await storage.saveDailyStepRecord(
        const DailyStepRecord(
            date: '2026-06-10',
            totalSteps: 100,
            totalEnergyWh: 1.0,
            lastSyncedSteps: 100),
      );
      await storage.saveDailyStepRecord(
        const DailyStepRecord(
            date: '2026-06-11',
            totalSteps: 200,
            totalEnergyWh: 2.0,
            lastSyncedSteps: 200),
      );

      await storage.clearAllDailyRecords();

      expect(storage.loadAllDailyRecords(), isEmpty);
    });
  });

  group('FullBatteryEvent', () {
    test('未保存時は空のリストを返す', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      expect(storage.loadFullBatteryEvents(), isEmpty);
    });

    test('保存して復元できる', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      const events = [
        FullBatteryEvent(number: 1, date: '2026-06-20'),
        FullBatteryEvent(number: 2, date: '2026-06-21'),
      ];

      await storage.saveFullBatteryEvents(events);
      final loaded = storage.loadFullBatteryEvents();

      expect(loaded.length, 2);
      expect(loaded[0].number, 1);
      expect(loaded[1].date, '2026-06-21');
    });
  });

  group('SparkleEvent', () {
    test('未保存時は空のリストを返す', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      expect(storage.loadSparkleEvents(), isEmpty);
    });

    test('保存して復元できる', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      const events = [
        SparkleEvent(number: 1, date: '2026-06-20'),
        SparkleEvent(number: 2, date: '2026-06-22'),
      ];

      await storage.saveSparkleEvents(events);
      final loaded = storage.loadSparkleEvents();

      expect(loaded.length, 2);
      expect(loaded[0].number, 1);
      expect(loaded[1].date, '2026-06-22');
    });
  });

  group('AchievementEvent', () {
    test('未保存時は空のリストを返す', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      expect(storage.loadAchievementEvents(), isEmpty);
    });

    test('保存して復元できる', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      const events = [
        AchievementEvent(id: 'first_meal', date: '2026-06-20'),
        AchievementEvent(id: 'first_sparkle', date: '2026-06-22'),
      ];

      await storage.saveAchievementEvents(events);
      final loaded = storage.loadAchievementEvents();

      expect(loaded.length, 2);
      expect(loaded[0].id, 'first_meal');
      expect(loaded[1].date, '2026-06-22');
    });
  });

  group('Companion stage celebration', () {
    test('未保存時の演出済み段階IDは null を返す（未マイグレーション）', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      expect(storage.loadCelebratedStageIds(), isNull);
    });

    test('演出済み段階IDを保存して復元できる', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      await storage.saveCelebratedStageIds(['crack', 'hatch']);

      final loaded = storage.loadCelebratedStageIds();
      expect(loaded, isNotNull);
      expect(loaded, containsAll(['crack', 'hatch']));
    });

    test('相棒の進化段階履歴を保存して復元できる', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      const events = [
        CompanionStageEvent(stageId: 'crack', date: '2026-07-13'),
        CompanionStageEvent(stageId: 'hatch', date: '2026-07-14'),
      ];
      await storage.saveCompanionStageEvents(events);

      final loaded = storage.loadCompanionStageEvents();
      expect(loaded.length, 2);
      expect(loaded.first.stageId, 'crack');
      expect(loaded.last.date, '2026-07-14');
    });
  });

  group('companion_last_fed_at', () {
    test('未保存時は null を返す', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      expect(storage.loadCompanionLastFedAt(), isNull);
    });

    test('保存して復元できる', () async {
      final storage = LocalStorage(await SharedPreferences.getInstance());
      final time = DateTime(2026, 7, 30, 10, 0);
      await storage.saveCompanionLastFedAt(time);

      expect(storage.loadCompanionLastFedAt(), time);
    });
  });
}
