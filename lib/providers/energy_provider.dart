import 'package:flutter/foundation.dart';

import '../constants/game_constants.dart';
import '../data/local_storage.dart';
import '../domain/energy_calculator.dart';
import '../domain/models/battery_state.dart';
import '../domain/models/daily_step_record.dart';
import '../domain/models/full_battery_event.dart';
import '../services/health_service.dart';
import 'settings_provider.dart';

/// 蓄電池・今日の歩数/エネルギーの状態管理
class EnergyProvider extends ChangeNotifier {
  final LocalStorage _storage;
  final HealthService _healthService;
  final SettingsProvider _settingsProvider;

  final DateTime Function() _now;
  double Function() _coefficientSupplier;
  Future<void> Function(int count)? _onBatteryFull;

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
        _battery = _storage.loadBatteryState(_storage.loadTownState().buildings),
        _today = _storage
            .loadDailyStepRecord(_dateKey((now ?? DateTime.now)())),
        _lastSyncedAt = _storage.loadLastSyncedAt(),
        _lifetimeEnergyWh = _storage.loadLifetimeEnergyWh(),
        _pendingBatteries = _storage.loadPendingBatteries();

  void setCoefficientSupplier(double Function() supplier) {
    _coefficientSupplier = supplier;
  }

  /// 蓄電池が満タンになった回数を通知するコールバックを設定する
  /// （街の自動発展に使用）。
  void setOnBatteryFull(Future<void> Function(int count) callback) {
    _onBatteryFull = callback;
  }

  BatteryState get battery => _battery;
  DailyStepRecord get today => _today;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  double get lifetimeEnergyWh => _lifetimeEnergyWh;

  /// 満タンになったがまだ街の発展に使われていない蓄電池の個数。
  int get pendingBatteries => _pendingBatteries;

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Health から今日の歩数を取得し、差分をエネルギーに変換して蓄電池に加算する。
  Future<void> syncStepsFromHealth() async {
    await _healthService.requestPermissions();

    final todayKey = _dateKey(_now());
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

    final addResult = _battery.addEnergy(newEnergyWh);
    _battery = addResult.state;
    _today = _today.copyWith(
      totalSteps: _today.totalSteps + effectiveDelta,
      totalEnergyWh: _today.totalEnergyWh + newEnergyWh,
      lastSyncedSteps: totalSteps,
    );
    _lifetimeEnergyWh += newEnergyWh;
    _lastSyncedAt = _now();

    if (addResult.batteriesFilled > 0) {
      await _recordFullBatteries(addResult.batteriesFilled);
      _pendingBatteries += addResult.batteriesFilled;
    }

    await _persist();
    notifyListeners();
  }

  /// ストックした満タン分を使って街を発展させる。
  Future<void> useStockedBatteries() async {
    if (_pendingBatteries == 0 || _onBatteryFull == null) return;
    final count = _pendingBatteries;
    _pendingBatteries = 0;
    await _storage.savePendingBatteries(_pendingBatteries);
    await _onBatteryFull!(count);
    notifyListeners();
  }

  /// 満タンになった蓄電池を履歴に記録する。
  Future<void> _recordFullBatteries(int count) async {
    final events = _storage.loadFullBatteryEvents();
    final todayKey = _dateKey(_now());
    final newEvents = [
      ...events,
      for (var i = 0; i < count; i++)
        FullBatteryEvent(number: events.length + i + 1, date: todayKey),
    ];
    await _storage.saveFullBatteryEvents(newEvents);
  }

  /// 建物効果などにより変化した蓄電池状態を反映・永続化する。
  Future<void> applyBatteryState(BatteryState battery) async {
    _battery = battery;
    await _storage.saveBatteryState(_battery);
    notifyListeners();
  }

  /// 永続化済みの値で表示を更新する。
  void refreshDisplay() {
    final town = _storage.loadTownState();
    _battery = _storage.loadBatteryState(town.buildings);
    _today = _storage.loadDailyStepRecord(_dateKey(_now()));
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
