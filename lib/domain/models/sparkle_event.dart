/// きらめきタイムが発生した記録（履歴表示用）
class SparkleEvent {
  final int number;
  final String date;

  const SparkleEvent({required this.number, required this.date});

  Map<String, dynamic> toJson() => {'number': number, 'date': date};

  factory SparkleEvent.fromJson(Map<String, dynamic> json) => SparkleEvent(
        number: json['number'] as int,
        date: json['date'] as String,
      );
}
