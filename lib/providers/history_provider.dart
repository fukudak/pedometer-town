import 'package:flutter/foundation.dart';

import '../data/local_storage.dart';
import '../domain/models/daily_step_record.dart';
import 'companion_provider.dart';
import 'energy_provider.dart';

/// 日次記録（歩数・エネルギー履歴）の管理
class HistoryProvider extends ChangeNotifier {
  final LocalStorage _storage;
  final EnergyProvider _energyProvider;
  final CompanionProvider _companionProvider;

  HistoryProvider(this._storage, this._energyProvider, this._companionProvider);

  /// 保存済みの全日次記録を日付の新しい順に返す（無期限保持）。
  List<DailyStepRecord> loadHistory() => _storage.loadAllDailyRecords();

  /// 指定日の日次記録を削除する。削除対象が今日の記録なら表示も空にする。
  /// 同期差分の起点（[LocalStorage.loadTodaySyncedCursor]）は削除されないため、
  /// 再同期しても今日すでに同期済みの歩数が二重加算されることはない。
  Future<void> deleteHistoryRecord(String date) async {
    await _storage.deleteDailyRecord(date);
    if (_energyProvider.today.date == date) {
      _energyProvider.refreshDisplay();
    }
    notifyListeners();
  }

  /// 全ての日次記録を削除し、星の発展状況（発展度・蓄電池・累積発電量・
  /// 満タンストック）も初期状態に戻す。同期差分の起点には触れないため、
  /// 再同期しても今日すでに同期済みの歩数が再加算されることはない。
  Future<void> clearHistory() async {
    await _storage.clearAllDailyRecords();
    await _companionProvider.resetProgress();
    await _energyProvider.resetProgress();
    notifyListeners();
  }
}
