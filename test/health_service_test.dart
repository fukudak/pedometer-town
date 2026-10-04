import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import 'package:pedometer_town/services/health_service.dart';

/// HealthKit プラグインの呼び出しが素の例外を投げる状況を再現するフェイク。
class _ThrowingHealth extends Health {
  @override
  Future<int?> getTotalStepsInInterval(
    DateTime startTime,
    DateTime endTime, {
    bool includeManualEntry = true,
  }) async {
    throw Exception('plugin channel error');
  }
}

/// EnergyProvider.syncStepsFromHealth の加算規約を再現するヘルパー。
///
/// - 日付が変わったら今日の記録は空（lastSyncedSteps = 0）から始まる
/// - 新規歩数 = getTodaySteps() の戻り値 − 今日の記録の lastSyncedSteps
///
/// HealthService 単体では日またぎの二重計上を検出できないため、
/// この規約と噛み合わせた通しのシナリオで検証する。
class _StepSyncSimulator {
  String _todayKey;
  int _lastSyncedSteps = 0;
  int? _baselineSteps;
  int totalCredited = 0;

  _StepSyncSimulator({required String startDateKey}) : _todayKey = startDateKey;

  /// 1回分の同期を行い、そのとき加算された新規歩数を返す。
  int sync({required int rawSteps, required String todayKey}) {
    if (_todayKey != todayKey) {
      _todayKey = todayKey;
      _lastSyncedSteps = 0; // 日付が変わったら今日の記録はリセットされる
    }

    final result = HealthService.normalizeAndroidSteps(
      rawSteps: rawSteps,
      todayKey: todayKey,
      storedBaselineSteps: _baselineSteps,
      alreadySyncedToday: _lastSyncedSteps,
    );
    _baselineSteps = result.baselineSteps;

    final delta = result.todaySteps - _lastSyncedSteps;
    final credited = delta < 0 ? result.todaySteps : delta;
    _lastSyncedSteps = result.todaySteps;
    totalCredited += credited;
    return credited;
  }
}

void main() {
  group('HealthService.normalizeAndroidSteps', () {
    test('初回起動（ベースライン未設定）は現在値を起点にして増分は0になる', () {
      final result = HealthService.normalizeAndroidSteps(
        rawSteps: 12345,
        todayKey: '2026-06-19',
      );
      expect(result.todaySteps, 0);
      expect(result.baselineDate, '2026-06-19');
      expect(result.baselineSteps, 12345);
    });

    test('同日内の再同期は前回同期からの増分が加算される', () {
      final result = HealthService.normalizeAndroidSteps(
        rawSteps: 12500,
        todayKey: '2026-06-19',
        storedBaselineSteps: 12345,
        alreadySyncedToday: 0,
      );
      expect(result.todaySteps, 155);
      // ベースラインは最終同期時点のセンサー値まで前進する
      expect(result.baselineSteps, 12500);
    });

    test('同日内で既に同期済みの歩数がある場合は、その累計に増分を足して返す', () {
      final result = HealthService.normalizeAndroidSteps(
        rawSteps: 13000,
        todayKey: '2026-06-19',
        storedBaselineSteps: 12500,
        alreadySyncedToday: 155,
      );
      expect(result.todaySteps, 155 + 500);
    });

    test('端末再起動でセンサーがリセットされた場合は現在値をそのまま増分とする', () {
      final result = HealthService.normalizeAndroidSteps(
        rawSteps: 80,
        todayKey: '2026-06-19',
        storedBaselineSteps: 12345,
        alreadySyncedToday: 11000,
      );
      expect(result.todaySteps, 11000 + 80);
      expect(result.baselineSteps, 80);
    });
  });

  group('HealthService プラグイン例外の変換', () {
    test('今日の歩数取得でプラグイン例外が発生すると HealthServiceException になる', () async {
      final service = HealthService(health: _ThrowingHealth());

      await expectLater(
        service.getTodaySteps(),
        throwsA(isA<HealthServiceException>()),
      );
    });

    test('さかのぼり取得でプラグイン例外が発生すると null を返す（例外を投げない）', () async {
      final service = HealthService(health: _ThrowingHealth());

      final result = await service.getStepsForDate(DateTime(2026, 6, 1));

      expect(result, isNull);
    });
  });

  group('Android 歩数の通し同期シナリオ（EnergyProvider の加算規約込み）', () {
    test('同日内に複数回同期しても、実際に歩いた分だけが加算される', () {
      final sim = _StepSyncSimulator(startDateKey: '2026-06-19');

      sim.sync(rawSteps: 5000, todayKey: '2026-06-19'); // 初回：起点を作るだけ
      expect(sim.sync(rawSteps: 15000, todayKey: '2026-06-19'), 10000);
      expect(sim.sync(rawSteps: 16000, todayKey: '2026-06-19'), 1000);

      expect(sim.totalCredited, 11000); // 16000 - 5000
    });

    test('日をまたいでも、前日に加算済みの歩数が二重計上されない', () {
      final sim = _StepSyncSimulator(startDateKey: '2026-06-19');

      sim.sync(rawSteps: 5000, todayKey: '2026-06-19'); // 初回：起点 5000
      sim.sync(rawSteps: 15000, todayKey: '2026-06-19'); // day1 に 10000 歩

      // 2日空けて再開。センサー累積は 35000。
      sim.sync(rawSteps: 35000, todayKey: '2026-06-21');

      // 初回同期から実際に歩いたのは 35000 - 5000 = 30000 歩。
      expect(sim.totalCredited, 30000);
    });

    test('数日アプリを開かなくても、その間に歩いた分は失われない', () {
      final sim = _StepSyncSimulator(startDateKey: '2026-06-19');

      sim.sync(rawSteps: 10000, todayKey: '2026-06-19'); // 起点 10000
      // 5日後に再開：その間に 13000 歩あるいている
      expect(sim.sync(rawSteps: 23000, todayKey: '2026-06-24'), 13000);
      expect(sim.totalCredited, 13000);
    });

    test('日をまたいだ上に端末再起動もしていた場合も二重計上しない', () {
      final sim = _StepSyncSimulator(startDateKey: '2026-06-19');

      sim.sync(rawSteps: 5000, todayKey: '2026-06-19'); // 起点 5000
      sim.sync(rawSteps: 15000, todayKey: '2026-06-19'); // day1 に 10000 歩

      // 端末を再起動したのでセンサーは 0 起算に戻り、翌日 800 歩あるいた
      expect(sim.sync(rawSteps: 800, todayKey: '2026-06-20'), 800);
      expect(sim.totalCredited, 10800);
    });
  });
}
