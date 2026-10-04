import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pedometer_town/data/local_storage.dart';
import 'package:pedometer_town/providers/companion_provider.dart';
import 'package:pedometer_town/providers/energy_provider.dart';
import 'package:pedometer_town/providers/settings_provider.dart';
import 'package:pedometer_town/screens/companion_screen.dart';
import 'package:pedometer_town/screens/home_screen.dart';
import 'package:pedometer_town/services/health_service.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(WidgetTester tester, int stock, Widget home) async {
    // 実機（1080x2400, 3x）相当の 360x800 論理サイズ
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({'pending_batteries': stock});
    final storage = LocalStorage(await SharedPreferences.getInstance());
    final settings = SettingsProvider(storage);
    final energy = EnergyProvider(storage, HealthService(), settings);
    final companion = CompanionProvider(storage, energy, settings);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: energy),
          ChangeNotifierProvider.value(value: companion),
        ],
        child: MaterialApp(home: home),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  for (final stock in [37, 250]) {
    testWidgets('星画面: ストック$stock個でもレイアウトがあふれず、投入ボタンと重ならない', (tester) async {
      await pump(tester, stock, const CompanionScreen());

      expect(tester.takeException(), isNull);
      final label = find.text('ストック: $stock 個');
      expect(label, findsOneWidget);
      final button = tester.getRect(find.text('投入'));
      expect(tester.getRect(label).right, lessThanOrEqualTo(button.left));
    });

    testWidgets('ホーム: ストック$stock個でも蓄電池カードからはみ出さない', (tester) async {
      await pump(tester, stock, const HomeScreen());

      expect(tester.takeException(), isNull);
      final label = find.text('ストック: $stock 個');
      expect(label, findsOneWidget);
      expect(tester.getRect(label).right, lessThanOrEqualTo(360 - 16));
    });
  }
}
