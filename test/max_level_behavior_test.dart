import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pedometer_town/constants/companion_stages.dart';
import 'package:pedometer_town/data/local_storage.dart';
import 'package:pedometer_town/domain/models/feed_item_type.dart';
import 'package:pedometer_town/providers/companion_provider.dart';
import 'package:pedometer_town/providers/energy_provider.dart';
import 'package:pedometer_town/providers/settings_provider.dart';
import 'package:pedometer_town/screens/companion_screen.dart';
import 'package:pedometer_town/services/health_service.dart';

void main() {
  final finalLevel = CompanionStages.stages.last.minLevel;

  // HapticFeedback（星の完成お祝い演出で呼ぶ）はテスト環境では応答が返らず
  // ハングするため、プラットフォームチャンネルをモックしておく。
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

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
    companionProvider.clearPendingStarCompletions();

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

  testWidgets('最終段階直前は通常の次段階カードが出る', (WidgetTester tester) async {
    final level = finalLevel - 1;
    await pumpAtLevel(tester, level);

    expect(find.text('発展度 $level'), findsOneWidget);
    expect(find.textContaining('あと 1 回投入すると灯りが広がる'), findsOneWidget);
    expect(find.textContaining('完成した星'), findsNothing);
  });

  testWidgets('最終段階到達で星ストックカードに切り替わる', (WidgetTester tester) async {
    await pumpAtLevel(tester, finalLevel);

    expect(find.text('発展度 $finalLevel'), findsOneWidget);
    expect(find.text('軌道から見た星'), findsOneWidget);
    expect(find.textContaining('完成した星 1 個'), findsOneWidget);
    expect(find.textContaining('あと $finalLevel 回投入すると次の星が完成する'), findsOneWidget);
  });

  testWidgets('最終段階後さらに投入を重ねると星の個数が増える',
      (WidgetTester tester) async {
    final level = finalLevel * 2;
    await pumpAtLevel(tester, level);

    expect(find.text('発展度 $level'), findsOneWidget);
    expect(find.textContaining('完成した星 2 個'), findsOneWidget);
    expect(find.textContaining('あと $finalLevel 回投入すると次の星が完成する'), findsOneWidget);
  });

  testWidgets('最終段階到達直前で「投入」すると星の完成お祝いダイアログが出る',
      (WidgetTester tester) async {
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

    for (var i = 0; i < finalLevel - 1; i++) {
      await companionProvider.feedChosen(FeedItemType.meal);
    }
    companionProvider.clearPendingStageCelebrations();
    companionProvider.clearPendingCelebrations();
    companionProvider.clearPendingStarCompletions();
    await energyProvider.creditStockedBatteries(1);

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
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    await tester.tap(find.text('投入'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // 最終段階（星）到達の通常演出が先に出る。閉じて次へ進む。
    expect(find.text('軌道から見た星'), findsOneWidget);
    await tester.tap(find.text('もっと歩く'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('星が完成した！'), findsOneWidget);
    // 背景の星ストックカードにも同じ文言が出るため、複数ヒットを許容する。
    expect(find.textContaining('完成した星 1 個'), findsWidgets);

    await tester.tap(find.text('つづける'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('星が完成した！'), findsNothing);
  });
}
