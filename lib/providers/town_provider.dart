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

  /// 指定した建物を建設できるかどうか
  bool canBuild(BuildingType type) {
    return TownLogic.canBuild(_energyProvider.battery, type);
  }

  /// 建物を建設する。エネルギー不足の場合は false を返す。
  Future<bool> buildBuilding(BuildingType type) async {
    final cost = TownLogic.costOf(type);
    final result = _energyProvider.battery.consumeEnergy(cost);
    if (!result.success) {
      return false;
    }

    _town = _town.addBuilding(Building(type: type));
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
