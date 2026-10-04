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
import '../domain/companion_logic.dart';

/// 歩数同期で同時に確定させる状態のスナップショット。
///
/// SharedPreferences は複数キーのトランザクションを提供しないため、この値全体を
/// 先にジャーナルへ保存してから各キーへ反映する。途中でアプリが終了しても、次回起動時に
/// 同じスナップショットを再適用すれば二重加算せず確定状態へ収束できる。
class EnergySyncCommit {
  final BatteryState battery;
  final DailyStepRecord dailyRecord;
  final double lifetimeEnergyWh;
  final int pendingBatteries;
  final List<FullBatteryEvent> fullBatteryEvents;
  final String? syncedDate;
  final int? syncedSteps;
  final DateTime? lastSyncedAt;
  final Set<String>? backfillCommittedDates;

  const EnergySyncCommit({
    required this.battery,
    required this.dailyRecord,
    required this.lifetimeEnergyWh,
    required this.pendingBatteries,
    required this.fullBatteryEvents,
    this.syncedDate,
    this.syncedSteps,
    this.lastSyncedAt,
    this.backfillCommittedDates,
  });

  Map<String, dynamic> toJson() => {
    'version': 1,
    'batteryStoredWh': battery.storedWh,
    'dailyRecord': dailyRecord.toJson(),
    'lifetimeEnergyWh': lifetimeEnergyWh,
    'pendingBatteries': pendingBatteries,
    'fullBatteryEvents': fullBatteryEvents
        .map((event) => event.toJson())
        .toList(),
    if (syncedDate != null) 'syncedDate': syncedDate,
    if (syncedSteps != null) 'syncedSteps': syncedSteps,
    if (lastSyncedAt != null) 'lastSyncedAt': lastSyncedAt!.toIso8601String(),
    if (backfillCommittedDates != null)
      'backfillCommittedDates': backfillCommittedDates!.toList(),
  };

  factory EnergySyncCommit.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('未対応の同期ジャーナル形式です');
    }
    return EnergySyncCommit(
      battery: BatteryState(
        storedWh: (json['batteryStoredWh'] as num).toDouble(),
        // 容量は永続化せず CompanionState から導出するため、復旧時には使用しない。
        capacityWh: 0,
      ),
      dailyRecord: DailyStepRecord.fromJson(
        Map<String, dynamic>.from(json['dailyRecord'] as Map),
      ),
      lifetimeEnergyWh: (json['lifetimeEnergyWh'] as num).toDouble(),
      pendingBatteries: json['pendingBatteries'] as int,
      fullBatteryEvents: (json['fullBatteryEvents'] as List<dynamic>)
          .map(
            (event) => FullBatteryEvent.fromJson(
              Map<String, dynamic>.from(event as Map),
            ),
          )
          .toList(),
      syncedDate: json['syncedDate'] as String?,
      syncedSteps: json['syncedSteps'] as int?,
      lastSyncedAt: json['lastSyncedAt'] == null
          ? null
          : DateTime.parse(json['lastSyncedAt'] as String),
      backfillCommittedDates: json['backfillCommittedDates'] == null
          ? null
          : (json['backfillCommittedDates'] as List<dynamic>)
                .cast<String>()
                .toSet(),
    );
  }
}

/// 電池投入で同時に確定させる状態のスナップショット。
class InvestmentCommit {
  final CompanionState companion;
  final int pendingBatteries;
  final DateTime lastFedAt;
  final List<AchievementEvent> achievementEvents;
  final List<CompanionStageEvent> stageEvents;
  final Set<String> celebratedStageIds;

  const InvestmentCommit({
    required this.companion,
    required this.pendingBatteries,
    required this.lastFedAt,
    required this.achievementEvents,
    required this.stageEvents,
    required this.celebratedStageIds,
  });

  Map<String, dynamic> toJson() => {
    'version': 1,
    'companion': {
      'mealCount': companion.mealCount,
      'boosterCount': companion.boosterCount,
      'toyCount': companion.toyCount,
    },
    'pendingBatteries': pendingBatteries,
    'lastFedAt': lastFedAt.toIso8601String(),
    'achievementEvents': achievementEvents
        .map((event) => event.toJson())
        .toList(),
    'stageEvents': stageEvents.map((event) => event.toJson()).toList(),
    'celebratedStageIds': celebratedStageIds.toList(),
  };

  factory InvestmentCommit.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('未対応の投入ジャーナル形式です');
    }
    final companionJson = Map<String, dynamic>.from(json['companion'] as Map);
    return InvestmentCommit(
      companion: CompanionState(
        mealCount: companionJson['mealCount'] as int,
        boosterCount: companionJson['boosterCount'] as int,
        toyCount: companionJson['toyCount'] as int,
      ),
      pendingBatteries: json['pendingBatteries'] as int,
      lastFedAt: DateTime.parse(json['lastFedAt'] as String),
      achievementEvents: (json['achievementEvents'] as List<dynamic>)
          .map(
            (event) => AchievementEvent.fromJson(
              Map<String, dynamic>.from(event as Map),
            ),
          )
          .toList(),
      stageEvents: (json['stageEvents'] as List<dynamic>)
          .map(
            (event) => CompanionStageEvent.fromJson(
              Map<String, dynamic>.from(event as Map),
            ),
          )
          .toList(),
      celebratedStageIds: (json['celebratedStageIds'] as List<dynamic>)
          .cast<String>()
          .toSet(),
    );
  }
}

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
  static const _keyAchievementEvents = 'companion_achievement_events';
  static const _keyPendingBatteries = 'pending_batteries';
  static const _keyCelebratedStageIds = 'companion_celebrated_stage_ids';
  static const _keyCompanionStageEvents = 'companion_stage_events';
  static const _keyCompanionName = 'companion_name';
  static const _keyCompanionLastFedAt = 'companion_last_fed_at';
  static const _keyTodaySyncedDate = 'today_synced_date';
  static const _keyTodaySyncedSteps = 'today_synced_steps';
  static const _keyBackfillCommittedDates = 'backfill_committed_dates';
  static const _keyBackfillFloorDate = 'backfill_floor_date';
  static const _keyEnergySyncJournal = 'energy_sync_journal';
  static const _keyInvestmentJournal = 'investment_journal';

  PlayerSettings loadPlayerSettings() {
    return PlayerSettings(
      weightKg: _prefs.getDouble(_keyWeight) ?? GameConstants.defaultWeightKg,
      defaultSpeedKmh:
          _prefs.getDouble(_keySpeed) ?? GameConstants.defaultSpeedKmh,
      energyCoefficient:
          _prefs.getDouble(_keyCoefficient) ?? GameConstants.energyCoefficient,
      companionName: _prefs.getString(_keyCompanionName) ?? '',
    );
  }

  Future<void> savePlayerSettings(PlayerSettings settings) async {
    await _prefs.setDouble(_keyWeight, settings.weightKg);
    await _prefs.setDouble(_keySpeed, settings.defaultSpeedKmh);
    await _prefs.setDouble(_keyCoefficient, settings.energyCoefficient);
    await _prefs.setString(_keyCompanionName, settings.companionName);
  }

  /// 蓄電池容量は相棒の給餌効果から都度算出するため永続化しない。
  /// 呼び出し元は事前に [loadCompanionState] で取得した companion を渡すこと。
  BatteryState loadBatteryState(CompanionState companion) {
    return BatteryState(
      storedWh:
          _prefs.getDouble(_keyBatteryStored) ??
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
    final hasCompanionData =
        _prefs.containsKey(_keyCompanionMealCount) ||
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

    try {
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
    } on Object {
      return null;
    }
  }

  DailyStepRecord loadDailyStepRecord(String date) {
    final json = _prefs.getString('$_dailyRecordPrefix$date');
    if (json == null) {
      return DailyStepRecord.empty(date);
    }
    try {
      return DailyStepRecord.fromJson(
        Map<String, dynamic>.from(jsonDecode(json) as Map),
      );
    } on Object {
      return DailyStepRecord.empty(date);
    }
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
        .map((json) {
          try {
            return DailyStepRecord.fromJson(
              Map<String, dynamic>.from(jsonDecode(json) as Map),
            );
          } on Object {
            return null;
          }
        })
        .whereType<DailyStepRecord>()
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
    final keys = _prefs.getKeys().where(
      (k) => k.startsWith(_dailyRecordPrefix),
    );
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
  double loadLifetimeEnergyWh() =>
      _prefs.getDouble(_keyLifetimeEnergyWh) ?? 0.0;

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
    try {
      return (jsonDecode(json) as List<dynamic>)
          .map(
            (event) => FullBatteryEvent.fromJson(
              Map<String, dynamic>.from(event as Map),
            ),
          )
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> saveFullBatteryEvents(List<FullBatteryEvent> events) async {
    await _prefs.setString(
      _keyFullBatteryEvents,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );
  }

  /// 解除済みの実績を、解除した順に返す。
  List<AchievementEvent> loadAchievementEvents() {
    final json = _prefs.getString(_keyAchievementEvents);
    if (json == null) return [];
    try {
      return (jsonDecode(json) as List<dynamic>)
          .map(
            (event) => AchievementEvent.fromJson(
              Map<String, dynamic>.from(event as Map),
            ),
          )
          .toList();
    } on Object {
      return [];
    }
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
    try {
      return (jsonDecode(json) as List<dynamic>)
          .map(
            (event) => CompanionStageEvent.fromJson(
              Map<String, dynamic>.from(event as Map),
            ),
          )
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> saveCompanionStageEvents(
    List<CompanionStageEvent> events,
  ) async {
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

  /// 今日すでに同期済みの歩数カーソル（同期差分の計算専用）。
  /// 画面に表示する日次記録（[loadDailyStepRecord] 等）とは別に保持し、
  /// 履歴の削除・全クリアの影響を受けない。
  ({String? date, int steps}) loadTodaySyncedCursor() => (
    date: _prefs.getString(_keyTodaySyncedDate),
    steps: _prefs.getInt(_keyTodaySyncedSteps) ?? 0,
  );

  Future<void> saveTodaySyncedCursor(String date, int steps) async {
    await _prefs.setString(_keyTodaySyncedDate, date);
    await _prefs.setInt(_keyTodaySyncedSteps, steps);
  }

  /// さかのぼり同期で、日次記録・蓄電池等への反映まで完了済みの日付一覧。
  /// 未完了のまま中断した日は含まれず、次回同期で再試行される。
  Set<String> loadBackfillCommittedDates() =>
      (_prefs.getStringList(_keyBackfillCommittedDates) ?? const []).toSet();

  Future<void> saveBackfillCommittedDates(Set<String> dates) async {
    await _prefs.setStringList(_keyBackfillCommittedDates, dates.toList());
  }

  /// さかのぼり同期の対象とする最古の日付（これより前の日は対象にしない）。
  /// 初回同期時の日付で一度だけ固定し、以降は動かさない。
  /// 「前回同期日時」は同期のたびに更新されるため、それをそのまま基準にすると
  /// 一度失敗した日が次回以降ずっと対象から外れてしまう問題を避けるための専用値。
  String? loadBackfillFloorDate() => _prefs.getString(_keyBackfillFloorDate);

  Future<void> saveBackfillFloorDate(String date) async {
    await _prefs.setString(_keyBackfillFloorDate, date);
  }

  /// 歩数同期に関係する複数キーを、復旧可能な1つの論理コミットとして保存する。
  Future<void> commitEnergySync(EnergySyncCommit commit) async {
    await _prefs.setString(_keyEnergySyncJournal, jsonEncode(commit.toJson()));
    await beforeEnergySyncCommitStep('journal_saved');
    await _applyEnergySyncCommit(commit);
    await _prefs.remove(_keyEnergySyncJournal);
  }

  /// 前回の同期が複数キーへの反映途中で終了していた場合、保存済みスナップショットを
  /// 再適用して確定状態へ復旧する。再適用は同じ値による上書きなので冪等。
  Future<bool> recoverPendingEnergySync() async {
    final raw = _prefs.getString(_keyEnergySyncJournal);
    if (raw == null) return false;
    late final EnergySyncCommit commit;
    try {
      commit = EnergySyncCommit.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on Object {
      // 復旧不能なジャーナルを残すと以後すべての同期が停止するため破棄する。
      await _prefs.remove(_keyEnergySyncJournal);
      return false;
    }
    await _applyEnergySyncCommit(commit);
    await _prefs.remove(_keyEnergySyncJournal);
    return true;
  }

  Future<void> _applyEnergySyncCommit(EnergySyncCommit commit) async {
    await saveDailyStepRecord(commit.dailyRecord);
    await beforeEnergySyncCommitStep('daily_record_saved');
    await saveBatteryState(commit.battery);
    await beforeEnergySyncCommitStep('battery_saved');
    await saveLifetimeEnergyWh(commit.lifetimeEnergyWh);
    await beforeEnergySyncCommitStep('lifetime_saved');
    await savePendingBatteries(commit.pendingBatteries);
    await beforeEnergySyncCommitStep('pending_batteries_saved');
    await saveFullBatteryEvents(commit.fullBatteryEvents);
    await beforeEnergySyncCommitStep('full_battery_events_saved');

    final syncedDate = commit.syncedDate;
    final syncedSteps = commit.syncedSteps;
    if (syncedDate != null && syncedSteps != null) {
      await saveTodaySyncedCursor(syncedDate, syncedSteps);
      await beforeEnergySyncCommitStep('cursor_saved');
    }
    final lastSyncedAt = commit.lastSyncedAt;
    if (lastSyncedAt != null) {
      await saveLastSyncedAt(lastSyncedAt);
      await beforeEnergySyncCommitStep('last_synced_at_saved');
    }
    final committedDates = commit.backfillCommittedDates;
    if (committedDates != null) {
      await saveBackfillCommittedDates(committedDates);
      await beforeEnergySyncCommitStep('backfill_dates_saved');
    }
  }

  /// テストで保存途中の終了を再現するためのフック。通常実装では何もしない。
  Future<void> beforeEnergySyncCommitStep(String step) async {}

  /// 電池ストックの消費と発展更新を、復旧可能な1つの論理コミットとして保存する。
  Future<void> commitInvestment(InvestmentCommit commit) async {
    await _prefs.setString(_keyInvestmentJournal, jsonEncode(commit.toJson()));
    await beforeInvestmentCommitStep('journal_saved');
    await _applyInvestmentCommit(commit);
    await _prefs.remove(_keyInvestmentJournal);
  }

  /// 保存途中で終了した電池投入を同じ確定状態へ収束させる。
  Future<bool> recoverPendingInvestment() async {
    final raw = _prefs.getString(_keyInvestmentJournal);
    if (raw == null) return false;
    late final InvestmentCommit commit;
    try {
      commit = InvestmentCommit.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on Object {
      await _prefs.remove(_keyInvestmentJournal);
      return false;
    }
    await _applyInvestmentCommit(commit);
    await _prefs.remove(_keyInvestmentJournal);
    return true;
  }

  Future<void> _applyInvestmentCommit(InvestmentCommit commit) async {
    await saveCompanionState(commit.companion);
    await beforeInvestmentCommitStep('companion_saved');
    await savePendingBatteries(commit.pendingBatteries);
    await beforeInvestmentCommitStep('pending_batteries_saved');
    await saveCompanionLastFedAt(commit.lastFedAt);
    await beforeInvestmentCommitStep('last_fed_at_saved');
    await saveAchievementEvents(commit.achievementEvents);
    await beforeInvestmentCommitStep('achievements_saved');
    await saveCompanionStageEvents(commit.stageEvents);
    await beforeInvestmentCommitStep('stage_events_saved');
    await saveCelebratedStageIds(commit.celebratedStageIds.toList());
    await beforeInvestmentCommitStep('celebrated_stage_ids_saved');
  }

  /// テストで投入保存途中の終了を再現するためのフック。通常実装では何もしない。
  Future<void> beforeInvestmentCommitStep(String step) async {}
}
