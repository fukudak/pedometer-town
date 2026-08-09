import 'package:flutter_test/flutter_test.dart';
import 'package:pedometer_town/constants/companion_atmosphere.dart';

void main() {
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
}
