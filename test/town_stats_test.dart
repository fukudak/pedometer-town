import 'package:flutter_test/flutter_test.dart';
import 'package:pedometer_town/constants/companion_stages.dart';

void main() {
  test('TownStats は段階に応じて灯り都市・照らされた人が増える', () {
    expect(TownStats.buildingCount(0), 0);
    expect(TownStats.population(0), 0);

    expect(TownStats.buildingCount(1), 1);
    expect(TownStats.population(1), greaterThan(0));

    expect(TownStats.buildingCount(17), 72);
    expect(TownStats.population(17), 72 * 100);
  });

  test('nextMilestone は残り回数と次の姿を返す', () {
    final m = CompanionStages.nextMilestone(0);
    expect(m, isNotNull);
    expect(m!.remaining, 1);
    expect(m.stage.id, 'crack');
    expect(m.buildings, greaterThan(0));

    final nearRocket = CompanionStages.nextMilestone(15);
    expect(nearRocket!.remaining, 2);
    expect(nearRocket.stage.id, 'star');

    expect(CompanionStages.nextMilestone(17), isNull);
  });

  test('earthCount は最終段階到達後、一定回数ごとに1個ずつ積み上がる', () {
    expect(CompanionStages.earthCount(16), 0);
    expect(CompanionStages.remainingForNextEarth(16), isNull);

    expect(CompanionStages.earthCount(17), 1);
    expect(CompanionStages.remainingForNextEarth(17), 17);

    expect(CompanionStages.earthCount(33), 1);
    expect(CompanionStages.remainingForNextEarth(33), 1);

    expect(CompanionStages.earthCount(34), 2);
    expect(CompanionStages.remainingForNextEarth(34), 17);
  });
}
