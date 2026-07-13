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
}
