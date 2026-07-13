import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'town_stages.dart';

enum TownTimeOfDay { morning, day, evening, night }

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
