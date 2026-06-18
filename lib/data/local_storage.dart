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
  static const _keyDifficulty = 'player_difficulty';
  static const _keyBatteryStored = 'battery_stored_wh';
  static const _keyTownBuildings = 'town_buildings';
  static const _dailyRecordPrefix = 'daily_record_';

  PlayerSettings loadPlayerSettings() {
    return PlayerSettings(
      weightKg: _prefs.getDouble(_keyWeight) ?? GameConstants.defaultWeightKg,
      defaultSpeedKmh:
          _prefs.getDouble(_keySpeed) ?? GameConstants.defaultSpeedKmh,
      difficulty:
          _prefs.getString(_keyDifficulty) ?? GameConstants.defaultDifficulty,
    );
  }

  Future<void> savePlayerSettings(PlayerSettings settings) async {
    await _prefs.setDouble(_keyWeight, settings.weightKg);
    await _prefs.setDouble(_keySpeed, settings.defaultSpeedKmh);
    await _prefs.setString(_keyDifficulty, settings.difficulty);
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
}
