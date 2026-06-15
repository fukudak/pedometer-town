import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/local_storage.dart';
import 'providers/energy_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/town_provider.dart';
import 'screens/home_screen.dart';
import 'services/health_service.dart';

class PedometerTownApp extends StatelessWidget {
  final SharedPreferences prefs;
  final HealthService healthService;

  const PedometerTownApp({
    super.key,
    required this.prefs,
    required this.healthService,
  });

  @override
  Widget build(BuildContext context) {
    final storage = LocalStorage(prefs);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(storage),
        ),
        ChangeNotifierProvider(
          create: (context) => EnergyProvider(
            storage,
            healthService,
            context.read<SettingsProvider>(),
            // TownProvider はこの後に登録されるが、呼び出し時点では
            // ツリーに存在するため遅延参照で問題ない。
            coefficientSupplier: () =>
                context.read<TownProvider>().effectiveCoefficient,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => TownProvider(
            storage,
            context.read<EnergyProvider>(),
          ),
        ),
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
