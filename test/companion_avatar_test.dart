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
}
