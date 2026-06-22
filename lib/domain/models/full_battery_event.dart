/// 蓄電池が満タンになった記録（履歴表示用）
class FullBatteryEvent {
  final int number;
  final String date;

  const FullBatteryEvent({required this.number, required this.date});

  Map<String, dynamic> toJson() => {'number': number, 'date': date};

  factory FullBatteryEvent.fromJson(Map<String, dynamic> json) =>
      FullBatteryEvent(
        number: json['number'] as int,
        date: json['date'] as String,
      );
}
