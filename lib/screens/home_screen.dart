import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/energy_provider.dart';
import '../services/health_service.dart';
import 'settings_screen.dart';
import 'town_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync(context);
    }
  }

  Future<void> _sync(BuildContext context) async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await context.read<EnergyProvider>().syncStepsFromHealth();
    } on HealthServiceException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      _isSyncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final energyProvider = context.watch<EnergyProvider>();
    final battery = energyProvider.battery;
    final today = energyProvider.today;
    final progress = battery.capacityWh == 0
        ? 0.0
        : (battery.storedWh / battery.capacityWh).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('万歩計タウン'),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_city),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TownScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('蓄電池', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 4),
            Text(
              '${battery.storedWh.toStringAsFixed(1)} / '
              '${battery.capacityWh.toStringAsFixed(0)} Wh',
            ),
            const SizedBox(height: 24),
            Text('今日の歩数: ${today.totalSteps}'),
            Text('今日獲得したエネルギー: ${today.totalEnergyWh.toStringAsFixed(1)} Wh'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _sync(context),
              child: const Text('同期'),
            ),
          ],
        ),
      ),
    );
  }
}
