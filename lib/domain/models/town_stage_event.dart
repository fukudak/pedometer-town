/// 町の発展段階に到達した履歴イベント。
class TownStageEvent {
  final String stageId;
  final String date;

  const TownStageEvent({required this.stageId, required this.date});

  Map<String, dynamic> toJson() => {'stageId': stageId, 'date': date};

  factory TownStageEvent.fromJson(Map<String, dynamic> json) => TownStageEvent(
        stageId: json['stageId'] as String,
        date: json['date'] as String,
      );
}
