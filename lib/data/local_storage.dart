import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/game_constants.dart';
import '../domain/models/battery_state.dart';
import '../domain/models/building.dart';
import '../domain/models/daily_step_record.dart';
import '../domain/models/player_settings.dart';
import '../domain/models/town_state.dart';
import '../domain/town_logic.dart';

/// SharedPreferences ラッパー（全モデルの save / load）
class LocalStorage {
  final SharedPreferences _prefs;

  const LocalStorage(this._prefs);

  static const _keyWeight = 'player_weight_kg';
  static const _keySpeed = 'player_default_speed_kmh';
  static const _keyCoefficient = 'player_energy_coefficient';
  static const _keyBatteryStored = 'battery_stored_wh';
  static const _keyTownBuildings = 'town_buildings';
  static const _dailyRecordPrefix = 'daily_record_';
  static const _keyLastSyncedAt = 'last_synced_at';
  static const _keyLifetimeEnergyWh = 'lifetime_energy_wh';
  static const _keyAndroidBaselineDate = 'health_android_baseline_date';
  static const _keyAndroidBaselineSteps = 'health_android_baseline_steps';

  PlayerSettings loadPlayerSettings() {
    return PlayerSettings(
      weightKg: _prefs.getDouble(_keyWeight) ?? GameConstants.defaultWeightKg,
      defaultSpeedKmh:
          _prefs.getDouble(_keySpeed) ?? GameConstants.defaultSpeedKmh,
      energyCoefficient:
          _prefs.getDouble(_keyCoefficient) ?? GameConstants.energyCoefficient,
    );
  }

  Future<void> savePlayerSettings(PlayerSettings settings) async {
    await _prefs.setDouble(_keyWeight, settings.weightKg);
    await _prefs.setDouble(_keySpeed, settings.defaultSpeedKmh);
    await _prefs.setDouble(_keyCoefficient, settings.energyCoefficient);
  }

  /// 蓄電池容量は建物効果から都度算出するため永続化しない（容量は建物リストが真実の源）。
  /// 呼び出し元は事前に [loadTownState] で取得した buildings を渡すこと。
  BatteryState loadBatteryState(List<Building> buildings) {
    return BatteryState(
      storedWh: _prefs.getDouble(_keyBatteryStored) ??
          GameConstants.initialBatteryStoredWh,
      capacityWh: TownLogic.effectiveCapacity(
        GameConstants.initialBatteryCapacityWh,
        buildings,
      ),
    );
  }

  Future<void> saveBatteryState(BatteryState battery) async {
    await _prefs.setDouble(_keyBatteryStored, battery.storedWh);
  }

  TownState loadTownState() {
    final json = _prefs.getString(_keyTownBuildings);
    if (json == null) {
      return TownState.initial();
    }
    return TownState.fromJson(jsonDecode(json) as List<dynamic>);
  }

  Future<void> saveTownState(TownState town) async {
    await _prefs.setString(_keyTownBuildings, jsonEncode(town.toJson()));
  }

  DailyStepRecord loadDailyStepRecord(String date) {
    final json = _prefs.getString('$_dailyRecordPrefix$date');
    if (json == null) {
      return DailyStepRecord.empty(date);
    }
    return DailyStepRecord.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> saveDailyStepRecord(DailyStepRecord record) async {
    await _prefs.setString(
      '$_dailyRecordPrefix${record.date}',
      jsonEncode(record.toJson()),
    );
  }

  /// 保存済みの全日次記録を日付の新しい順に返す。
  List<DailyStepRecord> loadAllDailyRecords() {
    final records = _prefs
        .getKeys()
        .where((k) => k.startsWith(_dailyRecordPrefix))
        .map((k) => _prefs.getString(k))
        .whereType<String>()
        .map((json) =>
            DailyStepRecord.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList();
    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  /// 指定日の日次記録を削除する。
  Future<void> deleteDailyRecord(String date) async {
    await _prefs.remove('$_dailyRecordPrefix$date');
  }

  /// 全ての日次記録を削除する。
  Future<void> clearAllDailyRecords() async {
    final keys =
        _prefs.getKeys().where((k) => k.startsWith(_dailyRecordPrefix));
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  DateTime? loadLastSyncedAt() {
    final iso = _prefs.getString(_keyLastSyncedAt);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  Future<void> saveLastSyncedAt(DateTime time) async {
    await _prefs.setString(_keyLastSyncedAt, time.toIso8601String());
  }

  /// 蓄電池の消費に関わらず、生涯で発電した総エネルギー量 (Wh)。
  double loadLifetimeEnergyWh() => _prefs.getDouble(_keyLifetimeEnergyWh) ?? 0.0;

  Future<void> saveLifetimeEnergyWh(double wh) async {
    await _prefs.setDouble(_keyLifetimeEnergyWh, wh);
  }

  /// Android センサーの「今日0:00時点の累積歩数」ベースライン。
  ({String? date, int? steps}) loadAndroidStepBaseline() => (
        date: _prefs.getString(_keyAndroidBaselineDate),
        steps: _prefs.getInt(_keyAndroidBaselineSteps),
      );

  Future<void> saveAndroidStepBaseline(String date, int steps) async {
    await _prefs.setString(_keyAndroidBaselineDate, date);
    await _prefs.setInt(_keyAndroidBaselineSteps, steps);
  }
}
