import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pedometer_town/data/local_storage.dart';
import 'package:pedometer_town/domain/models/battery_state.dart';
import 'package:pedometer_town/domain/models/companion_state.dart';
import 'package:pedometer_town/domain/models/feed_item_type.dart';
import 'package:pedometer_town/providers/companion_provider.dart';
import 'package:pedometer_town/providers/energy_provider.dart';
import 'package:pedometer_town/providers/settings_provider.dart';
import 'package:pedometer_town/services/health_service.dart';

/// [LocalStorage.saveCompanionState] だけが失敗する状況を再現するフェイク
/// （投入処理の途中失敗時のロールバックを検証するため）。
class _ThrowingCompanionSaveStorage extends LocalStorage {
  _ThrowingCompanionSaveStorage(super.prefs);

  @override
  Future<void> saveCompanionState(CompanionState companion) async {
    throw Exception('保存失敗（テスト用）');
  }
}

void main() {
  late LocalStorage storage;
  late SettingsProvider settingsProvider;
  late EnergyProvider energyProvider;
  late CompanionProvider companionProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorage(await SharedPreferences.getInstance());
    settingsProvider = SettingsProvider(storage);
    energyProvider = EnergyProvider(storage, HealthService(), settingsProvider);
    companionProvider = CompanionProvider(storage, energyProvider, settingsProvider);
  });

  /// 実際のUIと同じく meal を n 回投入する（feedAuto の代替）。
  Future<void> feedMealTimes(int n) async {
    for (var i = 0; i < n; i++) {
      await companionProvider.feedChosen(FeedItemType.meal);
    }
  }

  group('CompanionProvider 給餌種別の効果', () {
    test('booster を与えると蓄電池容量が+2000Whされる', () async {
      await energyProvider.applyBatteryState(
        const BatteryState(storedWh: 0, capacityWh: 10000),
      );

      await companionProvider.feedChosen(FeedItemType.booster);

      expect(energyProvider.battery.capacityWh, 12000);
    });
  });

  group('CompanionProvider 給餌イベント', () {
    test('feedChosen 成功後に pendingFeedEvent がセットされる', () async {
      await companionProvider.feedChosen(FeedItemType.meal);

      expect(companionProvider.pendingFeedEvent, isNotNull);
      expect(companionProvider.pendingFeedEvent!.type, FeedItemType.meal);
    });

    test('clearFeedEvent 後は null になる', () async {
      await companionProvider.feedChosen(FeedItemType.meal);
      companionProvider.clearFeedEvent();

      expect(companionProvider.pendingFeedEvent, isNull);
    });

    test('何度与えても失敗しない（上限なし）', () async {
      for (var i = 0; i < 30; i++) {
        await companionProvider.feedChosen(FeedItemType.meal);
      }
      expect(companionProvider.companion.mealCount, 30);
    });
  });

  group('CompanionProvider 愛着スコア', () {
    test('愛着スコアはなつき度・累積発電量から算出される', () async {
      await feedMealTimes(1);
      expect(companionProvider.bondScore, 10); // なつき度1×10
    });
  });

  group('CompanionProvider 実績', () {
    test('最初のごはんをあげると実績が1件解除される', () async {
      await feedMealTimes(1);

      expect(companionProvider.pendingCelebrations.length, 1);
      expect(companionProvider.pendingCelebrations.first.id, 'first_meal');

      final events = storage.loadAchievementEvents();
      expect(events.length, 1);
      expect(events.first.id, 'first_meal');
    });

    test('clearPendingCelebrations 後はキューが空になる', () async {
      await feedMealTimes(1);
      companionProvider.clearPendingCelebrations();

      expect(companionProvider.pendingCelebrations, isEmpty);
    });

    test('同じ実績は二重に解除されない', () async {
      await feedMealTimes(1);
      companionProvider.clearPendingCelebrations();

      await feedMealTimes(1); // 2回目の meal 投入

      expect(
        companionProvider.pendingCelebrations.any((a) => a.id == 'first_meal'),
        isFalse,
      );
    });
  });

  group('CompanionProvider 進化段階祝福', () {
    test('level 0→1 で stage celebration が pending になり保存される', () async {
      await companionProvider.feedChosen(FeedItemType.meal);

      expect(companionProvider.pendingStageCelebrations.length, 1);
      expect(companionProvider.pendingStageCelebrations.first.id, 'crack');
      expect(companionProvider.isStageCelebrated('crack'), isTrue);
      expect(storage.loadCompanionStageEvents().length, 1);
    });

    test('旧町データ（house×4,powerPlant×3,park×3=10）からの移行後は過去分の段階祝福は pending にならない', () async {
      SharedPreferences.setMockInitialValues({
        'town_buildings': '[{"type":"house","x":0,"y":0},{"type":"powerPlant","x":1,"y":0},{"type":"park","x":2,"y":0},{"type":"house","x":3,"y":0},{"type":"powerPlant","x":4,"y":0},{"type":"park","x":0,"y":1},{"type":"house","x":1,"y":1},{"type":"powerPlant","x":2,"y":1},{"type":"park","x":3,"y":1},{"type":"house","x":4,"y":1}]',
      });
      final migratedStorage = LocalStorage(await SharedPreferences.getInstance());
      final migratedSettings = SettingsProvider(migratedStorage);
      final migratedEnergy = EnergyProvider(
        migratedStorage,
        HealthService(),
        migratedSettings,
      );
      final migrated = CompanionProvider(migratedStorage, migratedEnergy, migratedSettings);

      expect(migrated.companion.level, 10);
      expect(migrated.pendingStageCelebrations, isEmpty);
      expect(migrated.isStageCelebrated('crack'), isTrue);
      expect(migrated.isStageCelebrated('reliable'), isTrue);
    });
  });

  group('CompanionProvider.investBattery', () {
    test('ストックが無ければ何もせず false を返す', () async {
      final invested = await companionProvider.investBattery();

      expect(invested, isFalse);
      expect(companionProvider.companion.level, 0);
    });

    test('正常時はストックと発展度がそれぞれ正確に1変化する', () async {
      await energyProvider.creditStockedBatteries(3);

      final invested = await companionProvider.investBattery();

      expect(invested, isTrue);
      expect(companionProvider.companion.level, 1);
      expect(energyProvider.pendingBatteries, 2);
    });

    test('ストック1個で投入を連続実行しても発展度は1だけ増える', () async {
      await energyProvider.creditStockedBatteries(1);

      final results = await Future.wait([
        companionProvider.investBattery(),
        companionProvider.investBattery(),
      ]);

      expect(results.where((succeeded) => succeeded).length, 1);
      expect(companionProvider.companion.level, 1);
      expect(energyProvider.pendingBatteries, 0);
    });

    test('発展更新に失敗した場合、ストックも発展度も変化しない', () async {
      SharedPreferences.setMockInitialValues({});
      final throwingStorage =
          _ThrowingCompanionSaveStorage(await SharedPreferences.getInstance());
      final throwingSettings = SettingsProvider(throwingStorage);
      final throwingEnergy =
          EnergyProvider(throwingStorage, HealthService(), throwingSettings);
      final throwingCompanion =
          CompanionProvider(throwingStorage, throwingEnergy, throwingSettings);
      await throwingEnergy.creditStockedBatteries(1);

      await expectLater(throwingCompanion.investBattery(), throwsException);

      expect(throwingCompanion.companion.level, 0);
      expect(throwingEnergy.pendingBatteries, 1);
    });
  });
}
