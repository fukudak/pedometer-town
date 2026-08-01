import 'package:flutter/material.dart';

import 'companion_stages.dart';

enum CompanionTimeOfDay { morning, day, evening, night }

enum CompanionWeather { clear, cloudy, rainy }

enum CompanionSeason { spring, summer, autumn, winter }

class CompanionAtmospherePalette {
  final Color skyColor;
  final Color tileColor;

  const CompanionAtmospherePalette({
    required this.skyColor,
    required this.tileColor,
  });
}

class CompanionAtmosphere {
  CompanionAtmosphere._();

  static CompanionTimeOfDay timeOfDay(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 11) return CompanionTimeOfDay.morning;
    if (hour >= 11 && hour < 17) return CompanionTimeOfDay.day;
    if (hour >= 17 && hour < 20) return CompanionTimeOfDay.evening;
    return CompanionTimeOfDay.night;
  }

  static CompanionAtmospherePalette paletteOf(CompanionTimeOfDay timeOfDay) {
    switch (timeOfDay) {
      case CompanionTimeOfDay.morning:
        return const CompanionAtmospherePalette(
          skyColor: Color(0xFF87CEEB),
          tileColor: Color(0xFF9CCC65),
        );
      case CompanionTimeOfDay.day:
        return const CompanionAtmospherePalette(
          skyColor: Color(0xFF7CB342),
          tileColor: Color(0xFF8FCE52),
        );
      case CompanionTimeOfDay.evening:
        return const CompanionAtmospherePalette(
          skyColor: Color(0xFF7E57C2),
          tileColor: Color(0xFFAED581),
        );
      case CompanionTimeOfDay.night:
        return const CompanionAtmospherePalette(
          skyColor: Color(0xFF1A237E),
          tileColor: Color(0xFF33691E),
        );
    }
  }

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

  /// 天気・季節に応じてパレットを微調整する。
  static CompanionAtmospherePalette applyWeatherAndSeason(
    CompanionAtmospherePalette base, {
    required CompanionWeather weather,
    required CompanionSeason season,
  }) {
    var sky = base.skyColor;
    var tile = base.tileColor;

    switch (weather) {
      case CompanionWeather.clear:
        break;
      case CompanionWeather.cloudy:
        sky = Color.lerp(sky, const Color(0xFF90A4AE), 0.28)!;
        tile = Color.lerp(tile, const Color(0xFF7CB342), 0.08)!;
      case CompanionWeather.rainy:
        sky = Color.lerp(sky, const Color(0xFF546E7A), 0.45)!;
        tile = Color.lerp(tile, const Color(0xFF558B2F), 0.12)!;
    }

    if (season == CompanionSeason.summer) {
      tile = Color.lerp(tile, const Color(0xFF33691E), 0.18)!;
    }

    return CompanionAtmospherePalette(skyColor: sky, tileColor: tile);
  }

  static ({String title, String description}) stageStory(String stageId) {
    switch (stageId) {
      case 'crack':
        return (title: '家が建った', description: 'まっさらな土地に、小さな家がひとつ建った。');
      case 'hatch':
        return (title: '電灯の村へ', description: '家が並び、歩いて集めたエネルギーで窓に灯りがついた。');
      case 'kid':
        return (title: 'にぎわう街へ', description: '商店や家が増え、街らしくなってきた。');
      case 'charged':
        return (title: 'ビルの街へ', description: '高層ビルが立ち、夜のスカイラインが形づくられた。');
      case 'reliable':
        return (title: '工業地帯へ', description: '工場と煙突が現れ、町が産業の力で動きだした。');
      case 'radiant':
        return (title: '宇宙基地へ', description: '研究棟と発射台が整備され、空を目指す準備が整った。');
      case 'star':
        return (title: 'ロケット打ち上げ', description: '歩いて集めたエネルギーが、ロケットを空へ押し上げた。');
      default:
        return (title: 'まちが発展', description: '町が新しい姿へ発展した。');
    }
  }

  static IconData stageIcon(CompanionStage stage) => stage.icon ?? Icons.egg_outlined;
}
