import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pedometer_town/data/local_storage.dart';
import 'package:pedometer_town/domain/models/daily_step_record.dart';
import 'package:pedometer_town/providers/energy_provider.dart';
import 'package:pedometer_town/providers/history_provider.dart';
import 'package:pedometer_town/providers/settings_provider.dart';
import 'package:pedometer_town/services/health_service.dart';

class _FakeHealthService extends HealthService {
  @override
  Future<void> requestPermissions() async {}

  @override
  Future<int> getTodaySteps() async => 0;
}

void main() {
  late LocalStorage storage;
  late EnergyProvider energyProvider;
  late HistoryProvider historyProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorage(await SharedPreferences.getInstance());
    final settingsProvider = SettingsProvider(storage);
    energyProvider = EnergyProvider(
      storage,
      _FakeHealthService(),
      settingsProvider,
      now: () => DateTime(2026, 6, 19),
    );
    historyProvider = HistoryProvider(storage, energyProvider);
  });

  group('HistoryProvider.loadHistory', () {
    test('保存済みの全記録を日付の新しい順に返す', () async {
      await storage.saveDailyStepRecord(
        const DailyStepRecord(
          date: '2026-06-17',
          totalSteps: 100,
          totalEnergyWh: 1.0,
          lastSyncedSteps: 100,
        ),
      );
      await storage.saveDailyStepRecord(
        const DailyStepRecord(
          date: '2026-06-19',
          totalSteps: 300,
          totalEnergyWh: 3.0,
          lastSyncedSteps: 300,
        ),
      );

      final history = historyProvider.loadHistory();

      expect(history.map((r) => r.date), ['2026-06-19', '2026-06-17']);
    });
  });

  group('HistoryProvider.deleteHistoryRecord', () {
    test('指定日の記録を削除する', () async {
      await storage.saveDailyStepRecord(
        const DailyStepRecord(
          date: '2026-06-17',
          totalSteps: 100,
          totalEnergyWh: 1.0,
          lastSyncedSteps: 100,
        ),
      );

      await historyProvider.deleteHistoryRecord('2026-06-17');

      expect(historyProvider.loadHistory(), isEmpty);
    });

    test('削除対象が今日の記録なら EnergyProvider の表示も空になる', () async {
      await storage.saveDailyStepRecord(
        const DailyStepRecord(
          date: '2026-06-19',
          totalSteps: 500,
          totalEnergyWh: 5.0,
          lastSyncedSteps: 500,
        ),
      );
      energyProvider.refreshDisplay();
      expect(energyProvider.today.totalSteps, 500);

      await historyProvider.deleteHistoryRecord('2026-06-19');

      expect(energyProvider.today.totalSteps, 0);
      expect(energyProvider.today.date, '2026-06-19');
    });

    test('削除対象が今日でなければ EnergyProvider の表示は変化しない', () async {
      await storage.saveDailyStepRecord(
        const DailyStepRecord(
          date: '2026-06-19',
          totalSteps: 500,
          totalEnergyWh: 5.0,
          lastSyncedSteps: 500,
        ),
      );
      await storage.saveDailyStepRecord(
        const DailyStepRecord(
          date: '2026-06-17',
          totalSteps: 100,
          totalEnergyWh: 1.0,
          lastSyncedSteps: 100,
        ),
      );
      energyProvider.refreshDisplay();

      await historyProvider.deleteHistoryRecord('2026-06-17');

      expect(energyProvider.today.totalSteps, 500);
    });
  });

  group('HistoryProvider.clearHistory', () {
    test('全ての記録を削除し EnergyProvider の表示も空になる', () async {
      await storage.saveDailyStepRecord(
        const DailyStepRecord(
          date: '2026-06-19',
          totalSteps: 500,
          totalEnergyWh: 5.0,
          lastSyncedSteps: 500,
        ),
      );
      await storage.saveDailyStepRecord(
        const DailyStepRecord(
          date: '2026-06-17',
          totalSteps: 100,
          totalEnergyWh: 1.0,
          lastSyncedSteps: 100,
        ),
      );
      energyProvider.refreshDisplay();

      await historyProvider.clearHistory();

      expect(historyProvider.loadHistory(), isEmpty);
      expect(energyProvider.today.totalSteps, 0);
    });
  });
}
