import '../../constants/game_constants.dart';

/// 蓄電池の状態
class BatteryState {
  final double storedWh;
  final double capacityWh;

  const BatteryState({required this.storedWh, required this.capacityWh});

  factory BatteryState.initial() => const BatteryState(
        storedWh: GameConstants.initialBatteryStoredWh,
        capacityWh: GameConstants.initialBatteryCapacityWh,
      );

  /// エネルギーを加算する。容量に達するたびに満タンとして折り返し、
  /// 新たに何個満タンになったか（[BatteryAddResult.batteriesFilled]）を返す。
  BatteryAddResult addEnergy(double amount) {
    final total = storedWh + amount;
    if (capacityWh <= 0 || total < capacityWh) {
      return BatteryAddResult(state: copyWith(storedWh: total), batteriesFilled: 0);
    }
    final filled = (total / capacityWh).floor();
    final remainder = total - filled * capacityWh;
    return BatteryAddResult(
      state: copyWith(storedWh: remainder),
      batteriesFilled: filled,
    );
  }

  /// エネルギーを消費する。不足時は失敗（成功フラグfalse・状態は変化なし）。
  BatteryConsumeResult consumeEnergy(double amount) {
    if (amount > storedWh) {
      return BatteryConsumeResult(success: false, state: this);
    }
    return BatteryConsumeResult(
      success: true,
      state: copyWith(storedWh: storedWh - amount),
    );
  }

  BatteryState copyWith({double? storedWh, double? capacityWh}) {
    return BatteryState(
      storedWh: storedWh ?? this.storedWh,
      capacityWh: capacityWh ?? this.capacityWh,
    );
  }
}

/// [BatteryState.consumeEnergy] の結果
class BatteryConsumeResult {
  final bool success;
  final BatteryState state;

  const BatteryConsumeResult({required this.success, required this.state});
}

/// [BatteryState.addEnergy] の結果
class BatteryAddResult {
  final BatteryState state;
  final int batteriesFilled;

  const BatteryAddResult({required this.state, required this.batteriesFilled});
}
