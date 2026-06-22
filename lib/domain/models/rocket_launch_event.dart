/// ロケットを発射した記録（履歴表示用）
class RocketLaunchEvent {
  final int number;
  final String date;

  const RocketLaunchEvent({required this.number, required this.date});

  Map<String, dynamic> toJson() => {'number': number, 'date': date};

  factory RocketLaunchEvent.fromJson(Map<String, dynamic> json) =>
      RocketLaunchEvent(
        number: json['number'] as int,
        date: json['date'] as String,
      );
}
