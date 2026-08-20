import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedometer_town/constants/companion_stages.dart';
import 'package:pedometer_town/domain/companion_logic.dart';
import 'package:pedometer_town/widgets/companion/companion_avatar.dart';

void main() {
  testWidgets('全進化段階の CompanionAvatar が描画できる', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              for (final stage in CompanionStages.stages)
                CompanionAvatar(
                  stage: stage,
                  mood: CompanionMood.happy,
                  size: 48,
                  interactive: false,
                  autoSpin: false,
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CompanionAvatar), findsNWidgets(CompanionStages.stages.length));
    expect(find.byType(ClipOval), findsWidgets);
  });

  test('EarthLights は地球が1個完成するたびに真っ暗にリセットされる', () {
    // 最終段階直前（16）はほぼ満点の明るさ
    expect(EarthLights.countFor(16), greaterThan(0));
    expect(EarthLights.glowFor(16), closeTo(0.94, 0.01));

    // 最終段階到達＝地球1個目が完成した瞬間は真っ暗
    expect(EarthLights.countFor(17), 0);
    expect(EarthLights.glowFor(17), 0.0);

    // 2個目の地球が完成する直前（33）は再びほぼ満点
    expect(EarthLights.countFor(33), greaterThan(0));
    expect(EarthLights.glowFor(33), closeTo(0.94, 0.01));

    // 2個目の地球が完成した瞬間（34）も再び真っ暗
    expect(EarthLights.countFor(34), 0);
    expect(EarthLights.glowFor(34), 0.0);
  });
}
