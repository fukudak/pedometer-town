import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pedometer_town/app.dart';
import 'package:pedometer_town/screens/how_to_play_screen.dart';
import 'package:pedometer_town/services/health_service.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      PedometerTownApp(prefs: prefs, healthService: HealthService()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ホーム画面に「遊び方」ボタンは表示されない（設定画面に移動済み）',
      (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('遊び方'), findsNothing);
  });

  testWidgets('ホーム画面の「まち」アイコンは地球儀（Icons.public）',
      (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.byIcon(Icons.public), findsOneWidget);
    expect(find.byIcon(Icons.location_city), findsNothing);
  });

  testWidgets('設定画面から「遊び方」画面に遷移できる', (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    final howToPlayButton = find.widgetWithText(OutlinedButton, '遊び方');
    await tester.scrollUntilVisible(
      howToPlayButton,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(howToPlayButton, findsOneWidget);
    await tester.tap(howToPlayButton);
    await tester.pumpAndSettle();

    expect(find.byType(HowToPlayScreen), findsOneWidget);
  });
}
