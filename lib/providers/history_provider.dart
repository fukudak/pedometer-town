import 'package:flutter/foundation.dart';

import '../constants/achievements.dart';
import '../constants/companion_atmosphere.dart';
import '../constants/companion_stages.dart';
import '../data/local_storage.dart';
import '../domain/models/companion_stage_event.dart';
import '../domain/models/daily_step_record.dart';
import '../domain/models/full_battery_event.dart';
import '../domain/models/sparkle_event.dart';
import 'energy_provider.dart';

/// 解除済みの実績（履歴表示用に定義とイベントを結合したもの）
class UnlockedAchievement {
  final Achievement achievement;
  final String date;

  const UnlockedAchievement({required this.achievement, required this.date});
}

/// 相棒の進化段階到達履歴（表示用に段階定義と結合したもの）
class CompanionStageHistoryEntry {
  final CompanionStage stage;
  final String title;
  final String description;
  final String date;

  const CompanionStageHistoryEntry({
    required this.stage,
    required this.title,
    required this.description,
    required this.date,
  });
}

/// 日次記録（歩数・エネルギー履歴）の管理
class HistoryProvider extends ChangeNotifier {
  final LocalStorage _storage;
  final EnergyProvider _energyProvider;

  HistoryProvider(this._storage, this._energyProvider);

  /// 保存済みの全日次記録を日付の新しい順に返す（無期限保持）。
  List<DailyStepRecord> loadHistory() => _storage.loadAllDailyRecords();

  /// 蓄電池が満タンになった記録を、新しい順に返す。
  List<FullBatteryEvent> loadFullBatteryEvents() =>
      _storage.loadFullBatteryEvents().reversed.toList();

  /// きらめきタイムが発生した記録を、新しい順に返す。
  List<SparkleEvent> loadSparkleEvents() =>
      _storage.loadSparkleEvents().reversed.toList();

  /// 解除済みの実績を、新しい順に返す。
  List<UnlockedAchievement> loadAchievementEvents() => _storage
      .loadAchievementEvents()
      .reversed
      .map((e) => UnlockedAchievement(
            achievement: Achievements.of(e.id),
            date: e.date,
          ))
      .toList();

  /// 相棒の進化段階到達履歴を、新しい順に返す。
  List<CompanionStageHistoryEntry> loadCompanionStageEvents() => _storage
      .loadCompanionStageEvents()
      .reversed
      .map((CompanionStageEvent e) {
        final stage = CompanionStages.stages.firstWhere(
          (s) => s.id == e.stageId,
          orElse: () => CompanionStages.stages.first,
        );
        final story = CompanionAtmosphere.stageStory(e.stageId);
        return CompanionStageHistoryEntry(
          stage: stage,
          title: story.title,
          description: story.description,
          date: e.date,
        );
      })
      .toList();

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
