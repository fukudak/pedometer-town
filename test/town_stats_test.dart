import 'package:flutter_test/flutter_test.dart';
import 'package:pedometer_town/constants/companion_stages.dart';

void main() {
  test('TownStats は段階に応じて灯り都市・照らされた人が増える', () {
    expect(TownStats.buildingCount(0), 0);
    expect(TownStats.population(0), 0);

    expect(TownStats.buildingCount(1), 1);
    expect(TownStats.population(1), greaterThan(0));

    final finalLevel = CompanionStages.stages.last.minLevel;
    expect(finalLevel, 55);
    expect(TownStats.buildingCount(finalLevel), 145);
    expect(TownStats.population(finalLevel), 145 * 100);
  });

  test('段階は20段階ある', () {
    expect(CompanionStages.stages.length, 20);
  });

  test('nextMilestone は残り回数と次の姿を返す', () {
    final m = CompanionStages.nextMilestone(0);
    expect(m, isNotNull);
    expect(m!.remaining, 1);
    expect(m.stage.id, 'spark');
    expect(m.buildings, greaterThan(0));

    final finalLevel = CompanionStages.stages.last.minLevel;
    final secondToLast = CompanionStages.stages[CompanionStages.stages.length - 2];
    final nearRocket = CompanionStages.nextMilestone(secondToLast.minLevel);
    expect(nearRocket!.remaining, finalLevel - secondToLast.minLevel);
    expect(nearRocket.stage.id, 'star');

    expect(CompanionStages.nextMilestone(finalLevel), isNull);
  });

  test('earthCount は最終段階到達後、一定回数ごとに1個ずつ積み上がる', () {
    final finalLevel = CompanionStages.stages.last.minLevel;

    expect(CompanionStages.earthCount(finalLevel - 1), 0);
    expect(CompanionStages.remainingForNextEarth(finalLevel - 1), isNull);

    expect(CompanionStages.earthCount(finalLevel), 1);
    expect(CompanionStages.remainingForNextEarth(finalLevel), finalLevel);

    expect(CompanionStages.earthCount(finalLevel * 2 - 1), 1);
    expect(CompanionStages.remainingForNextEarth(finalLevel * 2 - 1), 1);

    expect(CompanionStages.earthCount(finalLevel * 2), 2);
    expect(CompanionStages.remainingForNextEarth(finalLevel * 2), finalLevel);
  });
}
