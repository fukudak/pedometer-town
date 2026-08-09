import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pedometer_town/data/local_storage.dart';
import 'package:pedometer_town/domain/models/battery_state.dart';
import 'package:pedometer_town/domain/models/daily_step_record.dart';
import 'package:pedometer_town/domain/models/feed_item_type.dart';
import 'package:pedometer_town/providers/companion_provider.dart';
import 'package:pedometer_town/providers/energy_provider.dart';
import 'package:pedometer_town/providers/history_provider.dart';
import 'package:pedometer_town/providers/settings_provider.dart';
import 'package:pedometer_town/services/health_service.dart';
import 'package:pedometer_town/utils/date_key.dart';

/// テスト用の固定/可変歩数を返す HealthService フェイク
class FakeHealthService extends HealthService {
  int totalSteps;
  Object? error;
  Object? permissionError;

  /// さかのぼり取得（[getStepsForDate]）が日付ごとに返す歩数。
  /// 未設定の日付は null（＝取得できない）を返す。
  final Map<String, int> stepsByDate = {};

  /// この日付集合に含まれる日は [getStepsForDate] が例外を投げる
  /// （1日だけの取得失敗が他の日を巻き込まないことを検証するため）。
  final Set<String> throwingDates = {};

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

  @override
  Future<int?> getStepsForDate(DateTime date) async {
    final key = formatDateKey(date);
    if (throwingDates.contains(key)) {
      throw Exception('$key の取得に失敗（テスト用）');
    }
    return stepsByDate[key];
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
    test('1日の上限はなく、複数回満タンになっても発電が止まらない', () async {
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

      // 2回目: +4,000歩 → +4000Wh (合計10000Whで満タン、蓄電池は0に折り返る)
      now = now.add(const Duration(hours: 1));
      healthService.totalSteps = 10000;
      await provider.syncStepsFromHealth();
      expect(provider.today.totalEnergyWh, closeTo(10000.0, 1e-9));
      expect(provider.battery.storedWh, closeTo(0.0, 1e-9));

      // 3回目: +2,000歩 → 満タン後も発電は止まらず、蓄電池に2000Wh蓄積される
      now = now.add(const Duration(hours: 1));
      healthService.totalSteps = 12000;
      await provider.syncStepsFromHealth();
      expect(provider.today.totalEnergyWh, closeTo(12000.0, 1e-9));
      expect(provider.battery.storedWh, closeTo(2000.0, 1e-9));
      expect(provider.today.totalSteps, 12000);

      final events = storage.loadFullBatteryEvents();
      expect(events.length, 1);
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

    test('おもちゃを与えるとエネルギー係数が1.1倍になる', () async {
      late CompanionProvider companionProvider;
      final provider = EnergyProvider(
        storage,
        healthService,
        settingsProvider,
        coefficientSupplier: () => companionProvider.effectiveCoefficient,
      );
      companionProvider = CompanionProvider(storage, provider, settingsProvider);

      await companionProvider.feedChosen(FeedItemType.toy);
      expect(companionProvider.companion.toyCount, 1);

      // 1000歩 @70kg/5km/h, 係数1.0×1.1=1.1 → 1100.0Wh
      healthService.totalSteps = 1000;
      await provider.syncStepsFromHealth();
      expect(provider.today.totalEnergyWh, closeTo(1100.0, 1e-9));
    });

    test('蓄電池が満タンになると履歴に記録され、蓄電池は0に折り返る', () async {
      final provider = EnergyProvider(storage, healthService, settingsProvider);

      // 10000歩 @70kg/5km/h, 係数1.0 → 10000.0Wh（蓄電池容量と一致）
      healthService.totalSteps = 10000;
      await provider.syncStepsFromHealth();

      expect(provider.battery.storedWh, closeTo(0.0, 1e-9));
      final events = storage.loadFullBatteryEvents();
      expect(events.length, 1);
      expect(events.first.number, 1);
    });
  });

  group('EnergyProvider 未同期日のさかのぼり加算', () {
    test('数日アプリを開かなくても、間の日の歩数がさかのぼってエネルギーに加算される', () async {
      var now = DateTime(2026, 6, 16, 8);
      final provider = EnergyProvider(
        storage,
        healthService,
        settingsProvider,
        now: () => now,
      );

      // 6/16 に同期
      healthService.totalSteps = 1000;
      await provider.syncStepsFromHealth();
      expect(provider.lifetimeEnergyWh, closeTo(1000.0, 1e-9));

      // 6/17, 6/18 はアプリを開かなかった（HealthKit 側には歩数が残っている）
      healthService.stepsByDate['2026-06-17'] = 2000;
      healthService.stepsByDate['2026-06-18'] = 1500;

      // 6/19 に久しぶりに開いて同期
      now = DateTime(2026, 6, 19, 9);
      healthService.totalSteps = 500;
      await provider.syncStepsFromHealth();

      // 開かなかった2日分(2000+1500)と6/19当日分(500)が失われず加算されている
      expect(provider.lifetimeEnergyWh, closeTo(1000.0 + 2000.0 + 1500.0 + 500.0, 1e-9));
      expect(storage.loadDailyStepRecord('2026-06-17').totalSteps, 2000);
      expect(storage.loadDailyStepRecord('2026-06-18').totalSteps, 1500);
      expect(provider.today.totalSteps, 500);
    });

    test('取得できない日（Androidなど）はスキップされ、他の日には影響しない', () async {
      var now = DateTime(2026, 6, 16, 8);
      final provider = EnergyProvider(
        storage,
        healthService,
        settingsProvider,
        now: () => now,
      );

      healthService.totalSteps = 1000;
      await provider.syncStepsFromHealth();

      // 6/17 分は取得できない（stepsByDate に設定しない）
      now = DateTime(2026, 6, 18, 9);
      healthService.totalSteps = 300;
      await provider.syncStepsFromHealth();

      expect(provider.lifetimeEnergyWh, closeTo(1000.0 + 300.0, 1e-9));
      expect(storage.loadDailyStepRecord('2026-06-17').totalSteps, 0);
    });

    test('初回同期（前回同期日時が無い）ではさかのぼり処理は行われない', () async {
      final provider = EnergyProvider(storage, healthService, settingsProvider);
      healthService.totalSteps = 500;

      await provider.syncStepsFromHealth();

      expect(provider.lifetimeEnergyWh, closeTo(500.0, 1e-9));
    });

    test('同じ日を2回さかのぼり対象にしても二重加算されない', () async {
      var now = DateTime(2026, 6, 16, 8);
      final provider = EnergyProvider(
        storage,
        healthService,
        settingsProvider,
        now: () => now,
      );

      healthService.totalSteps = 1000;
      await provider.syncStepsFromHealth();

      healthService.stepsByDate['2026-06-17'] = 2000;

      // 6/18 に同期（6/17 分がさかのぼり加算される）
      now = DateTime(2026, 6, 18, 8);
      healthService.totalSteps = 0;
      await provider.syncStepsFromHealth();
      final afterFirstBackfill = provider.lifetimeEnergyWh;

      // 同日中にもう一度同期しても 6/17 分が再加算されない
      healthService.totalSteps = 0;
      await provider.syncStepsFromHealth();

      expect(provider.lifetimeEnergyWh, closeTo(afterFirstBackfill, 1e-9));
    });

    test('長期間あけた場合、上限を超える古い日ではなく直近の日が優先して埋められる', () async {
      var now = DateTime(2026, 1, 1, 8);
      final provider = EnergyProvider(
        storage,
        healthService,
        settingsProvider,
        now: () => now,
      );

      healthService.totalSteps = 100;
      await provider.syncStepsFromHealth();

      // 1/1 の同期のあと 40 日間アプリを開かず、その間ずっと 1000 歩ずつ歩いていた。
      for (var offset = 1; offset < 40; offset++) {
        final date = DateTime(2026, 1, 1).add(Duration(days: offset));
        healthService.stepsByDate[formatDateKey(date)] = 1000;
      }

      now = DateTime(2026, 2, 10, 8); // 1/1 から 40 日後
      healthService.totalSteps = 0;
      await provider.syncStepsFromHealth();

      // 直近側（2月上旬〜1月下旬）が埋まり、最古の 1/02 は上限を超えて切り捨てられる。
      expect(storage.loadDailyStepRecord('2026-02-09').totalSteps, 1000,
          reason: '直近の日が埋まっているべき');
      expect(storage.loadDailyStepRecord('2026-01-02').totalSteps, 0,
          reason: '上限を超えた最古の日は対象外');
    });

    test('さかのぼり加算された満タン履歴は日付の古い順に並ぶ', () async {
      var now = DateTime(2026, 6, 16, 8);
      final provider = EnergyProvider(
        storage,
        healthService,
        settingsProvider,
        now: () => now,
      );

      healthService.totalSteps = 100;
      await provider.syncStepsFromHealth();

      // 各日 10000 歩＝蓄電池ちょうど1個分
      healthService.stepsByDate['2026-06-17'] = 10000;
      healthService.stepsByDate['2026-06-18'] = 10000;

      now = DateTime(2026, 6, 19, 8);
      healthService.totalSteps = 0;
      await provider.syncStepsFromHealth();

      final events = storage.loadFullBatteryEvents();
      final backfilled =
          events.where((e) => e.date.startsWith('2026-06-1')).toList();
      expect(backfilled.length, greaterThanOrEqualTo(2));
      final dates = backfilled.map((e) => e.date).toList();
      final sorted = [...dates]..sort();
      expect(dates, sorted, reason: '満タン履歴は日付の古い順であるべき');
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

  group('EnergyProvider 同期カーソルの移行互換', () {
    test('カーソル導入前のバージョンからの更新直後は、旧lastSyncedStepsを起点にする', () async {
      final now = DateTime(2026, 6, 19, 8);
      // 同期カーソル（today_synced_*）が存在しない状態で、旧方式の日次記録だけが
      // 500歩まで同期済みとして残っている状況を再現する。
      await storage.saveDailyStepRecord(
        const DailyStepRecord(
          date: '2026-06-19',
          totalSteps: 500,
          totalEnergyWh: 500.0,
          lastSyncedSteps: 500,
        ),
      );

      final provider = EnergyProvider(
        storage,
        healthService,
        settingsProvider,
        now: () => now,
      );

      healthService.totalSteps = 500;
      await provider.syncStepsFromHealth();

      expect(provider.lifetimeEnergyWh, 0, reason: '更新直後の同期で再加算されないこと');

      healthService.totalSteps = 600;
      await provider.syncStepsFromHealth();
      expect(provider.lifetimeEnergyWh, closeTo(100.0, 1e-9));
    });
  });

  group('EnergyProvider 履歴削除後の同期(二重加算防止)', () {
    test('今日の履歴を削除しても、同じ歩数の再同期では発電量・蓄電池・累積発電量が増えない', () async {
      final now = DateTime(2026, 6, 19, 8);
      final provider = EnergyProvider(
        storage,
        healthService,
        settingsProvider,
        now: () => now,
      );
      final companionProvider = CompanionProvider(
        storage,
        provider,
        settingsProvider,
        now: () => now,
      );
      final historyProvider =
          HistoryProvider(storage, provider, companionProvider);

      // 1. 今日500歩を同期する。
      healthService.totalSteps = 500;
      await provider.syncStepsFromHealth();
      expect(provider.today.totalSteps, 500);
      expect(provider.today.totalEnergyWh, closeTo(500.0, 1e-9));
      expect(provider.lifetimeEnergyWh, closeTo(500.0, 1e-9));

      // 2. 今日の履歴を削除する。
      await historyProvider.deleteHistoryRecord('2026-06-19');
      expect(provider.today.totalSteps, 0);

      // 3. HealthKit相当のサービスが引き続き500歩を返す。
      // 4. 再同期しても発電量・蓄電池・累積発電量が増えない。
      await provider.syncStepsFromHealth();
      expect(provider.battery.storedWh, closeTo(500.0, 1e-9));
      expect(provider.lifetimeEnergyWh, closeTo(500.0, 1e-9));

      // 5. その後600歩を返した場合は差分100歩だけ加算される。
      healthService.totalSteps = 600;
      await provider.syncStepsFromHealth();
      expect(provider.battery.storedWh, closeTo(600.0, 1e-9));
      expect(provider.lifetimeEnergyWh, closeTo(600.0, 1e-9));
    });

    test('全履歴クリアでも同じ動作になる', () async {
      final now = DateTime(2026, 6, 19, 8);
      final provider = EnergyProvider(
        storage,
        healthService,
        settingsProvider,
        now: () => now,
      );
      final companionProvider = CompanionProvider(
        storage,
        provider,
        settingsProvider,
        now: () => now,
      );
      final historyProvider =
          HistoryProvider(storage, provider, companionProvider);

      healthService.totalSteps = 500;
      await provider.syncStepsFromHealth();

      await historyProvider.clearHistory();
      // 全履歴クリアは発展度・蓄電池・累積発電量も初期化するため、ここでは
      // 「同期カーソルが保持され、二重加算されないこと」だけを確認する。
      expect(provider.lifetimeEnergyWh, 0);

      await provider.syncStepsFromHealth();
      expect(provider.lifetimeEnergyWh, 0, reason: '同期済み500歩が再加算されないこと');

      healthService.totalSteps = 600;
      await provider.syncStepsFromHealth();
      expect(provider.lifetimeEnergyWh, closeTo(100.0, 1e-9));
    });
  });

  group('EnergyProvider さかのぼり同期の冪等性', () {
    test('複数日のさかのぼり処理中に1日だけ取得失敗しても、他の日は正常に反映される', () async {
      var now = DateTime(2026, 6, 16, 8);
      final provider = EnergyProvider(
        storage,
        healthService,
        settingsProvider,
        now: () => now,
      );

      healthService.totalSteps = 0;
      await provider.syncStepsFromHealth(); // 起点を作る

      healthService.stepsByDate['2026-06-17'] = 1000;
      healthService.throwingDates.add('2026-06-18');
      healthService.stepsByDate['2026-06-19'] = 3000;

      now = DateTime(2026, 6, 20, 8);
      healthService.totalSteps = 0;
      await provider.syncStepsFromHealth();

      // 失敗した6/18以外は反映されている。
      expect(provider.lifetimeEnergyWh, closeTo(4000.0, 1e-9));
      final committed = storage.loadBackfillCommittedDates();
      expect(committed.contains('2026-06-17'), isTrue);
      expect(committed.contains('2026-06-18'), isFalse);
      expect(committed.contains('2026-06-19'), isTrue);
    });

    test('失敗した日は次回同期で再試行され、成功済みの日は二重加算されない', () async {
      var now = DateTime(2026, 6, 16, 8);
      final provider = EnergyProvider(
        storage,
        healthService,
        settingsProvider,
        now: () => now,
      );

      healthService.totalSteps = 0;
      await provider.syncStepsFromHealth();

      healthService.stepsByDate['2026-06-17'] = 1000;
      healthService.throwingDates.add('2026-06-18');
      healthService.stepsByDate['2026-06-19'] = 3000;

      now = DateTime(2026, 6, 20, 8);
      healthService.totalSteps = 0;
      await provider.syncStepsFromHealth(); // 1回目: 6/18だけ失敗

      // 6/18 の取得が復旧した状態で再同期する。
      healthService.throwingDates.remove('2026-06-18');
      healthService.stepsByDate['2026-06-18'] = 500;
      await provider.syncStepsFromHealth(); // 2回目: 残りを回収

      // 6/17, 6/18, 6/19 の合計が一度だけ反映されている。
      expect(provider.lifetimeEnergyWh, closeTo(4500.0, 1e-9));
      final committed = storage.loadBackfillCommittedDates();
      expect(committed.containsAll(['2026-06-17', '2026-06-18', '2026-06-19']), isTrue);
    });
  });
}
