/// 日付ごとの歩数・エネルギー記録（'YYYY-MM-DD' キー）
class DailyStepRecord {
  final String date;
  final int totalSteps;
  final double totalEnergyWh;
  final int lastSyncedSteps;

  /// 数日アプリを開かなかった分がこの日にまとめて計上されたときの、集計の開始日
  /// （`YYYY-MM-DD`）。まとめ計上でなければ null。
  final String? rangeStart;

  const DailyStepRecord({
    required this.date,
    required this.totalSteps,
    required this.totalEnergyWh,
    required this.lastSyncedSteps,
    this.rangeStart,
  });

  factory DailyStepRecord.empty(String date) => DailyStepRecord(
        date: date,
        totalSteps: 0,
        totalEnergyWh: 0.0,
        lastSyncedSteps: 0,
      );

  DailyStepRecord copyWith({
    int? totalSteps,
    double? totalEnergyWh,
    int? lastSyncedSteps,
    String? rangeStart,
  }) {
    return DailyStepRecord(
      date: date,
      totalSteps: totalSteps ?? this.totalSteps,
      totalEnergyWh: totalEnergyWh ?? this.totalEnergyWh,
      lastSyncedSteps: lastSyncedSteps ?? this.lastSyncedSteps,
      rangeStart: rangeStart ?? this.rangeStart,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'totalSteps': totalSteps,
        'totalEnergyWh': totalEnergyWh,
        'lastSyncedSteps': lastSyncedSteps,
        if (rangeStart != null) 'rangeStart': rangeStart,
      };

  factory DailyStepRecord.fromJson(Map<String, dynamic> json) =>
      DailyStepRecord(
        date: json['date'] as String,
        totalSteps: json['totalSteps'] as int,
        totalEnergyWh: (json['totalEnergyWh'] as num).toDouble(),
        lastSyncedSteps: json['lastSyncedSteps'] as int,
        rangeStart: json['rangeStart'] as String?,
      );
}
