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
        return (
          title: '最初の灯り',
          description: '暗い地球のどこかに、小さな灯りがひとつともった。',
        );
      case 'hatch':
        return (
          title: '村の灯り',
          description: '歩いて集めたエネルギーが、集落の明かりになって地表に点在しはじめた。',
        );
      case 'kid':
        return (
          title: '街の光帯',
          description: '街が連なり、衛星から見ると細い光の帯が走りはじめた。',
        );
      case 'charged':
        return (
          title: '大都市が輝く',
          description: '大都市圏が白く輝き、夜の地球に明るい核が生まれた。',
        );
      case 'reliable':
        return (
          title: '大陸の光網',
          description: '大陸を横断する光の網がつながり、人間の営みが線になって見える。',
        );
      case 'radiant':
        return (
          title: '夜の地球が浮かぶ',
          description: '夜側の地球のかたちがはっきり浮かび、灯りの地図が姿を現した。',
        );
      case 'star':
        return (
          title: '軌道から見た地球',
          description: '歩いて集めたエネルギーが、軌道から眺める夜の地球を全灯に近づけた。',
        );
      default:
        return (title: '灯りが広がる', description: '地球の夜に、新しい灯りが加わった。');
    }
  }

  static IconData stageIcon(CompanionStage stage) =>
      stage.icon ?? Icons.public_off_outlined;
}
