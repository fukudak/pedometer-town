import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants/achievements.dart';
import '../constants/companion_stages.dart';
import '../constants/game_constants.dart';
import '../data/local_storage.dart';
import '../domain/companion_logic.dart';
import '../domain/models/achievement_event.dart';
import '../domain/models/companion_state.dart';
import '../domain/models/companion_stage_event.dart';
import '../domain/models/feed_event.dart';
import '../domain/models/feed_item_type.dart';
import '../domain/models/sparkle_event.dart';
import '../utils/date_key.dart';
import 'energy_provider.dart';
import 'settings_provider.dart';

/// 相棒（給餌によるなつき度・進化段階）の状態管理
class CompanionProvider extends ChangeNotifier {
  final LocalStorage _storage;
  final EnergyProvider _energyProvider;
  final SettingsProvider _settingsProvider;
  final DateTime Function() _now;

  CompanionState _companion;
  DateTime? _lastFedAt;
  final List<Achievement> _pendingCelebrations = [];
  final List<CompanionStage> _pendingStageCelebrations = [];
  FeedEvent? _pendingFeedEvent;
  final Set<String> _celebratedStageIds;
  String? _firstSparkleDate;

  CompanionProvider(
    this._storage,
    this._energyProvider,
    this._settingsProvider, {
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        _companion = _storage.loadCompanionState(),
        _lastFedAt = _storage.loadCompanionLastFedAt(),
        _celebratedStageIds =
            (_storage.loadCelebratedStageIds() ?? <String>[]).toSet() {
    final sparkleEvents = _storage.loadSparkleEvents();
    _firstSparkleDate =
        sparkleEvents.isEmpty ? null : sparkleEvents.first.date;
    _migrateCelebratedStagesIfNeeded();
  }

  CompanionState get companion => _companion;

  DateTime? get lastFedAt => _lastFedAt;

  CompanionMood get mood =>
      CompanionLogic.moodFor(now: _now(), lastFedAt: _lastFedAt);

  /// 蓄電池容量（給餌効果込み）
  double get effectiveCapacityWh => CompanionLogic.effectiveCapacity(
        GameConstants.initialBatteryCapacityWh,
        _companion,
      );

  /// エネルギー係数（ユーザー設定ベース × 給餌効果）
  double get effectiveCoefficient => CompanionLogic.effectiveCoefficient(
        _settingsProvider.settings.energyCoefficient,
        _companion,
      );

  /// 初きらめきタイム発生日（未発生なら null）。
  /// 画面の build から参照されるため、ストレージではなくメモリ上の値を返す。
  String? get firstSparkleDate => _firstSparkleDate;

  /// なつき度レベル・累積発電量・きらめきタイム回数を合成した愛着スコア
  int get bondScore => CompanionLogic.bondScore(
        level: _companion.level,
        lifetimeEnergyWh: _energyProvider.lifetimeEnergyWh,
        sparkleMoments: CompanionStages.sparkleCount(_companion.level),
      );

  /// まだ画面で祝福表示されていない、新たに解除された実績一覧。
  List<Achievement> get pendingCelebrations =>
      List.unmodifiable(_pendingCelebrations);

  List<CompanionStage> get pendingStageCelebrations =>
      List.unmodifiable(_pendingStageCelebrations);

  FeedEvent? get pendingFeedEvent => _pendingFeedEvent;

  bool isStageCelebrated(String stageId) => _celebratedStageIds.contains(stageId);

  /// 祝福表示済みとしてキューをクリアする。
  void clearPendingCelebrations() {
    _pendingCelebrations.clear();
  }

  void clearPendingStageCelebrations() {
    _pendingStageCelebrations.clear();
  }

  void clearFeedEvent() {
    _pendingFeedEvent = null;
  }

  /// ユーザーが選んだ種類のごはんを相棒に与える（常に成功する）。
  Future<void> feedChosen(FeedItemType type) async {
    final sparklesAfter = await _feed(type);
    await _storage.saveCompanionState(_companion);
    await _checkAchievements(sparkleMoments: sparklesAfter);
    notifyListeners();
  }

  /// 指定した種類のごはんを与える（永続化・通知は呼び出し元の責務）。
  /// 給餌後のきらめきタイム累計回数を返す。
  Future<int> _feed(FeedItemType type) async {
    final beforeLevel = _companion.level;
    final sparklesBefore = CompanionStages.sparkleCount(_companion.level);
    _companion = _companion.addFeed(type);
    final afterLevel = _companion.level;
    final sparklesAfter = CompanionStages.sparkleCount(_companion.level);

    final newCapacity = CompanionLogic.effectiveCapacity(
      GameConstants.initialBatteryCapacityWh,
      _companion,
    );
    await _energyProvider.applyBatteryState(
      _energyProvider.battery.copyWith(capacityWh: newCapacity),
    );

    _lastFedAt = _now();
    await _storage.saveCompanionLastFedAt(_lastFedAt!);

    if (sparklesAfter > sparklesBefore) {
      await _recordSparkleMoments(sparklesAfter - sparklesBefore);
    }
    _pendingFeedEvent = FeedEvent(type: type, createdAt: _now());
    await _recordStageCelebrations(beforeLevel: beforeLevel, afterLevel: afterLevel);
    return sparklesAfter;
  }

  /// きらめきタイムの発生を履歴に記録する。
  Future<void> _recordSparkleMoments(int count) async {
    final events = _storage.loadSparkleEvents();
    final todayKey = formatDateKey(_now());
    final newEvents = [
      ...events,
      for (var i = 0; i < count; i++)
        SparkleEvent(number: events.length + i + 1, date: todayKey),
    ];
    await _storage.saveSparkleEvents(newEvents);
    _firstSparkleDate ??= newEvents.first.date;
  }

  /// 新たに条件を満たした実績を解除し、履歴に記録する。
  Future<void> _checkAchievements({required int sparkleMoments}) async {
    final events = _storage.loadAchievementEvents();
    final unlockedIds = events.map((e) => e.id).toSet();
    final newlyUnlocked = Achievements.all
        .where((a) =>
            !unlockedIds.contains(a.id) && a.isUnlocked(_companion, sparkleMoments))
        .toList();
    if (newlyUnlocked.isEmpty) return;

    final todayKey = formatDateKey(_now());
    final newEvents = [
      ...events,
      for (final a in newlyUnlocked) AchievementEvent(id: a.id, date: todayKey),
    ];
    await _storage.saveAchievementEvents(newEvents);
    _pendingCelebrations.addAll(newlyUnlocked);
  }

  Future<void> _recordStageCelebrations({
    required int beforeLevel,
    required int afterLevel,
  }) async {
    final newlyReached = CompanionStages.reachedStages(afterLevel).where((stage) {
      if (stage.id == 'egg') return false;
      return stage.minLevel > beforeLevel && !_celebratedStageIds.contains(stage.id);
    }).toList();
    if (newlyReached.isEmpty) return;

    final existingEvents = _storage.loadCompanionStageEvents();
    final todayKey = formatDateKey(_now());
    final newEvents = [
      ...existingEvents,
      for (final stage in newlyReached)
        CompanionStageEvent(stageId: stage.id, date: todayKey),
    ];
    await _storage.saveCompanionStageEvents(newEvents);
    _pendingStageCelebrations.addAll(newlyReached);

    _celebratedStageIds.addAll(newlyReached.map((e) => e.id));
    await _storage.saveCelebratedStageIds(_celebratedStageIds.toList());
  }

  void _migrateCelebratedStagesIfNeeded() {
    final initial = _storage.loadCelebratedStageIds();
    if (initial != null) return;

    final reachedIds = CompanionStages.reachedStages(_companion.level)
        .where((stage) => stage.id != 'egg')
        .map((stage) => stage.id)
        .toSet();
    _celebratedStageIds.addAll(reachedIds);
    unawaited(_storage.saveCelebratedStageIds(_celebratedStageIds.toList()));
  }
}
