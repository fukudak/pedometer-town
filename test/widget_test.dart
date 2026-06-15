import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pedometer_town/app.dart';
import 'package:pedometer_town/services/health_service.dart';

void main() {
  testWidgets('ホーム画面に蓄電池と同期ボタンが表示される', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      PedometerTownApp(prefs: prefs, healthService: HealthService()),
    );

    expect(find.text('蓄電池'), findsOneWidget);
    expect(find.text('同期'), findsOneWidget);
    expect(find.text('0.0 / 10000 Wh'), findsOneWidget);
  });
}
