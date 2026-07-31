import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/game_constants.dart';
import '../domain/models/achievement_event.dart';
import '../domain/models/battery_state.dart';
import '../domain/models/companion_stage_event.dart';
import '../domain/models/companion_state.dart';
import '../domain/models/daily_step_record.dart';
import '../domain/models/full_battery_event.dart';
import '../domain/models/player_settings.dart';
import '../domain/models/sparkle_event.dart';
import '../domain/companion_logic.dart';

/// SharedPreferences ラッパー（全モデルの save / load）
class LocalStorage {
  final SharedPreferences _prefs;

  const LocalStorage(this._prefs);

  static const _keyWeight = 'player_weight_kg';
  static const _keySpeed = 'player_default_speed_kmh';
  static const _keyCoefficient = 'player_energy_coefficient';
  static const _keyBatteryStored = 'battery_stored_wh';
  static const _keyCompanionMealCount = 'companion_meal_count';
  static const _keyCompanionBoosterCount = 'companion_booster_count';
  static const _keyCompanionToyCount = 'companion_toy_count';
  static const _keyLegacyTownBuildings = 'town_buildings';
  static const _dailyRecordPrefix = 'daily_record_';
  static const _keyLastSyncedAt = 'last_synced_at';
  static const _keyLifetimeEnergyWh = 'lifetime_energy_wh';
  static const _keyAndroidBaselineDate = 'health_android_baseline_date';
  static const _keyAndroidBaselineSteps = 'health_android_baseline_steps';
  static const _keyFullBatteryEvents = 'full_battery_events';
  static const _keySparkleEvents = 'sparkle_events';
  static const _keyAchievementEvents = 'companion_achievement_events';
  static const _keyPendingBatteries = 'pending_batteries';
  static const _keyCelebratedStageIds = 'companion_celebrated_stage_ids';
  static const _keyCompanionStageEvents = 'companion_stage_events';
  static const _keyCompanionWeatherFx = 'companion_weather_fx_enabled';
  static const _keyCompanionName = 'companion_name';
  static const _keyCompanionLastFedAt = 'companion_last_fed_at';

  PlayerSettings loadPlayerSettings() {
    return PlayerSettings(
      weightKg: _prefs.getDouble(_keyWeight) ?? GameConstants.defaultWeightKg,
      defaultSpeedKmh:
          _prefs.getDouble(_keySpeed) ?? GameConstants.defaultSpeedKmh,
      energyCoefficient:
          _prefs.getDouble(_keyCoefficient) ?? GameConstants.energyCoefficient,
      companionWeatherFxEnabled:
          _prefs.getBool(_keyCompanionWeatherFx) ?? true,
      companionName: _prefs.getString(_keyCompanionName) ?? '',
    );
  }

  Future<void> savePlayerSettings(PlayerSettings settings) async {
    await _prefs.setDouble(_keyWeight, settings.weightKg);
    await _prefs.setDouble(_keySpeed, settings.defaultSpeedKmh);
    await _prefs.setDouble(_keyCoefficient, settings.energyCoefficient);
    await _prefs.setBool(
        _keyCompanionWeatherFx, settings.companionWeatherFxEnabled);
    await _prefs.setString(_keyCompanionName, settings.companionName);
  }

  /// 蓄電池容量は相棒の給餌効果から都度算出するため永続化しない。
  /// 呼び出し元は事前に [loadCompanionState] で取得した companion を渡すこと。
  BatteryState loadBatteryState(CompanionState companion) {
    return BatteryState(
      storedWh: _prefs.getDouble(_keyBatteryStored) ??
          GameConstants.initialBatteryStoredWh,
      capacityWh: CompanionLogic.effectiveCapacity(
        GameConstants.initialBatteryCapacityWh,
        companion,
      ),
    );
  }

  Future<void> saveBatteryState(BatteryState battery) async {
    await _prefs.setDouble(_keyBatteryStored, battery.storedWh);
  }

  /// 相棒の状態を読み込む。種類別カウントが一つも保存されていない場合、
  /// 旧「町の建物」データ（house/powerPlant/park）が残っていれば個数を引き継ぐ。
  CompanionState loadCompanionState() {
    final hasCompanionData = _prefs.containsKey(_keyCompanionMealCount) ||
        _prefs.containsKey(_keyCompanionBoosterCount) ||
        _prefs.containsKey(_keyCompanionToyCount);

    if (!hasCompanionData) {
      final migrated = _migrateFromLegacyTownBuildings();
      if (migrated != null) return migrated;
      return CompanionState.initial();
    }

    return CompanionState(
      mealCount: _prefs.getInt(_keyCompanionMealCount) ?? 0,
      boosterCount: _prefs.getInt(_keyCompanionBoosterCount) ?? 0,
      toyCount: _prefs.getInt(_keyCompanionToyCount) ?? 0,
    );
  }

  Future<void> saveCompanionState(CompanionState companion) async {
    await _prefs.setInt(_keyCompanionMealCount, companion.mealCount);
    await _prefs.setInt(_keyCompanionBoosterCount, companion.boosterCount);
    await _prefs.setInt(_keyCompanionToyCount, companion.toyCount);
  }

  /// 旧バージョン（町ビルド）の建物リストを、種類別の給餌回数に変換する。
  /// 座標・建設順は破棄し、種類ごとの個数のみを引き継ぐ。
  CompanionState? _migrateFromLegacyTownBuildings() {
    final json = _prefs.getString(_keyLegacyTownBuildings);
    if (json == null) return null;

    var mealCount = 0;
    var boosterCount = 0;
    var toyCount = 0;
    for (final entry in jsonDecode(json) as List<dynamic>) {
      final type = (entry as Map<String, dynamic>)['type'] as String;
      switch (type) {
        case 'house':
          mealCount++;
        case 'powerPlant':
          boosterCount++;
        case 'park':
          toyCount++;
      }
    }
    return CompanionState(
      mealCount: mealCount,
      boosterCount: boosterCount,
      toyCount: toyCount,
    );
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

  /// 蓄電池が満タンになった記録を、古い順に返す。
  List<FullBatteryEvent> loadFullBatteryEvents() {
    final json = _prefs.getString(_keyFullBatteryEvents);
    if (json == null) return [];
    return (jsonDecode(json) as List<dynamic>)
        .map((e) => FullBatteryEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveFullBatteryEvents(List<FullBatteryEvent> events) async {
    await _prefs.setString(
      _keyFullBatteryEvents,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );
  }

  /// きらめきタイムが発生した記録を、古い順に返す。
  List<SparkleEvent> loadSparkleEvents() {
    final json = _prefs.getString(_keySparkleEvents);
    if (json == null) return [];
    return (jsonDecode(json) as List<dynamic>)
        .map((e) => SparkleEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveSparkleEvents(List<SparkleEvent> events) async {
    await _prefs.setString(
      _keySparkleEvents,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );
  }

  /// 解除済みの実績を、解除した順に返す。
  List<AchievementEvent> loadAchievementEvents() {
    final json = _prefs.getString(_keyAchievementEvents);
    if (json == null) return [];
    return (jsonDecode(json) as List<dynamic>)
        .map((e) => AchievementEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAchievementEvents(List<AchievementEvent> events) async {
    await _prefs.setString(
      _keyAchievementEvents,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );
  }

  /// 満タンになったがまだ相棒に与えられていない蓄電池の個数。
  int loadPendingBatteries() => _prefs.getInt(_keyPendingBatteries) ?? 0;

  Future<void> savePendingBatteries(int count) async {
    await _prefs.setInt(_keyPendingBatteries, count);
  }

  /// 進化段階の祝福を表示済みの stageId 一覧。
  /// 未設定（null）は「初回マイグレーション未実行」を意味する。
  List<String>? loadCelebratedStageIds() {
    if (!_prefs.containsKey(_keyCelebratedStageIds)) return null;
    return _prefs.getStringList(_keyCelebratedStageIds) ?? <String>[];
  }

  Future<void> saveCelebratedStageIds(List<String> stageIds) async {
    await _prefs.setStringList(
      _keyCelebratedStageIds,
      stageIds.toSet().toList(),
    );
  }

  /// 進化段階到達の履歴（古い順）。
  List<CompanionStageEvent> loadCompanionStageEvents() {
    final json = _prefs.getString(_keyCompanionStageEvents);
    if (json == null) return [];
    return (jsonDecode(json) as List<dynamic>)
        .map((e) => CompanionStageEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCompanionStageEvents(List<CompanionStageEvent> events) async {
    await _prefs.setString(
      _keyCompanionStageEvents,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );
  }

  /// 最終給餌日時（きげん計算用）。まだ一度も給餌していない場合は null。
  DateTime? loadCompanionLastFedAt() {
    final iso = _prefs.getString(_keyCompanionLastFedAt);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  Future<void> saveCompanionLastFedAt(DateTime time) async {
    await _prefs.setString(_keyCompanionLastFedAt, time.toIso8601String());
  }
}
