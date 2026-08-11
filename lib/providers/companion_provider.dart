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
  bool _investing = false;

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

  /// なつき度レベル・累積発電量を合成した愛着スコア
  int get bondScore => CompanionLogic.bondScore(
        level: _companion.level,
        lifetimeEnergyWh: _energyProvider.lifetimeEnergyWh,
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
    await _feed(type);
    await _storage.saveCompanionState(_companion);
    await _checkAchievements();
    notifyListeners();
  }

  /// 満タンストックを1個消費して発展度を1増やす、呼び出し側から見て単一の操作。
  /// ストック不足なら何もせず false を返す。すでに処理中の呼び出しがあれば
  /// （連打対策）即座に false を返す。
  ///
  /// 消費後の発展更新（[feedChosen]）に失敗した場合は、消費したストックを戻し、
  /// メモリ上の発展度もこの呼び出し前の状態に戻してから例外を再送出する
  /// （「電池だけ消費」「発展だけ増加」という不整合を残さないため）。
  /// ただし [feedChosen] 内部の副次的な永続化（実績・進化祝福の記録、
  /// 蓄電池容量の反映等）はこの呼び出し単位のロールバック対象ではない。
  Future<bool> investBattery() async {
    if (_investing) return false;
    _investing = true;
    try {
      final consumed = await _energyProvider.consumeStockedBatteries(1);
      if (!consumed) return false;

      final companionBeforeFeed = _companion;
      try {
        await feedChosen(FeedItemType.meal);
        return true;
      } catch (_) {
        _companion = companionBeforeFeed;
        await _energyProvider.creditStockedBatteries(1);
        rethrow;
      }
    } finally {
      _investing = false;
    }
  }

  /// 指定した種類のごはんを与える（永続化・通知は呼び出し元の責務）。
  Future<void> _feed(FeedItemType type) async {
    final beforeLevel = _companion.level;
    _companion = _companion.addFeed(type);
    final afterLevel = _companion.level;

    final newCapacity = CompanionLogic.effectiveCapacity(
      GameConstants.initialBatteryCapacityWh,
      _companion,
    );
    await _energyProvider.applyBatteryState(
      _energyProvider.battery.copyWith(capacityWh: newCapacity),
    );

    _lastFedAt = _now();
    await _storage.saveCompanionLastFedAt(_lastFedAt!);

    _pendingFeedEvent = FeedEvent(type: type, createdAt: _now());
    await _recordStageCelebrations(beforeLevel: beforeLevel, afterLevel: afterLevel);
  }

  /// 新たに条件を満たした実績を解除し、履歴に記録する。
  Future<void> _checkAchievements() async {
    final events = _storage.loadAchievementEvents();
    final unlockedIds = events.map((e) => e.id).toSet();
    final newlyUnlocked = Achievements.all
        .where((a) => !unlockedIds.contains(a.id) && a.isUnlocked(_companion))
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

  /// 発展度（投入回数）を初期状態に戻す（全履歴クリアと連動）。
  /// 蓄電池・累積発電量のリセットは [EnergyProvider.resetProgress] が担う。
  Future<void> resetProgress() async {
    _companion = CompanionState.initial();
    await _storage.saveCompanionState(_companion);
    notifyListeners();
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
