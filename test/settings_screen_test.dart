import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pedometer_town/constants/game_constants.dart';
import 'package:pedometer_town/data/local_storage.dart';
import 'package:pedometer_town/providers/settings_provider.dart';
import 'package:pedometer_town/screens/settings_screen.dart';

void main() {
  const packageInfoChannel =
      MethodChannel('dev.fluttercommunity.plus/package_info');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, (call) async {
      if (call.method == 'getAll') {
        return <String, dynamic>{
          'appName': '万歩計タウン',
          'packageName': 'com.pedometertown.pedometer_town',
          'version': '1.0.0',
          'buildNumber': '1',
          'installerStore': null,
        };
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, null);
  });

  Future<LocalStorage> pumpSettingsScreen(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorage(await SharedPreferences.getInstance());
    final settingsProvider = SettingsProvider(storage);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settingsProvider,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return storage;
  }

  Future<void> tapSave(WidgetTester tester) async {
    final saveButton = find.widgetWithText(FilledButton, '保存');
    await tester.scrollUntilVisible(
      saveButton,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(saveButton);
    await tester.pump();
  }

  testWidgets('フォーカスを外さず保存を押しても、入力欄の新しい値が保存される',
      (WidgetTester tester) async {
    final storage = await pumpSettingsScreen(tester);

    final weightFieldFinder = find.ancestor(
      of: find.text('体重'),
      matching: find.byType(Row),
    );
    final textFieldFinder =
        find.descendant(of: weightFieldFinder, matching: find.byType(TextField));

    // フォーカスアウト（tap による defocus や onSubmitted）を経由せず、
    // 入力だけ行って保存ボタンを押す。
    await tester.enterText(textFieldFinder, '55');
    await tapSave(tester);

    expect(storage.loadPlayerSettings().weightKg, 55.0);
  });

  testWidgets('不正な文字列を入力した場合は直前の値にフォールバックして保存される',
      (WidgetTester tester) async {
    final storage = await pumpSettingsScreen(tester);
    final before = storage.loadPlayerSettings().weightKg;

    final weightFieldFinder = find.ancestor(
      of: find.text('体重'),
      matching: find.byType(Row),
    );
    final textFieldFinder =
        find.descendant(of: weightFieldFinder, matching: find.byType(TextField));

    await tester.enterText(textFieldFinder, 'abc');
    await tapSave(tester);

    expect(storage.loadPlayerSettings().weightKg, before);
  });

  testWidgets('最小値未満を入力した場合は範囲内にクランプされて保存される',
      (WidgetTester tester) async {
    final storage = await pumpSettingsScreen(tester);

    final weightFieldFinder = find.ancestor(
      of: find.text('体重'),
      matching: find.byType(Row),
    );
    final textFieldFinder =
        find.descendant(of: weightFieldFinder, matching: find.byType(TextField));

    await tester.enterText(textFieldFinder, '0');
    await tapSave(tester);

    expect(storage.loadPlayerSettings().weightKg, GameConstants.minWeightKg);
  });

  testWidgets('最大値超過を入力した場合は範囲内にクランプされて保存される',
      (WidgetTester tester) async {
    final storage = await pumpSettingsScreen(tester);

    final weightFieldFinder = find.ancestor(
      of: find.text('体重'),
      matching: find.byType(Row),
    );
    final textFieldFinder =
        find.descendant(of: weightFieldFinder, matching: find.byType(TextField));

    await tester.enterText(textFieldFinder, '9999');
    await tapSave(tester);

    expect(storage.loadPlayerSettings().weightKg, GameConstants.maxWeightKg);
  });

  testWidgets('まちの名前もフォーカスを外さず保存すれば前後の空白を除去して保存される',
      (WidgetTester tester) async {
    final storage = await pumpSettingsScreen(tester);

    final nameFieldFinder = find.ancestor(
      of: find.text('まちの名前'),
      matching: find.byType(Row),
    );
    final textFieldFinder =
        find.descendant(of: nameFieldFinder, matching: find.byType(TextField));

    await tester.scrollUntilVisible(
      textFieldFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(textFieldFinder, '  ほしのまち  ');
    await tapSave(tester);

    expect(storage.loadPlayerSettings().companionName, 'ほしのまち');
  });

  testWidgets('設定画面のバージョン表示は配布バージョン（pubspec.yaml）から取得される',
      (WidgetTester tester) async {
    await pumpSettingsScreen(tester);

    final versionText = find.textContaining('バージョン');
    await tester.scrollUntilVisible(
      versionText,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('バージョン 1.0.0+1'), findsOneWidget);
  });
}
