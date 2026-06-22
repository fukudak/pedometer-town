import 'package:flutter/foundation.dart';

import '../constants/game_constants.dart';
import '../constants/town_stages.dart';
import '../data/local_storage.dart';
import '../domain/models/building.dart';
import '../domain/models/rocket_launch_event.dart';
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

  TownProvider(
    this._storage,
    this._energyProvider,
    this._settingsProvider, {
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        _town = _storage.loadTownState();

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

  /// エネルギー残量だけで建設可否を判定する（座標の空き状況は見ない）。
  bool canAfford(BuildingType type) {
    return _energyProvider.battery.storedWh >= TownLogic.costOf(type);
  }

  /// 指定座標に指定した建物を建設できるかどうか
  bool canBuild(BuildingType type, int x, int y) {
    return TownLogic.canBuild(
      _energyProvider.battery,
      type,
      _town.buildings,
      x,
      y,
    );
  }

  /// 空いている座標を1つ返す（地平線ビューでは座標は表示しないが、
  /// データモデル上は座標を保持するため自動で割り当てる）。
  /// すべて埋まっている場合は null を返す。
  ({int x, int y})? nextAvailablePosition() {
    for (var y = 0; y < GameConstants.townGridSize; y++) {
      for (var x = 0; x < GameConstants.townGridSize; x++) {
        if (!TownLogic.isOccupied(_town.buildings, x, y)) {
          return (x: x, y: y);
        }
      }
    }
    return null;
  }

  /// 指定座標に建物を建設する。座標がグリッド範囲外・空いていない、またはエネルギー不足の場合は false を返す。
  Future<bool> buildBuilding(BuildingType type, int x, int y) async {
    if (!TownLogic.isWithinGrid(x, y)) {
      return false;
    }
    if (TownLogic.isOccupied(_town.buildings, x, y)) {
      return false;
    }

    final cost = TownLogic.costOf(type);
    final result = _energyProvider.battery.consumeEnergy(cost);
    if (!result.success) {
      return false;
    }

    final launchesBefore = TownStages.rocketLaunchCount(_town.townLevel);
    _town = _town.addBuilding(Building(type: type, x: x, y: y));
    final launchesAfter = TownStages.rocketLaunchCount(_town.townLevel);
    final newCapacity = TownLogic.effectiveCapacity(
      GameConstants.initialBatteryCapacityWh,
      _town.buildings,
    );

    await _energyProvider.applyBatteryState(
      result.state.copyWith(capacityWh: newCapacity),
    );
    await _storage.saveTownState(_town);
    if (launchesAfter > launchesBefore) {
      await _recordRocketLaunches(launchesAfter - launchesBefore);
    }
    notifyListeners();
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

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
