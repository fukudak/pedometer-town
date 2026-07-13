import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants/achievements.dart';
import '../constants/game_constants.dart';
import '../constants/town_stages.dart';
import '../data/local_storage.dart';
import '../domain/models/achievement_event.dart';
import '../domain/models/building.dart';
import '../domain/models/construction_event.dart';
import '../domain/models/rocket_launch_event.dart';
import '../domain/models/town_stage_event.dart';
import '../domain/models/town_state.dart';
import '../domain/town_logic.dart';
import 'energy_provider.dart';
import 'settings_provider.dart';

/// 町（建物）の状態管理
class TownProvider extends ChangeNotifier {
  final LocalStorage _storage;
  final EnergyProvider _energyProvider;
  final SettingsProvider _settingsProvider;
  final DateTime Function() _now;

  TownState _town;
  final List<Achievement> _pendingCelebrations = [];
  final List<TownStage> _pendingStageCelebrations = [];
  ConstructionEvent? _pendingConstructionEvent;
  final Set<String> _celebratedStageIds;

  TownProvider(
    this._storage,
    this._energyProvider,
    this._settingsProvider, {
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        _town = _storage.loadTownState(),
        _celebratedStageIds =
            (_storage.loadCelebratedStageIds() ?? <String>[]).toSet() {
    _migrateCelebratedStagesIfNeeded();
  }

  TownState get town => _town;

  /// 蓄電池容量（建物効果込み）
  double get effectiveCapacityWh => TownLogic.effectiveCapacity(
        GameConstants.initialBatteryCapacityWh,
        _town.buildings,
      );

  /// エネルギー係数（ユーザー設定ベース × 建物効果）
  double get effectiveCoefficient => TownLogic.effectiveCoefficient(
        _settingsProvider.settings.energyCoefficient,
        _town.buildings,
      );

  /// 建物から算出される人口
  int get population => TownLogic.totalPopulation(_town.buildings);

  /// 棟数・累積発電量・ロケット発射数を合成した文明スコア
  int get civilizationScore => TownLogic.civilizationScore(
        buildings: _town.buildings,
        lifetimeEnergyWh: _energyProvider.lifetimeEnergyWh,
        rocketLaunches: TownStages.rocketLaunchCount(_town.townLevel),
      );

  /// まだ画面で祝福表示されていない、新たに解除された実績一覧。
  List<Achievement> get pendingCelebrations =>
      List.unmodifiable(_pendingCelebrations);

  List<TownStage> get pendingStageCelebrations =>
      List.unmodifiable(_pendingStageCelebrations);

  ConstructionEvent? get pendingConstructionEvent => _pendingConstructionEvent;

  bool isStageCelebrated(String stageId) => _celebratedStageIds.contains(stageId);

  /// 祝福表示済みとしてキューをクリアする。
  void clearPendingCelebrations() {
    _pendingCelebrations.clear();
  }

  void clearPendingStageCelebrations() {
    _pendingStageCelebrations.clear();
  }

  void clearConstructionEvent() {
    _pendingConstructionEvent = null;
  }

  /// 空いている座標を1つ返す（地平線ビューでは座標は表示しないが、
  /// データモデル上は座標を保持するため自動で割り当てる）。
  /// すべて埋まっている場合は null を返す。
  ({int x, int y})? _nextAvailablePosition() {
    for (var y = 0; y < GameConstants.townGridSize; y++) {
      for (var x = 0; x < GameConstants.townGridSize; x++) {
        if (!TownLogic.isOccupied(_town.buildings, x, y)) {
          return (x: x, y: y);
        }
      }
    }
    return null;
  }

  /// 蓄電池が満タンになった回数分、街を自動で発展させる
  /// （建物の種類は自動で順に割り当てられ、ユーザーが選ぶ必要はない）。
  Future<void> advanceTown(int count) async {
    for (var i = 0; i < count; i++) {
      final type = BuildingType
          .values[_town.buildings.length % BuildingType.values.length];
      final placed = await _placeBuilding(type);
      if (!placed) break;
    }
    await _storage.saveTownState(_town);
    await _checkAchievements();
    notifyListeners();
  }

  /// ユーザーが選んだ種類の建物を1棟、空いている座標に建設する。
  /// グリッドが満杯の場合は false を返す。
  Future<bool> buildChosen(BuildingType type) async {
    final placed = await _placeBuilding(type);
    if (placed) {
      await _storage.saveTownState(_town);
      await _checkAchievements();
      notifyListeners();
    }
    return placed;
  }

  /// 指定した種類の建物を1棟、空いている座標に建設する（永続化・通知は呼び出し元の責務）。
  /// グリッドが満杯の場合は false を返す。
  Future<bool> _placeBuilding(BuildingType type) async {
    final pos = _nextAvailablePosition();
    if (pos == null) return false;

    final beforeLevel = _town.townLevel;
    final launchesBefore = TownStages.rocketLaunchCount(_town.townLevel);
    _town = _town.addBuilding(Building(type: type, x: pos.x, y: pos.y));
    final afterLevel = _town.townLevel;
    final launchesAfter = TownStages.rocketLaunchCount(_town.townLevel);

    final newCapacity = TownLogic.effectiveCapacity(
      GameConstants.initialBatteryCapacityWh,
      _town.buildings,
    );
    await _energyProvider.applyBatteryState(
      _energyProvider.battery.copyWith(capacityWh: newCapacity),
    );

    if (launchesAfter > launchesBefore) {
      await _recordRocketLaunches(launchesAfter - launchesBefore);
    }
    _pendingConstructionEvent = ConstructionEvent(
      type: type,
      x: pos.x,
      y: pos.y,
      createdAt: _now(),
    );
    await _recordStageCelebrations(beforeLevel: beforeLevel, afterLevel: afterLevel);
    return true;
  }

  /// ロケットの発射を履歴に記録する。
  Future<void> _recordRocketLaunches(int count) async {
    final events = _storage.loadRocketLaunchEvents();
    final todayKey = _dateKey(_now());
    final newEvents = [
      ...events,
      for (var i = 0; i < count; i++)
        RocketLaunchEvent(number: events.length + i + 1, date: todayKey),
    ];
    await _storage.saveRocketLaunchEvents(newEvents);
  }

  /// 新たに条件を満たした実績を解除し、履歴に記録する。
  Future<void> _checkAchievements() async {
    final launches = TownStages.rocketLaunchCount(_town.townLevel);
    final events = _storage.loadAchievementEvents();
    final unlockedIds = events.map((e) => e.id).toSet();
    final newlyUnlocked = Achievements.all
        .where((a) =>
            !unlockedIds.contains(a.id) && a.isUnlocked(_town, launches))
        .toList();
    if (newlyUnlocked.isEmpty) return;

    final todayKey = _dateKey(_now());
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
    final newlyReached = TownStages.reachedStages(afterLevel).where((stage) {
      if (stage.id == 'empty') return false;
      return stage.minLevel > beforeLevel && !_celebratedStageIds.contains(stage.id);
    }).toList();
    if (newlyReached.isEmpty) return;

    final existingEvents = _storage.loadTownStageEvents();
    final todayKey = _dateKey(_now());
    final newEvents = [
      ...existingEvents,
      for (final stage in newlyReached)
        TownStageEvent(stageId: stage.id, date: todayKey),
    ];
    await _storage.saveTownStageEvents(newEvents);
    _pendingStageCelebrations.addAll(newlyReached);

    _celebratedStageIds.addAll(newlyReached.map((e) => e.id));
    await _storage.saveCelebratedStageIds(_celebratedStageIds.toList());
  }

  void _migrateCelebratedStagesIfNeeded() {
    final initial = _storage.loadCelebratedStageIds();
    if (initial != null) return;

    final reachedIds = TownStages.reachedStages(_town.townLevel)
        .where((stage) => stage.id != 'empty')
        .map((stage) => stage.id)
        .toSet();
    _celebratedStageIds.addAll(reachedIds);
    unawaited(_storage.saveCelebratedStageIds(_celebratedStageIds.toList()));
  }

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
