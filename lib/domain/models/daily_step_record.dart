/// 日付ごとの歩数・エネルギー記録（'YYYY-MM-DD' キー）
class DailyStepRecord {
  final String date;
  final int totalSteps;
  final double totalEnergyWh;
  final int lastSyncedSteps;

  const DailyStepRecord({
    required this.date,
    required this.totalSteps,
    required this.totalEnergyWh,
    required this.lastSyncedSteps,
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
  }) {
    return DailyStepRecord(
      date: date,
      totalSteps: totalSteps ?? this.totalSteps,
      totalEnergyWh: totalEnergyWh ?? this.totalEnergyWh,
      lastSyncedSteps: lastSyncedSteps ?? this.lastSyncedSteps,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'totalSteps': totalSteps,
        'totalEnergyWh': totalEnergyWh,
        'lastSyncedSteps': lastSyncedSteps,
      };

  factory DailyStepRecord.fromJson(Map<String, dynamic> json) =>
      DailyStepRecord(
        date: json['date'] as String,
        totalSteps: json['totalSteps'] as int,
        totalEnergyWh: (json['totalEnergyWh'] as num).toDouble(),
        lastSyncedSteps: json['lastSyncedSteps'] as int,
      );
}
