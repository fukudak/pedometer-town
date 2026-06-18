import 'package:flutter/foundation.dart';

import '../constants/game_constants.dart';
import '../data/local_storage.dart';
import '../domain/models/player_settings.dart';

/// 体重・デフォルト速度などプレイヤー設定の状態管理
class SettingsProvider extends ChangeNotifier {
  final LocalStorage _storage;
  PlayerSettings _settings;

  SettingsProvider(this._storage) : _settings = _storage.loadPlayerSettings();

  PlayerSettings get settings => _settings;

  /// 体重を更新する。範囲外の場合は [ArgumentError] を throw する。
  Future<void> updateWeight(double weightKg) async {
    if (!PlayerSettings.isValidWeight(weightKg)) {
      throw ArgumentError(
        '体重は${GameConstants.minWeightKg}〜${GameConstants.maxWeightKg}kgの範囲で指定してください',
      );
    }
    _settings = _settings.copyWith(weightKg: weightKg);
    await _storage.savePlayerSettings(_settings);
    notifyListeners();
  }

  /// 歩行速度を更新する。範囲外の場合は [ArgumentError] を throw する。
  Future<void> updateSpeed(double speedKmh) async {
    if (!PlayerSettings.isValidSpeed(speedKmh)) {
      throw ArgumentError(
        '速度は${GameConstants.minSpeedKmh}〜${GameConstants.maxSpeedKmh}km/hの範囲で指定してください',
      );
    }
    _settings = _settings.copyWith(defaultSpeedKmh: speedKmh);
    await _storage.savePlayerSettings(_settings);
    notifyListeners();
  }

  /// 発電変換係数を更新する。範囲外の場合は [ArgumentError] を throw する。
  Future<void> updateCoefficient(double coefficient) async {
    if (!PlayerSettings.isValidCoefficient(coefficient)) {
      throw ArgumentError(
        '係数は${GameConstants.minEnergyCoefficient}〜${GameConstants.maxEnergyCoefficient}の範囲で指定してください',
      );
    }
    _settings = _settings.copyWith(energyCoefficient: coefficient);
    await _storage.savePlayerSettings(_settings);
    notifyListeners();
  }
}
