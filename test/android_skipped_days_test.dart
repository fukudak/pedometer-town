import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pedometer_town/data/local_storage.dart';
import 'package:pedometer_town/domain/models/daily_step_record.dart';
import 'package:pedometer_town/providers/energy_provider.dart';
import 'package:pedometer_town/providers/settings_provider.dart';
import 'package:pedometer_town/services/health_service.dart';
import 'package:pedometer_town/utils/date_key.dart';

/// Android の実経路を再現するフェイク。
/// - 今日の歩数: `HealthService._getStepsFromSensor` と同じ手順
///   （保存済みベースライン・同期カーソル + normalizeAndroidSteps）。センサー生値のみ注入する。
/// - 過去日の個別取得: Android の実装どおり常に null（二重計上を避けるため）。
class _FakeAndroidHealthService extends HealthService {
  final LocalStorage storage;
  final DateTime Function() now;
  int rawSensorSteps = 0;

  _FakeAndroidHealthService(this.storage, this.now) : super(storage: storage);

  @override
  bool get aggregatesSkippedDays => true;

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<int> getTodaySteps() async {
    final baseline = storage.loadAndroidStepBaseline();
    final todayKey = formatDateKey(now());
    final cursor = storage.loadTodaySyncedCursor();
    final result = HealthService.normalizeAndroidSteps(
      rawSteps: rawSensorSteps,
      todayKey: todayKey,
      storedBaselineSteps: baseline.steps,
      alreadySyncedToday: cursor.date == todayKey ? cursor.steps : 0,
    );
    await storage.saveAndroidStepBaseline(
      result.baselineDate,
      result.baselineSteps,
    );
    return result.todaySteps;
  }

  @override
  Future<int?> getStepsForDate(DateTime date) async => null;
}

void main() {
  late LocalStorage storage;
  late DateTime now;
  late _FakeAndroidHealthService health;
  late EnergyProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorage(await SharedPreferences.getInstance());
    now = DateTime(2026, 6, 16, 8);
    health = _FakeAndroidHealthService(storage, () => now);
    provider = EnergyProvider(
      storage,
      health,
      SettingsProvider(storage),
      now: () => now,
    );

    // 6/16: 初回同期(起点作成のみ)→ 1000歩歩いて再同期
    health.rawSensorSteps = 5000;
    await provider.syncStepsFromHealth();
    health.rawSensorSteps = 6000;
    await provider.syncStepsFromHealth();
  });

  // 係数・体重・速度が既定値なので 1歩 = 1Wh。
  test('数日空けても、歩いた分だけが同期日にまとめて加算される（二重計上しない）', () async {
    // 6/17 に 3000歩、6/18 に 2000歩、6/19 朝までに 500歩（アプリは開かない）
    now = DateTime(2026, 6, 19, 9);
    health.rawSensorSteps = 6000 + 3000 + 2000 + 500;
    await provider.syncStepsFromHealth();

    expect(provider.lifetimeEnergyWh, closeTo(1000 + 5500, 1e-9));
    expect(provider.today.totalSteps, 5500);
    expect(storage.loadDailyStepRecord('2026-06-17').totalSteps, 0);
    expect(storage.loadDailyStepRecord('2026-06-18').totalSteps, 0);
  });

  test('2日以上空けてまとめて加算されたら、集計開始日が記録される', () async {
    now = DateTime(2026, 6, 19, 9);
    health.rawSensorSteps = 11500;
    await provider.syncStepsFromHealth();

    expect(provider.today.rangeStart, '2026-06-16');
    expect(storage.loadDailyStepRecord('2026-06-19').rangeStart, '2026-06-16');

    // 同じ日の再同期でも集計開始日は保たれる
    health.rawSensorSteps = 11600;
    await provider.syncStepsFromHealth();
    expect(provider.today.totalSteps, 5600);
    expect(provider.today.rangeStart, '2026-06-16');
  });

  test('空きが1日以内なら集計開始日は付かない', () async {
    now = DateTime(2026, 6, 17, 9);
    health.rawSensorSteps = 7000;
    await provider.syncStepsFromHealth();

    expect(provider.today.totalSteps, 1000);
    expect(provider.today.rangeStart, isNull);
  });

  test('集計開始日が無い古い保存データも読み込める', () {
    final record = DailyStepRecord.fromJson({
      'date': '2026-06-19',
      'totalSteps': 10,
      'totalEnergyWh': 10.0,
      'lastSyncedSteps': 10,
    });
    expect(record.rangeStart, isNull);
    expect(record.toJson().containsKey('rangeStart'), isFalse);

    final withRange = record.copyWith(rangeStart: '2026-06-16');
    expect(DailyStepRecord.fromJson(withRange.toJson()).rangeStart, '2026-06-16');
  });
}
