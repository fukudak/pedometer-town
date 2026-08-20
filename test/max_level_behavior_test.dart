import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pedometer_town/data/local_storage.dart';
import 'package:pedometer_town/domain/models/feed_item_type.dart';
import 'package:pedometer_town/providers/companion_provider.dart';
import 'package:pedometer_town/providers/energy_provider.dart';
import 'package:pedometer_town/providers/settings_provider.dart';
import 'package:pedometer_town/screens/companion_screen.dart';
import 'package:pedometer_town/services/health_service.dart';

void main() {
  Future<void> pumpAtLevel(WidgetTester tester, int level) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorage(await SharedPreferences.getInstance());
    final settingsProvider = SettingsProvider(storage);
    final energyProvider =
        EnergyProvider(storage, HealthService(), settingsProvider);
    final companionProvider =
        CompanionProvider(storage, energyProvider, settingsProvider);

    // UI と同じ経路（投入）で発展度を level まで積む。
    for (var i = 0; i < level; i++) {
      await companionProvider.feedChosen(FeedItemType.meal);
    }
    companionProvider.clearPendingStageCelebrations();
    companionProvider.clearPendingCelebrations();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settingsProvider),
          ChangeNotifierProvider.value(value: energyProvider),
          ChangeNotifierProvider.value(value: companionProvider),
        ],
        child: const MaterialApp(home: CompanionScreen()),
      ),
    );
    // idle/spin アニメーションは無限リピートなので pumpAndSettle は使わない。
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('最終段階直前（発展度16）は通常の次段階カードが出る', (WidgetTester tester) async {
    await pumpAtLevel(tester, 16);

    expect(find.text('発展度 16'), findsOneWidget);
    expect(find.textContaining('あと 1 回投入すると灯りが広がる'), findsOneWidget);
    expect(find.textContaining('完成した地球'), findsNothing);
  });

  testWidgets('最終段階到達（発展度17）で地球ストックカードに切り替わる', (WidgetTester tester) async {
    await pumpAtLevel(tester, 17);

    expect(find.text('発展度 17'), findsOneWidget);
    expect(find.text('軌道から見た地球'), findsOneWidget);
    expect(find.textContaining('完成した地球 1 個'), findsOneWidget);
    expect(find.textContaining('あと 17 回投入すると次の地球が完成する'), findsOneWidget);
  });

  testWidgets('最終段階後さらに投入を重ねると地球の個数が増える（発展度34）',
      (WidgetTester tester) async {
    await pumpAtLevel(tester, 34);

    expect(find.text('発展度 34'), findsOneWidget);
    expect(find.textContaining('完成した地球 2 個'), findsOneWidget);
    expect(find.textContaining('あと 17 回投入すると次の地球が完成する'), findsOneWidget);
  });
}
