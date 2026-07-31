/// 日付を `YYYY-MM-DD` 形式のキー文字列に変換する。
/// 永続化キー（日次記録・各種イベント）や日付比較に共通して使う。
String formatDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
