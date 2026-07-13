import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'town_stages.dart';

enum TownTimeOfDay { morning, day, evening, night }

enum TownWeather { clear, cloudy, rainy }

enum TownSeason { spring, summer, autumn, winter }

class TownAtmospherePalette {
  final Color skyColor;
  final Color tileColor;

  const TownAtmospherePalette({
    required this.skyColor,
    required this.tileColor,
  });
}

class TownAtmosphere {
  TownAtmosphere._();

  static TownTimeOfDay timeOfDay(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 11) return TownTimeOfDay.morning;
    if (hour >= 11 && hour < 17) return TownTimeOfDay.day;
    if (hour >= 17 && hour < 20) return TownTimeOfDay.evening;
    return TownTimeOfDay.night;
  }

  static TownAtmospherePalette paletteOf(TownTimeOfDay timeOfDay) {
    switch (timeOfDay) {
      case TownTimeOfDay.morning:
        return const TownAtmospherePalette(
          skyColor: Color(0xFF87CEEB),
          tileColor: Color(0xFF9CCC65),
        );
      case TownTimeOfDay.day:
        return const TownAtmospherePalette(
          skyColor: Color(0xFF7CB342),
          tileColor: Color(0xFF8FCE52),
        );
      case TownTimeOfDay.evening:
        return const TownAtmospherePalette(
          skyColor: Color(0xFF7E57C2),
          tileColor: Color(0xFFAED581),
        );
      case TownTimeOfDay.night:
        return const TownAtmospherePalette(
          skyColor: Color(0xFF1A237E),
          tileColor: Color(0xFF33691E),
        );
    }
  }

  /// 日付シード（YYYYMMDD）から天気を決定する。同日は常に同じ結果。
  static TownWeather weatherOf(DateTime date) {
    final seed = date.year * 10000 + date.month * 100 + date.day;
    final bucket = seed % 100;
    if (bucket < 50) return TownWeather.clear;
    if (bucket < 80) return TownWeather.cloudy;
    return TownWeather.rainy;
  }

  /// 月から季節を決定する。
  static TownSeason seasonOf(DateTime date) {
    final month = date.month;
    if (month >= 3 && month <= 5) return TownSeason.spring;
    if (month >= 6 && month <= 8) return TownSeason.summer;
    if (month >= 9 && month <= 11) return TownSeason.autumn;
    return TownSeason.winter;
  }

  /// 天気・季節に応じてパレットを微調整する。
  static TownAtmospherePalette applyWeatherAndSeason(
    TownAtmospherePalette base, {
    required TownWeather weather,
    required TownSeason season,
  }) {
    var sky = base.skyColor;
    var tile = base.tileColor;

    switch (weather) {
      case TownWeather.clear:
        break;
      case TownWeather.cloudy:
        sky = Color.lerp(sky, const Color(0xFF90A4AE), 0.28)!;
        tile = Color.lerp(tile, const Color(0xFF7CB342), 0.08)!;
      case TownWeather.rainy:
        sky = Color.lerp(sky, const Color(0xFF546E7A), 0.45)!;
        tile = Color.lerp(tile, const Color(0xFF558B2F), 0.12)!;
    }

    if (season == TownSeason.summer) {
      tile = Color.lerp(tile, const Color(0xFF33691E), 0.18)!;
    }

    return TownAtmospherePalette(skyColor: sky, tileColor: tile);
  }

  static ({String title, String description}) stageStory(String stageId) {
    switch (stageId) {
      case 'lightbulb':
        return (title: '最初の灯り', description: '暗い地平線に、豆電球がひとつ灯った。');
      case 'lamp':
        return (title: '道が見える', description: '電灯がつき、足元が少し安心になった。');
      case 'house_lights':
        return (
          title: '誰かの夜',
          description: '窓から明かりが漏れ、人が住みはじめた気配がする。'
        );
      case 'factory':
        return (
          title: '動き出す町',
          description: '工場が息を吹き返し、エネルギーが町を巡りはじめる。'
        );
      case 'town':
        return (title: '街の輪郭', description: '家並みが増え、ここが「街」と呼べるようになった。');
      case 'city':
        return (title: '都市の鼓動', description: '夜景が広がり、文明の灯りが空に届きそうだ。');
      case 'rocket':
        return (title: '空へ', description: 'ロケットが立つ。歩いて蓄えた力が、空を目指す。');
      default:
        return (title: '発展', description: '町が新しい段階へ進んだ。');
    }
  }

  static IconData stageIcon(TownStage stage) => stage.icon ?? Icons.landscape;

  static int residentDisplayCount({
    required int houseCount,
    required TownTimeOfDay timeOfDay,
    int maxResidents = 8,
  }) {
    final base = math.min(maxResidents, math.max(0, houseCount));
    if (timeOfDay == TownTimeOfDay.night) {
      return math.min(3, base ~/ 2);
    }
    return base;
  }
}
