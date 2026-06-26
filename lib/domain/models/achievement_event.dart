/// 実績を解除した記録（履歴表示用）
class AchievementEvent {
  final String id;
  final String date;

  const AchievementEvent({required this.id, required this.date});

  Map<String, dynamic> toJson() => {'id': id, 'date': date};

  factory AchievementEvent.fromJson(Map<String, dynamic> json) =>
      AchievementEvent(
        id: json['id'] as String,
        date: json['date'] as String,
      );
}
