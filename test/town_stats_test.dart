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
}
