import 'package:flutter_test/flutter_test.dart';
import 'package:pedometer_town/constants/companion_atmosphere.dart';

void main() {
  group('CompanionAtmosphere.timeOfDay', () {
    test('5:00 は morning', () {
      expect(
        CompanionAtmosphere.timeOfDay(DateTime(2026, 7, 13, 5, 0)),
        CompanionTimeOfDay.morning,
      );
    });

    test('11:00 は day', () {
      expect(
        CompanionAtmosphere.timeOfDay(DateTime(2026, 7, 13, 11, 0)),
        CompanionTimeOfDay.day,
      );
    });

    test('17:00 は evening', () {
      expect(
        CompanionAtmosphere.timeOfDay(DateTime(2026, 7, 13, 17, 0)),
        CompanionTimeOfDay.evening,
      );
    });

    test('20:00 は night', () {
      expect(
        CompanionAtmosphere.timeOfDay(DateTime(2026, 7, 13, 20, 0)),
        CompanionTimeOfDay.night,
      );
    });

    test('4:59 は night', () {
      expect(
        CompanionAtmosphere.timeOfDay(DateTime(2026, 7, 13, 4, 59)),
        CompanionTimeOfDay.night,
      );
    });
  });

  group('CompanionAtmosphere.weatherOf', () {
    test('同じ日付は常に同じ天気', () {
      final date = DateTime(2026, 7, 13);
      expect(
        CompanionAtmosphere.weatherOf(date),
        CompanionAtmosphere.weatherOf(date),
      );
    });

    test('日付が違えば結果が変わりうる', () {
      final a = CompanionAtmosphere.weatherOf(DateTime(2026, 1, 1));
      final b = CompanionAtmosphere.weatherOf(DateTime(2026, 1, 2));
      expect(a, isA<CompanionWeather>());
      expect(b, isA<CompanionWeather>());
    });
  });

  group('CompanionAtmosphere.seasonOf', () {
    test('春は3〜5月', () {
      expect(
        CompanionAtmosphere.seasonOf(DateTime(2026, 3, 1)),
        CompanionSeason.spring,
      );
      expect(
        CompanionAtmosphere.seasonOf(DateTime(2026, 5, 31)),
        CompanionSeason.spring,
      );
    });

    test('夏は6〜8月', () {
      expect(
        CompanionAtmosphere.seasonOf(DateTime(2026, 7, 13)),
        CompanionSeason.summer,
      );
    });

    test('秋は9〜11月', () {
      expect(
        CompanionAtmosphere.seasonOf(DateTime(2026, 10, 1)),
        CompanionSeason.autumn,
      );
    });

    test('冬は12〜2月', () {
      expect(
        CompanionAtmosphere.seasonOf(DateTime(2026, 12, 1)),
        CompanionSeason.winter,
      );
      expect(
        CompanionAtmosphere.seasonOf(DateTime(2026, 2, 28)),
        CompanionSeason.winter,
      );
    });
  });

  group('CompanionAtmosphere.applyWeatherAndSeason', () {
    test('夏はタイルがより緑になる', () {
      final base = CompanionAtmosphere.paletteOf(CompanionTimeOfDay.day);
      final adjusted = CompanionAtmosphere.applyWeatherAndSeason(
        base,
        weather: CompanionWeather.clear,
        season: CompanionSeason.summer,
      );
      expect(adjusted.tileColor, isNot(equals(base.tileColor)));
    });
  });
}
