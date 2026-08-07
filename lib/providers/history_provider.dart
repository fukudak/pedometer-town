import 'package:flutter/foundation.dart';

import '../data/local_storage.dart';
import '../domain/models/daily_step_record.dart';
import 'energy_provider.dart';

/// 日次記録（歩数・エネルギー履歴）の管理
class HistoryProvider extends ChangeNotifier {
  final LocalStorage _storage;
  final EnergyProvider _energyProvider;

  HistoryProvider(this._storage, this._energyProvider);

  /// 保存済みの全日次記録を日付の新しい順に返す（無期限保持）。
  List<DailyStepRecord> loadHistory() => _storage.loadAllDailyRecords();

  /// 指定日の日次記録を削除する。削除対象が今日の記録なら表示も空にする。
  Future<void> deleteHistoryRecord(String date) async {
    await _storage.deleteDailyRecord(date);
    if (_energyProvider.today.date == date) {
      _energyProvider.refreshDisplay();
    }
    notifyListeners();
  }

  /// 全ての日次記録を削除する。
  Future<void> clearHistory() async {
    await _storage.clearAllDailyRecords();
    _energyProvider.refreshDisplay();
    notifyListeners();
  }
}
