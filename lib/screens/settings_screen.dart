import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/game_constants.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _weightKg;
  late double _speedKmh;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _weightKg = settings.weightKg;
    _speedKmh = settings.defaultSpeedKmh;
  }

  Future<void> _save() async {
    final provider = context.read<SettingsProvider>();
    await provider.updateWeight(_weightKg);
    await provider.updateSpeed(_speedKmh);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保存しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('体重: ${_weightKg.toStringAsFixed(0)} kg'),
            Slider(
              value: _weightKg,
              min: GameConstants.minWeightKg,
              max: GameConstants.maxWeightKg,
              divisions: (GameConstants.maxWeightKg - GameConstants.minWeightKg)
                  .toInt(),
              label: _weightKg.toStringAsFixed(0),
              onChanged: (value) => setState(() => _weightKg = value),
            ),
            const SizedBox(height: 16),
            Text('デフォルト速度: ${_speedKmh.toStringAsFixed(1)} km/h'),
            Slider(
              value: _speedKmh,
              min: GameConstants.minSpeedKmh,
              max: GameConstants.maxSpeedKmh,
              divisions: ((GameConstants.maxSpeedKmh - GameConstants.minSpeedKmh) *
                      10)
                  .toInt(),
              label: _speedKmh.toStringAsFixed(1),
              onChanged: (value) => setState(() => _speedKmh = value),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: const Text('保存'),
            ),
            const Spacer(),
            Center(
              child: Text(
                'バージョン ${GameConstants.appVersion}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
