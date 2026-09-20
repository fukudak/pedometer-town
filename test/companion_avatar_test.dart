import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedometer_town/constants/companion_stages.dart';
import 'package:pedometer_town/domain/companion_logic.dart';
import 'package:pedometer_town/widgets/companion/companion_avatar.dart';

void main() {
  testWidgets('全進化段階の CompanionAvatar が描画できる', (tester) async {
    // 段階数ぶんの高さを確保し、ListView のビューポート外で
    // レンダリングされない項目が出ないようにする。
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

  test('EarthLights は地球が完成した瞬間は満天になり、次の投入で真っ暗にリセットされる', () {
    final finalLevel = CompanionStages.stages.last.minLevel;

    // 最終段階直前はほぼ満点の明るさ
    expect(EarthLights.countFor(finalLevel - 1), greaterThan(0));
    expect(EarthLights.glowFor(finalLevel - 1), closeTo(0.98, 0.02));

    // 最終段階到達＝地球1個目が完成した瞬間は満天の灯り
    expect(
      EarthLights.countFor(finalLevel),
      greaterThanOrEqualTo(EarthLights.countFor(finalLevel - 1)),
    );
    expect(EarthLights.glowFor(finalLevel), 1.0);

    // その次の投入で真っ暗にリセットされ、2個目の地球へ向けて灯りが増え始める
    expect(
      EarthLights.countFor(finalLevel + 1),
      lessThan(EarthLights.countFor(finalLevel - 1)),
    );
    expect(EarthLights.glowFor(finalLevel + 1), closeTo(0.0, 0.02));

    // 2個目の地球が完成する直前は再びほぼ満点
    expect(EarthLights.countFor(finalLevel * 2 - 1), greaterThan(0));
    expect(EarthLights.glowFor(finalLevel * 2 - 1), closeTo(0.98, 0.02));

    // 2個目の地球が完成した瞬間も再び満天になる
    expect(
      EarthLights.countFor(finalLevel * 2),
      greaterThanOrEqualTo(EarthLights.countFor(finalLevel * 2 - 1)),
    );
    expect(EarthLights.glowFor(finalLevel * 2), 1.0);

    // さらにその次の投入で再び真っ暗にリセットされる
    expect(
      EarthLights.countFor(finalLevel * 2 + 1),
      lessThan(EarthLights.countFor(finalLevel * 2 - 1)),
    );
    expect(EarthLights.glowFor(finalLevel * 2 + 1), closeTo(0.0, 0.02));
  });
}
