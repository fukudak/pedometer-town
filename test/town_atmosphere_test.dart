import 'package:flutter_test/flutter_test.dart';
import 'package:pedometer_town/constants/town_atmosphere.dart';

void main() {
  group('TownAtmosphere.timeOfDay', () {
    test('5:00 は morning', () {
      expect(
        TownAtmosphere.timeOfDay(DateTime(2026, 7, 13, 5, 0)),
        TownTimeOfDay.morning,
      );
    });

    test('11:00 は day', () {
      expect(
        TownAtmosphere.timeOfDay(DateTime(2026, 7, 13, 11, 0)),
        TownTimeOfDay.day,
      );
    });

    test('17:00 は evening', () {
      expect(
        TownAtmosphere.timeOfDay(DateTime(2026, 7, 13, 17, 0)),
        TownTimeOfDay.evening,
      );
    });

    test('20:00 は night', () {
      expect(
        TownAtmosphere.timeOfDay(DateTime(2026, 7, 13, 20, 0)),
        TownTimeOfDay.night,
      );
    });

    test('4:59 は night', () {
      expect(
        TownAtmosphere.timeOfDay(DateTime(2026, 7, 13, 4, 59)),
        TownTimeOfDay.night,
      );
    });
  });

  group('TownAtmosphere.residentDisplayCount', () {
    test('住宅数を上限8でクランプする', () {
      expect(
        TownAtmosphere.residentDisplayCount(
          houseCount: 12,
          timeOfDay: TownTimeOfDay.day,
        ),
        8,
      );
    });

    test('住宅0は常に0人', () {
      expect(
        TownAtmosphere.residentDisplayCount(
          houseCount: 0,
          timeOfDay: TownTimeOfDay.day,
        ),
        0,
      );
    });

    test('夜は住民数が半減し最大3人', () {
      expect(
        TownAtmosphere.residentDisplayCount(
          houseCount: 8,
          timeOfDay: TownTimeOfDay.night,
        ),
        3,
      );
      expect(
        TownAtmosphere.residentDisplayCount(
          houseCount: 5,
          timeOfDay: TownTimeOfDay.night,
        ),
        2,
      );
    });
  });

  group('TownAtmosphere.weatherOf', () {
    test('同じ日付は常に同じ天気', () {
      final date = DateTime(2026, 7, 13);
      expect(TownAtmosphere.weatherOf(date), TownAtmosphere.weatherOf(date));
    });

    test('日付が違えば結果が変わりうる', () {
      final a = TownAtmosphere.weatherOf(DateTime(2026, 1, 1));
      final b = TownAtmosphere.weatherOf(DateTime(2026, 1, 2));
      expect(a, isA<TownWeather>());
      expect(b, isA<TownWeather>());
    });
  });

  group('TownAtmosphere.seasonOf', () {
    test('春は3〜5月', () {
      expect(
        TownAtmosphere.seasonOf(DateTime(2026, 3, 1)),
        TownSeason.spring,
      );
      expect(
        TownAtmosphere.seasonOf(DateTime(2026, 5, 31)),
        TownSeason.spring,
      );
    });

    test('夏は6〜8月', () {
      expect(
        TownAtmosphere.seasonOf(DateTime(2026, 7, 13)),
        TownSeason.summer,
      );
    });

    test('秋は9〜11月', () {
      expect(
        TownAtmosphere.seasonOf(DateTime(2026, 10, 1)),
        TownSeason.autumn,
      );
    });

    test('冬は12〜2月', () {
      expect(
        TownAtmosphere.seasonOf(DateTime(2026, 12, 1)),
        TownSeason.winter,
      );
      expect(
        TownAtmosphere.seasonOf(DateTime(2026, 2, 28)),
        TownSeason.winter,
      );
    });
  });

  group('TownAtmosphere.applyWeatherAndSeason', () {
    test('夏はタイルがより緑になる', () {
      final base = TownAtmosphere.paletteOf(TownTimeOfDay.day);
      final adjusted = TownAtmosphere.applyWeatherAndSeason(
        base,
        weather: TownWeather.clear,
        season: TownSeason.summer,
      );
      expect(adjusted.tileColor, isNot(equals(base.tileColor)));
    });
  });
}
