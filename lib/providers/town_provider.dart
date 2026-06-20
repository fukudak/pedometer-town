import 'package:flutter/foundation.dart';

import '../constants/game_constants.dart';
import '../data/local_storage.dart';
import '../domain/models/building.dart';
import '../domain/models/town_state.dart';
import '../domain/town_logic.dart';
import 'energy_provider.dart';
import 'settings_provider.dart';

/// 町（建物）の状態管理
class TownProvider extends ChangeNotifier {
  final LocalStorage _storage;
  final EnergyProvider _energyProvider;
  final SettingsProvider _settingsProvider;

  TownState _town;

  TownProvider(this._storage, this._energyProvider, this._settingsProvider)
      : _town = _storage.loadTownState();

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

    _town = _town.addBuilding(Building(type: type, x: x, y: y));
    final newCapacity = TownLogic.effectiveCapacity(
      GameConstants.initialBatteryCapacityWh,
      _town.buildings,
    );

    await _energyProvider.applyBatteryState(
      result.state.copyWith(capacityWh: newCapacity),
    );
    await _storage.saveTownState(_town);
    notifyListeners();
    return true;
  }
}
