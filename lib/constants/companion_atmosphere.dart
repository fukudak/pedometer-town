enum CompanionWeather { clear, cloudy, rainy }

enum CompanionSeason { spring, summer, autumn, winter }

class CompanionAtmosphere {
  CompanionAtmosphere._();

  /// 日付シード（YYYYMMDD）から天気を決定する。同日は常に同じ結果。
  static CompanionWeather weatherOf(DateTime date) {
    final seed = date.year * 10000 + date.month * 100 + date.day;
    final bucket = seed % 100;
    if (bucket < 50) return CompanionWeather.clear;
    if (bucket < 80) return CompanionWeather.cloudy;
    return CompanionWeather.rainy;
  }

  /// 月から季節を決定する。
  static CompanionSeason seasonOf(DateTime date) {
    final month = date.month;
    if (month >= 3 && month <= 5) return CompanionSeason.spring;
    if (month >= 6 && month <= 8) return CompanionSeason.summer;
    if (month >= 9 && month <= 11) return CompanionSeason.autumn;
    return CompanionSeason.winter;
  }

}
