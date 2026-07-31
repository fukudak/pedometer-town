import 'package:flutter_test/flutter_test.dart';
import 'package:pedometer_town/domain/companion_logic.dart';
import 'package:pedometer_town/domain/models/companion_state.dart';

void main() {
  group('CompanionLogic.effectiveCapacity', () {
    test('げんきの素がなければベース容量のまま', () {
      final result = CompanionLogic.effectiveCapacity(10000, const CompanionState());
      expect(result, 10000);
    });

    test('げんきの素1回につき+2000Wh', () {
      final result = CompanionLogic.effectiveCapacity(
        10000,
        const CompanionState(boosterCount: 1),
      );
      expect(result, 12000);
    });

    test('げんきの素2回なら+4000Wh', () {
      final result = CompanionLogic.effectiveCapacity(
        10000,
        const CompanionState(boosterCount: 2),
      );
      expect(result, 14000);
    });
  });

  group('CompanionLogic.effectiveCoefficient', () {
    test('おもちゃがなければベース係数のまま', () {
      final result = CompanionLogic.effectiveCoefficient(0.01, const CompanionState());
      expect(result, closeTo(0.01, 1e-12));
    });

    test('おもちゃ1回につき×1.1', () {
      final result = CompanionLogic.effectiveCoefficient(
        0.01,
        const CompanionState(toyCount: 1),
      );
      expect(result, closeTo(0.011, 1e-12));
    });

    test('おもちゃ2回なら×1.1×1.1', () {
      final result = CompanionLogic.effectiveCoefficient(
        0.01,
        const CompanionState(toyCount: 2),
      );
      expect(result, closeTo(0.01 * 1.1 * 1.1, 1e-12));
    });
  });

  group('CompanionLogic.bondScore', () {
    test('level×10 + 累積発電量/100(切捨て) + きらめき×50', () {
      final result = CompanionLogic.bondScore(
        level: 3,
        lifetimeEnergyWh: 250,
        sparkleMoments: 2,
      );
      expect(result, 3 * 10 + 2 + 2 * 50);
    });
  });

  group('CompanionLogic.moodFor', () {
    final base = DateTime(2026, 7, 30, 12, 0);

    test('一度も給餌していない場合は none', () {
      expect(
        CompanionLogic.moodFor(now: base, lastFedAt: null),
        CompanionMood.none,
      );
    });

    test('24時間以内は happy', () {
      expect(
        CompanionLogic.moodFor(now: base, lastFedAt: base.subtract(const Duration(hours: 24))),
        CompanionMood.happy,
      );
      expect(
        CompanionLogic.moodFor(now: base, lastFedAt: base.subtract(const Duration(hours: 1))),
        CompanionMood.happy,
      );
    });

    test('24時間超〜3日以内は normal', () {
      expect(
        CompanionLogic.moodFor(now: base, lastFedAt: base.subtract(const Duration(hours: 25))),
        CompanionMood.normal,
      );
      expect(
        CompanionLogic.moodFor(now: base, lastFedAt: base.subtract(const Duration(days: 3))),
        CompanionMood.normal,
      );
    });

    test('3日超は lonely', () {
      expect(
        CompanionLogic.moodFor(
          now: base,
          lastFedAt: base.subtract(const Duration(days: 3, hours: 1)),
        ),
        CompanionMood.lonely,
      );
    });
  });
}
