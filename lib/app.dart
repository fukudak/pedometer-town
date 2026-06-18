import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/local_storage.dart';
import 'providers/energy_provider.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _settingsProvider),
        ChangeNotifierProvider.value(value: _energyProvider),
        ChangeNotifierProvider.value(value: _townProvider),
      ],
      child: MaterialApp(
        title: '万歩計タウン',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
