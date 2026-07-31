import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pedometer_town/data/local_storage.dart';
import 'package:pedometer_town/domain/models/battery_state.dart';
import 'package:pedometer_town/domain/models/feed_item_type.dart';
import 'package:pedometer_town/providers/companion_provider.dart';
import 'package:pedometer_town/providers/energy_provider.dart';
import 'package:pedometer_town/providers/settings_provider.dart';
import 'package:pedometer_town/services/health_service.dart';

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

  group('CompanionProvider.feedAuto', () {
    test('1回分与えるとなつき度が1増え、種類は meal から順に割り当てられる', () async {
      await companionProvider.feedAuto(1);

      expect(companionProvider.companion.level, 1);
      expect(companionProvider.companion.mealCount, 1);
    });

    test('3回分与えると meal, booster, toy の順に割り当てられる', () async {
      await companionProvider.feedAuto(3);

      expect(companionProvider.companion.mealCount, 1);
      expect(companionProvider.companion.boosterCount, 1);
      expect(companionProvider.companion.toyCount, 1);
    });

    test('booster を与えると蓄電池容量が+2000Whされる', () async {
      await energyProvider.applyBatteryState(
        const BatteryState(storedWh: 0, capacityWh: 10000),
      );

      await companionProvider.feedAuto(2); // meal, booster

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

  group('CompanionProvider きらめきタイム履歴', () {
    test('初きらめき発生日を取得できる', () async {
      await companionProvider.feedAuto(17);
      final today = DateTime.now();
      final expectedDate =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      expect(companionProvider.firstSparkleDate, isNotNull);
      expect(companionProvider.firstSparkleDate, expectedDate);
    });

    test('最終進化段階(なつき度17)に到達するときらめき履歴が1件記録される', () async {
      await companionProvider.feedAuto(17);

      final events = storage.loadSparkleEvents();
      expect(events.length, 1);
      expect(events.first.number, 1);
    });

    test('最終進化段階到達後、interval回ごとにきらめき回数が増える', () async {
      await companionProvider.feedAuto(19); // 17 + 2 (interval)

      final events = storage.loadSparkleEvents();
      expect(events.length, 2);
    });
  });

  group('CompanionProvider 愛着スコア', () {
    test('愛着スコアはなつき度・累積発電量・きらめき回数から算出される', () async {
      await companionProvider.feedAuto(1);
      expect(companionProvider.bondScore, 10); // なつき度1×10
    });
  });

  group('CompanionProvider 実績', () {
    test('最初のごはんをあげると実績が1件解除される', () async {
      await companionProvider.feedAuto(1);

      expect(companionProvider.pendingCelebrations.length, 1);
      expect(companionProvider.pendingCelebrations.first.id, 'first_meal');

      final events = storage.loadAchievementEvents();
      expect(events.length, 1);
      expect(events.first.id, 'first_meal');
    });

    test('clearPendingCelebrations 後はキューが空になる', () async {
      await companionProvider.feedAuto(1);
      companionProvider.clearPendingCelebrations();

      expect(companionProvider.pendingCelebrations, isEmpty);
    });

    test('同じ実績は二重に解除されない', () async {
      await companionProvider.feedAuto(1);
      companionProvider.clearPendingCelebrations();

      await companionProvider.feedAuto(1); // booster が与えられるだけ

      expect(
        companionProvider.pendingCelebrations.any((a) => a.id == 'first_meal'),
        isFalse,
      );
    });

    test('最終進化段階(なつき度17)で初めてのきらめき実績が解除される', () async {
      await companionProvider.feedAuto(17);

      final events = storage.loadAchievementEvents();
      expect(events.any((e) => e.id == 'first_sparkle'), isTrue);
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
}
