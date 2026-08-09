import 'package:flutter/foundation.dart';

import '../constants/game_constants.dart';
import '../data/local_storage.dart';
import '../domain/energy_calculator.dart';
import '../domain/models/battery_state.dart';
import '../domain/models/daily_step_record.dart';
import '../domain/models/full_battery_event.dart';
import '../services/health_service.dart';
import '../utils/date_key.dart';
import 'settings_provider.dart';

/// 蓄電池・今日の歩数/エネルギーの状態管理
class EnergyProvider extends ChangeNotifier {
  /// さかのぼり取得を試みる最大日数（無制限にすると同期が長時間化するため上限を設ける）。
  static const int _maxBackfillDays = 30;

  final LocalStorage _storage;
  final HealthService _healthService;
  final SettingsProvider _settingsProvider;

  final DateTime Function() _now;
  double Function() _coefficientSupplier;

  BatteryState _battery;
  DailyStepRecord _today;
  DateTime? _lastSyncedAt;
  double _lifetimeEnergyWh;
  int _pendingBatteries;

  EnergyProvider(
    this._storage,
    this._healthService,
    this._settingsProvider, {
    DateTime Function()? now,
    double Function()? coefficientSupplier,
  })  : _now = now ?? DateTime.now,
        _coefficientSupplier =
            coefficientSupplier ?? (() => GameConstants.energyCoefficient),
        _battery = _storage.loadBatteryState(_storage.loadCompanionState()),
        _today = _storage
            .loadDailyStepRecord(formatDateKey((now ?? DateTime.now)())),
        _lastSyncedAt = _storage.loadLastSyncedAt(),
        _lifetimeEnergyWh = _storage.loadLifetimeEnergyWh(),
        _pendingBatteries = _storage.loadPendingBatteries();

  void setCoefficientSupplier(double Function() supplier) {
    _coefficientSupplier = supplier;
  }

  BatteryState get battery => _battery;
  DailyStepRecord get today => _today;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  double get lifetimeEnergyWh => _lifetimeEnergyWh;

  /// 満タンになったがまだ相棒に与えられていない蓄電池の個数。
  int get pendingBatteries => _pendingBatteries;

  /// 今日すでに同期済みとして記録されている歩数（表示用履歴とは独立）。
  /// 日付が変わっていれば 0 を返す。
  ///
  /// 移行互換: このカーソルが導入される前のバージョンから更新した直後は、
  /// カーソルがまだ未設定（`cursor.date == null`）になる。その場合、旧方式で
  /// 記録されていた今日の日次記録の `lastSyncedSteps` があればそれを起点として使う
  /// （0 から起点を作り直すと、更新直後の1回だけ今日の同期済み歩数を再加算してしまうため）。
  int _todaySyncedCursor(String todayKey) {
    final cursor = _storage.loadTodaySyncedCursor();
    if (cursor.date == todayKey) return cursor.steps;
    if (cursor.date == null && _today.date == todayKey) {
      return _today.lastSyncedSteps;
    }
    return 0;
  }

  /// Health から今日の歩数を取得し、差分をエネルギーに変換して蓄電池に加算する。
  /// 前回同期から日をまたいで開いていなかった場合、間の日の歩数もさかのぼって加算を試みる
  /// （iOS のみ。Android はベースライン繰り越しで日またぎに対応済み）。
  ///
  /// 同期差分の起点には、画面の履歴削除・全クリアの影響を受けない専用カーソル
  /// （[LocalStorage.loadTodaySyncedCursor]）を使う。表示用の [DailyStepRecord] を
  /// 削除しても、この起点が失われないため再同期で歩数・発電量が二重加算されない。
  Future<void> syncStepsFromHealth() async {
    await _healthService.requestPermissions();
    await _backfillMissedDays();

    final todayKey = formatDateKey(_now());
    if (_today.date != todayKey) {
      _today = DailyStepRecord.empty(todayKey);
    }
    final cursorSteps = _todaySyncedCursor(todayKey);

    final totalSteps = await _healthService.getTodaySteps();
    final deltaSteps = totalSteps - cursorSteps;

    // delta < 0 は再起動によるセンサーリセット。センサー現在値を新規歩数として扱う。
    final effectiveDelta = deltaSteps < 0 ? totalSteps : deltaSteps;

    if (effectiveDelta == 0) {
      _today = _today.copyWith(lastSyncedSteps: totalSteps);
      _lastSyncedAt = _now();
      await _persist(todayKey, totalSteps);
      notifyListeners();
      return;
    }

    final settings = _settingsProvider.settings;
    final newEnergyWh = EnergyCalculator.calculateEnergyWh(
      steps: effectiveDelta,
      weightKg: settings.weightKg,
      speedKmh: settings.defaultSpeedKmh,
      coefficient: _coefficientSupplier(),
    );

    final batteriesFilled = _applyEnergyGain(newEnergyWh);
    _today = _today.copyWith(
      totalSteps: _today.totalSteps + effectiveDelta,
      totalEnergyWh: _today.totalEnergyWh + newEnergyWh,
      lastSyncedSteps: totalSteps,
    );
    _lastSyncedAt = _now();

    if (batteriesFilled > 0) {
      await _recordFullBatteries(todayKey, batteriesFilled);
      _pendingBatteries += batteriesFilled;
    }

    await _persist(todayKey, totalSteps);
    notifyListeners();
  }

  /// 前回同期日の翌日から昨日までのうち、まだ蓄電池・累積発電量へ反映しきれていない
  /// 日の歩数を取得できれば加算する。取得できない日（Android や HealthKit 側にデータが
  /// 無い日、取得中にエラーが起きた日）は今回はスキップし、次回の同期で再試行する
  /// （ベストエフォート）。
  ///
  /// 走査は **昨日から新しい順** に行い、[_maxBackfillDays] 日より前は打ち切る。
  /// 古い順に走査すると、長期間アプリを開かなかったときに上限を古い日で使い切ってしまい、
  /// 直近の歩数が取りこぼされるため。
  ///
  /// 冪等性: 各日の処理は「日次記録の保存 → 蓄電池・累積発電量・ストック・満タン履歴の保存
  /// → コミット済みマーカーへの追加」を1日ずつ順番に行い、コミット済みマーカーに入っている
  /// 日だけを「反映済み」とみなす。処理の途中でアプリが終了したり保存に失敗したりしても、
  /// マーカーが付いていない日は次回また候補になり再試行される一方、マーカーが付いた日は
  /// 二重に加算されない。SharedPreferences には複数キーにまたがる本当のトランザクションは
  /// 無いため、1日の処理の最中（例: 蓄電池保存後・マーカー保存前）に中断した場合は
  /// 理論上ごく僅かな不整合が残り得るが、現実的に起きやすい失敗（日をまたぐ複数日の処理中に
  /// 1日だけ失敗する、次回同期まで中断する）に対しては安全に回復できる。
  Future<void> _backfillMissedDays() async {
    final lastSynced = _lastSyncedAt;
    if (lastSynced == null) return;

    final now = _now();
    final todayDate = DateTime(now.year, now.month, now.day);

    // さかのぼり対象の下限日は初回同期時に一度だけ固定する。「前回同期日時」は
    // 同期のたびに更新されるため、それをそのまま下限にすると、取得や保存に
    // 失敗して未コミットのまま残った日が次回以降ずっと対象から外れてしまう
    // （二度と拾えなくなる）。
    var floorDateKey = _storage.loadBackfillFloorDate();
    if (floorDateKey == null) {
      floorDateKey = formatDateKey(
        DateTime(lastSynced.year, lastSynced.month, lastSynced.day),
      );
      await _storage.saveBackfillFloorDate(floorDateKey);
    }
    final floorDate = DateTime.parse(floorDateKey);

    final committed = _storage.loadBackfillCommittedDates();

    final candidateDates = <DateTime>[];
    var date = todayDate.subtract(const Duration(days: 1));
    var daysScanned = 0;
    while (date.isAfter(floorDate) && daysScanned < _maxBackfillDays) {
      if (!committed.contains(formatDateKey(date))) {
        candidateDates.add(date);
      }
      date = date.subtract(const Duration(days: 1));
      daysScanned++;
    }
    if (candidateDates.isEmpty) return;

    // 満タン履歴が日付順に並ぶよう、加算は古い日から行う。
    candidateDates.sort((a, b) => a.compareTo(b));

    // 各日の取得は互いに独立しているため並列に行うが、1件の失敗・例外が他の日の結果を
    // 巻き込んで失わないよう、日ごとに個別に例外を処理して null（取得失敗）に変換する。
    final stepsPerDate = await Future.wait(
      candidateDates.map((d) async {
        try {
          return await _healthService.getStepsForDate(d);
        } catch (_) {
          return null;
        }
      }),
    );

    final settings = _settingsProvider.settings;

    for (var i = 0; i < candidateDates.length; i++) {
      final steps = stepsPerDate[i];
      // 取得できなかった日はコミットせずスキップする（次回また候補になる）。
      if (steps == null) continue;

      final dateKey = formatDateKey(candidateDates[i]);
      final energyWh = steps <= 0
          ? 0.0
          : EnergyCalculator.calculateEnergyWh(
              steps: steps,
              weightKg: settings.weightKg,
              speedKmh: settings.defaultSpeedKmh,
              coefficient: _coefficientSupplier(),
            );
      final batteriesFilled = steps <= 0 ? 0 : _applyEnergyGain(energyWh);

      await _storage.saveDailyStepRecord(DailyStepRecord(
        date: dateKey,
        totalSteps: steps,
        totalEnergyWh: energyWh,
        lastSyncedSteps: steps,
      ));

      if (batteriesFilled > 0) {
        await _recordFullBatteries(dateKey, batteriesFilled);
        _pendingBatteries += batteriesFilled;
      }

      // この日までの反映結果を確定させてからコミット済みマーカーを追加する。
      await _storage.saveBatteryState(_battery);
      await _storage.saveLifetimeEnergyWh(_lifetimeEnergyWh);
      await _storage.savePendingBatteries(_pendingBatteries);

      committed.add(dateKey);
      await _storage.saveBackfillCommittedDates(committed);
    }
  }

  /// エネルギーを蓄電池・累積発電量に反映する（メモリ上のみ、永続化はしない）。
  /// 満タンになった回数を返す。
  int _applyEnergyGain(double energyWh) {
    final addResult = _battery.addEnergy(energyWh);
    _battery = addResult.state;
    _lifetimeEnergyWh += energyWh;
    return addResult.batteriesFilled;
  }

  /// ストックを指定個数消費する。不足していれば消費せず false を返す。
  Future<bool> consumeStockedBatteries(int amount) async {
    if (_pendingBatteries < amount) return false;
    _pendingBatteries -= amount;
    await _storage.savePendingBatteries(_pendingBatteries);
    notifyListeners();
    return true;
  }

  /// [consumeStockedBatteries] のロールバック用。消費後に後続処理が失敗した場合、
  /// 消費した分をストックに戻す。
  Future<void> creditStockedBatteries(int amount) async {
    _pendingBatteries += amount;
    await _storage.savePendingBatteries(_pendingBatteries);
    notifyListeners();
  }

  /// 満タンになった蓄電池を指定日の履歴に記録する。
  Future<void> _recordFullBatteries(String dateKey, int count) async {
    final events = _storage.loadFullBatteryEvents();
    final newEvents = [
      ...events,
      for (var i = 0; i < count; i++)
        FullBatteryEvent(number: events.length + i + 1, date: dateKey),
    ];
    await _storage.saveFullBatteryEvents(newEvents);
  }

  /// 給餌効果などにより変化した蓄電池状態を反映・永続化する。
  Future<void> applyBatteryState(BatteryState battery) async {
    _battery = battery;
    await _storage.saveBatteryState(_battery);
    notifyListeners();
  }

  /// 永続化済みの値で表示を更新する。
  void refreshDisplay() {
    final companion = _storage.loadCompanionState();
    _battery = _storage.loadBatteryState(companion);
    _today = _storage.loadDailyStepRecord(formatDateKey(_now()));
    _lastSyncedAt = _storage.loadLastSyncedAt();
    _lifetimeEnergyWh = _storage.loadLifetimeEnergyWh();
    _pendingBatteries = _storage.loadPendingBatteries();
    notifyListeners();
  }

  /// 蓄電池・累積発電量・ストックを初期状態に戻す（全履歴クリアと連動）。
  /// 同期カーソル（[LocalStorage.loadTodaySyncedCursor]）には触れない。ここを
  /// リセットすると、今日すでに同期済みの歩数が次回同期で新規分として
  /// 再加算されてしまうため。
  Future<void> resetProgress() async {
    await _storage.saveBatteryState(
      const BatteryState(storedWh: 0, capacityWh: 0),
    );
    await _storage.saveLifetimeEnergyWh(0);
    await _storage.savePendingBatteries(0);
    refreshDisplay();
  }

  Future<void> _persist(String todayKey, int cursorSteps) async {
    await _storage.saveBatteryState(_battery);
    await _storage.saveDailyStepRecord(_today);
    await _storage.saveTodaySyncedCursor(todayKey, cursorSteps);
    if (_lastSyncedAt != null) {
      await _storage.saveLastSyncedAt(_lastSyncedAt!);
    }
    await _storage.saveLifetimeEnergyWh(_lifetimeEnergyWh);
    await _storage.savePendingBatteries(_pendingBatteries);
  }
}
