import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pedometer_town/data/local_storage.dart';
import 'package:pedometer_town/domain/models/battery_state.dart';
import 'package:pedometer_town/domain/models/building.dart';
import 'package:pedometer_town/domain/models/daily_step_record.dart';
import 'package:pedometer_town/providers/energy_provider.dart';
import 'package:pedometer_town/providers/settings_provider.dart';
import 'package:pedometer_town/providers/town_provider.dart';
import 'package:pedometer_town/services/health_service.dart';

/// テスト用の固定/可変歩数を返す HealthService フェイク
class FakeHealthService extends HealthService {
  int totalSteps;
  Object? error;
  Object? permissionError;

  FakeHealthService({this.totalSteps = 0});

  @override
  Future<void> requestPermissions() async {
    if (permissionError != null) throw permissionError!;
  }

  @override
  Future<int> getTodaySteps() async {
    if (error != null) {
      throw error!;
    }
    return totalSteps;
  }
}

void main() {
  late LocalStorage storage;
  late SettingsProvider settingsProvider;
  late FakeHealthService healthService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorage(await SharedPreferences.getInstance());
    settingsProvider = SettingsProvider(storage);
    healthService = FakeHealthService();
  });

  group('EnergyProvider.syncStepsFromHealth', () {
    test('複数回の同期で1日の上限(10000Wh)を超えて加算されない', () async {
      var now = DateTime(2026, 6, 16, 8);
      final provider = EnergyProvider(
        storage,
        healthService,
        settingsProvider,
        now: () => now,
      );

      // 1回目: 6,000歩 → 6000Wh
      healthService.totalSteps = 6000;
      await provider.syncStepsFromHealth();
      expect(provider.today.totalEnergyWh, closeTo(6000.0, 1e-9));
      expect(provider.battery.storedWh, closeTo(6000.0, 1e-9));

      // 2回目: +4,000歩 → +4000Wh (合計10000Whで上限)
      now = now.add(const Duration(hours: 1));
      healthService.totalSteps = 10000;
      await provider.syncStepsFromHealth();
      expect(provider.today.totalEnergyWh, closeTo(10000.0, 1e-9));
      expect(provider.battery.storedWh, closeTo(10000.0, 1e-9));

      // 3回目: +2,000歩 → 上限到達済みのため加算なし
      now = now.add(const Duration(hours: 1));
      healthService.totalSteps = 12000;
      await provider.syncStepsFromHealth();
      expect(provider.today.totalEnergyWh, closeTo(10000.0, 1e-9));
      expect(provider.battery.storedWh, closeTo(10000.0, 1e-9));
      // 3回目もエネルギーは加算されないが歩数差分自体は積算される
      expect(provider.today.totalSteps, 12000);
    });

    test('日付が変わると当日の記録がリセットされる', () async {
      var now = DateTime(2026, 6, 16, 23, 30);
      final provider = EnergyProvider(
        storage,
        healthService,
        settingsProvider,
        now: () => now,
      );

      healthService.totalSteps = 1000;
      await provider.syncStepsFromHealth();
      expect(provider.today.date, '2026-06-16');
      expect(provider.today.totalSteps, 1000);
      expect(provider.today.totalEnergyWh, closeTo(1000.0, 1e-9));

      // 日付が翌日に変わってから同期
      now = DateTime(2026, 6, 17, 0, 5);
      healthService.totalSteps = 1200;
      await provider.syncStepsFromHealth();

      expect(provider.today.date, '2026-06-17');
      // 新しい日のレコードなので歩数差分は1200歩そのもの
      expect(provider.today.totalSteps, 1200);
      expect(provider.today.totalEnergyWh, closeTo(1200.0, 1e-9));
    });

    test('Health取得に失敗するとHealthServiceExceptionが伝播する', () async {
      final provider = EnergyProvider(storage, healthService, settingsProvider);
      healthService.error = const HealthServiceException('歩数データを取得できませんでした');

      expect(
        () => provider.syncStepsFromHealth(),
        throwsA(isA<HealthServiceException>()),
      );
    });

    test('公園を建設するとエネルギー係数が1.1倍になる', () async {
      late TownProvider townProvider;
      final provider = EnergyProvider(
        storage,
        healthService,
        settingsProvider,
        coefficientSupplier: () => townProvider.effectiveCoefficient,
      );
      townProvider = TownProvider(storage, provider, settingsProvider);

      // 公園の建設コスト(800Wh)分のエネルギーを確保する
      await provider.applyBatteryState(
        const BatteryState(storedWh: 800, capacityWh: 10000),
      );
      final built = await townProvider.buildBuilding(BuildingType.park, 0, 0);
      expect(built, isTrue);

      // 1000歩 @70kg/5km/h, 係数1.0×1.1=1.1 → 1100.0Wh
      healthService.totalSteps = 1000;
      await provider.syncStepsFromHealth();
      expect(provider.today.totalEnergyWh, closeTo(1100.0, 1e-9));
    });
  });

  group('EnergyProvider.refreshDisplay', () {
    test('永続化済みの値で蓄電池・今日の記録を更新する', () async {
      final now = DateTime(2026, 6, 16, 8);
      final provider = EnergyProvider(
        storage,
        healthService,
        settingsProvider,
        now: () => now,
      );

      await storage.saveBatteryState(
        const BatteryState(storedWh: 500, capacityWh: 10000),
      );
      await storage.saveDailyStepRecord(
        const DailyStepRecord(
          date: '2026-06-16',
          totalSteps: 1234,
          totalEnergyWh: 12.34,
          lastSyncedSteps: 1234,
        ),
      );

      provider.refreshDisplay();

      expect(provider.battery.storedWh, 500);
      expect(provider.today.totalSteps, 1234);
      expect(provider.today.totalEnergyWh, closeTo(12.34, 1e-9));
    });
  });
}
