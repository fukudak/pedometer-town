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

  /// Health から今日の歩数を取得し、差分をエネルギーに変換して蓄電池に加算する。
  /// 前回同期から日をまたいで開いていなかった場合、間の日の歩数もさかのぼって加算を試みる
  /// （iOS のみ。Android はベースライン繰り越しで日またぎに対応済み）。
  Future<void> syncStepsFromHealth() async {
    await _healthService.requestPermissions();
    await _backfillMissedDays();

    final todayKey = formatDateKey(_now());
    if (_today.date != todayKey) {
      _today = DailyStepRecord.empty(todayKey);
    }

    final totalSteps = await _healthService.getTodaySteps();
    final deltaSteps = totalSteps - _today.lastSyncedSteps;

    // delta < 0 は再起動によるセンサーリセット。センサー現在値を新規歩数として扱う。
    final effectiveDelta = deltaSteps < 0 ? totalSteps : deltaSteps;

    if (effectiveDelta == 0) {
      _today = _today.copyWith(lastSyncedSteps: totalSteps);
      _lastSyncedAt = _now();
      await _persist();
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
      await _recordFullBatteries(batteriesFilled);
      _pendingBatteries += batteriesFilled;
    }

    await _persist();
    notifyListeners();
  }

  /// 前回同期日の翌日から昨日までのうち、記録の無い日の歩数を取得できればエネルギーとして
  /// 加算する。取得できない日（Android や HealthKit 側にデータが無い日）はスキップする
  /// （ベストエフォート）。
  ///
  /// 走査は **昨日から新しい順** に行い、[_maxBackfillDays] 日より前は打ち切る。
  /// 古い順に走査すると、長期間アプリを開かなかったときに上限を古い日で使い切ってしまい、
  /// 直近の歩数が取りこぼされるため。
  /// 各日の取得は互いに独立しているため並列に行い、蓄電池・累積発電量・満タン履歴は
  /// ループ内では永続化せず、最後にまとめて1回だけ書き込む。
  Future<void> _backfillMissedDays() async {
    final lastSynced = _lastSyncedAt;
    if (lastSynced == null) return;

    final now = _now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final lastSyncedDate =
        DateTime(lastSynced.year, lastSynced.month, lastSynced.day);

    final candidateDates = <DateTime>[];
    var date = todayDate.subtract(const Duration(days: 1));
    var daysScanned = 0;
    while (date.isAfter(lastSyncedDate) && daysScanned < _maxBackfillDays) {
      if (_storage.loadDailyStepRecord(formatDateKey(date)).totalSteps == 0) {
        candidateDates.add(date);
      }
      date = date.subtract(const Duration(days: 1));
      daysScanned++;
    }
    if (candidateDates.isEmpty) return;

    // 満タン履歴が日付順に並ぶよう、加算は古い日から行う。
    candidateDates.sort((a, b) => a.compareTo(b));

    final stepsPerDate = await Future.wait(
      candidateDates.map(_healthService.getStepsForDate),
    );

    var batteryChanged = false;
    final existingFullBatteryEvents = _storage.loadFullBatteryEvents();
    final newFullBatteryEvents = <FullBatteryEvent>[];
    final settings = _settingsProvider.settings;

    for (var i = 0; i < candidateDates.length; i++) {
      final steps = stepsPerDate[i];
      if (steps == null || steps <= 0) continue;
      batteryChanged = true;

      final dateKey = formatDateKey(candidateDates[i]);
      final energyWh = EnergyCalculator.calculateEnergyWh(
        steps: steps,
        weightKg: settings.weightKg,
        speedKmh: settings.defaultSpeedKmh,
        coefficient: _coefficientSupplier(),
      );
      final batteriesFilled = _applyEnergyGain(energyWh);

      await _storage.saveDailyStepRecord(DailyStepRecord(
        date: dateKey,
        totalSteps: steps,
        totalEnergyWh: energyWh,
        lastSyncedSteps: steps,
      ));

      for (var n = 0; n < batteriesFilled; n++) {
        newFullBatteryEvents.add(FullBatteryEvent(
          number: existingFullBatteryEvents.length + newFullBatteryEvents.length + 1,
          date: dateKey,
        ));
      }
      _pendingBatteries += batteriesFilled;
    }

    if (!batteryChanged) return;

    await _storage.saveBatteryState(_battery);
    await _storage.saveLifetimeEnergyWh(_lifetimeEnergyWh);
    await _storage.savePendingBatteries(_pendingBatteries);
    if (newFullBatteryEvents.isNotEmpty) {
      await _storage.saveFullBatteryEvents(
        [...existingFullBatteryEvents, ...newFullBatteryEvents],
      );
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

  /// 今日満タンになった蓄電池を履歴に記録する。
  Future<void> _recordFullBatteries(int count) async {
    final events = _storage.loadFullBatteryEvents();
    final todayKey = formatDateKey(_now());
    final newEvents = [
      ...events,
      for (var i = 0; i < count; i++)
        FullBatteryEvent(number: events.length + i + 1, date: todayKey),
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

  Future<void> _persist() async {
    await _storage.saveBatteryState(_battery);
    await _storage.saveDailyStepRecord(_today);
    if (_lastSyncedAt != null) {
      await _storage.saveLastSyncedAt(_lastSyncedAt!);
    }
    await _storage.saveLifetimeEnergyWh(_lifetimeEnergyWh);
    await _storage.savePendingBatteries(_pendingBatteries);
  }
}
