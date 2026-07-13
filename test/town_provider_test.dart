import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pedometer_town/data/local_storage.dart';
import 'package:pedometer_town/domain/models/battery_state.dart';
import 'package:pedometer_town/domain/models/building.dart';
import 'package:pedometer_town/domain/models/town_state.dart';
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

  group('TownProvider.advanceTown', () {
    test('1回分発展すると建物が1棟増え、種類は house から順に割り当てられる', () async {
      await townProvider.advanceTown(1);

      expect(townProvider.town.buildings.length, 1);
      expect(townProvider.town.buildings.first.type, BuildingType.house);
    });

    test('3回分発展すると house, powerPlant, park の順に建つ', () async {
      await townProvider.advanceTown(3);

      final types = townProvider.town.buildings.map((b) => b.type).toList();
      expect(types, [
        BuildingType.house,
        BuildingType.powerPlant,
        BuildingType.park,
      ]);
    });

    test('powerPlant が建つと蓄電池容量が+2000Whされる', () async {
      await energyProvider.applyBatteryState(
        const BatteryState(storedWh: 0, capacityWh: 10000),
      );

      await townProvider.advanceTown(2); // house, powerPlant

      expect(energyProvider.battery.capacityWh, 12000);
    });

    test('同じ座標が重複しないよう自動で空き座標に配置される', () async {
      await townProvider.advanceTown(5);

      final positions = townProvider.town.buildings
          .map((b) => '${b.x},${b.y}')
          .toSet();
      expect(positions.length, 5);
    });
  });

  group('TownProvider 建設演出イベント', () {
    test('buildChosen 成功後に constructionEvent がセットされる', () async {
      final placed = await townProvider.buildChosen(BuildingType.house);

      expect(placed, isTrue);
      expect(townProvider.pendingConstructionEvent, isNotNull);
      expect(townProvider.pendingConstructionEvent!.type, BuildingType.house);
    });

    test('clearConstructionEvent 後は null になる', () async {
      await townProvider.buildChosen(BuildingType.house);
      townProvider.clearConstructionEvent();

      expect(townProvider.pendingConstructionEvent, isNull);
    });

    test('グリッド満杯時に buildChosen は false を返し event を立てない', () async {
      await townProvider.advanceTown(25);
      townProvider.clearConstructionEvent();

      final placed = await townProvider.buildChosen(BuildingType.house);
      expect(placed, isFalse);
      expect(townProvider.pendingConstructionEvent, isNull);
    });
  });

  group('TownProvider ロケット発射履歴', () {
    test('初ロケット発射日を取得できる', () async {
      await townProvider.advanceTown(17);
      final today = DateTime.now();
      final expectedDate =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      expect(townProvider.firstRocketLaunchDate, isNotNull);
      expect(townProvider.firstRocketLaunchDate, expectedDate);
    });

    test('ロケット建設段階(17棟目)に到達すると発射履歴が1件記録される', () async {
      await townProvider.advanceTown(17);

      final events = storage.loadRocketLaunchEvents();
      expect(events.length, 1);
      expect(events.first.number, 1);
    });

    test('ロケット建設段階到達後、interval棟ごとに発射回数が増える', () async {
      await townProvider.advanceTown(19); // 17 + 2 (interval)

      final events = storage.loadRocketLaunchEvents();
      expect(events.length, 2);
    });
  });

  group('TownProvider 人口・文明スコア', () {
    test('人口は house×4 + powerPlant×1 + park×0 で算出される', () async {
      await townProvider.advanceTown(3); // house, powerPlant, park
      expect(townProvider.population, 5);
    });

    test('文明スコアは棟数・累積発電量・ロケット発射数から算出される', () async {
      await townProvider.advanceTown(1);
      expect(townProvider.civilizationScore, 10); // 1棟×10
    });
  });

  group('TownProvider 実績', () {
    test('最初の住宅を建てると実績が1件解除される', () async {
      await townProvider.advanceTown(1);

      expect(townProvider.pendingCelebrations.length, 1);
      expect(townProvider.pendingCelebrations.first.id, 'first_house');

      final events = storage.loadAchievementEvents();
      expect(events.length, 1);
      expect(events.first.id, 'first_house');
    });

    test('clearPendingCelebrations 後はキューが空になる', () async {
      await townProvider.advanceTown(1);
      townProvider.clearPendingCelebrations();

      expect(townProvider.pendingCelebrations, isEmpty);
    });

    test('同じ実績は二重に解除されない', () async {
      await townProvider.advanceTown(1);
      townProvider.clearPendingCelebrations();

      await townProvider.advanceTown(1); // powerPlant が建つだけ

      expect(
        townProvider.pendingCelebrations.any((a) => a.id == 'first_house'),
        isFalse,
      );
    });

    test('ロケット建設段階(17棟目)で初めてのロケット実績が解除される', () async {
      await townProvider.advanceTown(17);

      final events = storage.loadAchievementEvents();
      expect(events.any((e) => e.id == 'first_rocket'), isTrue);
    });
  });

  group('TownProvider 発展段階祝福', () {
    test('level 0→1 で stage celebration が pending になり保存される', () async {
      await townProvider.buildChosen(BuildingType.house);

      expect(townProvider.pendingStageCelebrations.length, 1);
      expect(townProvider.pendingStageCelebrations.first.id, 'lightbulb');
      expect(townProvider.isStageCelebrated('lightbulb'), isTrue);
      expect(storage.loadTownStageEvents().length, 1);
    });

    test('既存セーブ（10棟）で初期化しても過去分の段階祝福は pending にならない', () async {
      final oldTown = TownState(
        buildings: List.generate(
          10,
          (i) => Building(
            type: BuildingType.values[i % BuildingType.values.length],
            x: i % 5,
            y: i ~/ 5,
          ),
        ),
      );
      await storage.saveTownState(oldTown);
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
      final migrated = TownProvider(migratedStorage, migratedEnergy, migratedSettings);

      expect(migrated.pendingStageCelebrations, isEmpty);
      expect(migrated.isStageCelebrated('lightbulb'), isTrue);
      expect(migrated.isStageCelebrated('town'), isTrue);
    });
  });
}
