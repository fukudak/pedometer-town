import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/local_storage.dart';
import 'providers/energy_provider.dart';
import 'providers/history_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/town_provider.dart';
import 'screens/home_screen.dart';
import 'services/health_service.dart';

class PedometerTownApp extends StatefulWidget {
  final SharedPreferences prefs;
  final HealthService healthService;

  const PedometerTownApp({
    super.key,
    required this.prefs,
    required this.healthService,
  });

  @override
  State<PedometerTownApp> createState() => _PedometerTownAppState();
}

class _PedometerTownAppState extends State<PedometerTownApp> {
  late final SettingsProvider _settingsProvider;
  late final EnergyProvider _energyProvider;
  late final TownProvider _townProvider;
  late final HistoryProvider _historyProvider;

  @override
  void initState() {
    super.initState();
    final storage = LocalStorage(widget.prefs);
    _settingsProvider = SettingsProvider(storage);
    _energyProvider = EnergyProvider(
      storage,
      widget.healthService,
      _settingsProvider,
    );
    _townProvider = TownProvider(storage, _energyProvider, _settingsProvider);
    _energyProvider.setCoefficientSupplier(
      () => _townProvider.effectiveCoefficient,
    );
    _historyProvider = HistoryProvider(storage, _energyProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _settingsProvider),
        ChangeNotifierProvider.value(value: _energyProvider),
        ChangeNotifierProvider.value(value: _townProvider),
        ChangeNotifierProvider.value(value: _historyProvider),
      ],
      child: MaterialApp(
        title: '万歩計タウン',
        theme: _buildExpressiveTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}

/// Material 3 Expressive 流テーマ
/// （強めの角丸・tonal カラー・太めのタイポグラフィ）
/// 参考: https://m3.material.io/blog/building-with-m3-expressive
ThemeData _buildExpressiveTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: Colors.amber,
    brightness: Brightness.light,
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 8,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
      linearTrackColor: colorScheme.surfaceContainerHighest,
      linearMinHeight: 16,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}
