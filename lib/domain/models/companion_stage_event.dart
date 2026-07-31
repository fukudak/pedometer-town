/// 相棒の進化段階に到達した履歴イベント。
class CompanionStageEvent {
  final String stageId;
  final String date;

  const CompanionStageEvent({required this.stageId, required this.date});

  Map<String, dynamic> toJson() => {'stageId': stageId, 'date': date};

  factory CompanionStageEvent.fromJson(Map<String, dynamic> json) =>
      CompanionStageEvent(
        stageId: json['stageId'] as String,
        date: json['date'] as String,
      );
}
