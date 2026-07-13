import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/energy_provider.dart';
import '../services/health_service.dart';
import '../widgets/battery_stock_display.dart';
import 'history_screen.dart';
import 'how_to_play_screen.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(context);
    });
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
    final lastSyncedAt = energyProvider.lastSyncedAt;
    final progress = battery.capacityWh == 0
        ? 0.0
        : (battery.storedWh / battery.capacityWh).clamp(0.0, 1.0);

    final colorScheme = Theme.of(context).colorScheme;

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
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
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
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            color: colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: colorScheme.primary,
                        child: Icon(
                          Icons.battery_charging_full,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '蓄電池',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: colorScheme.surface,
                      minHeight: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${battery.storedWh.toStringAsFixed(1)} / '
                    '${battery.capacityWh.toStringAsFixed(0)} Wh',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      BatteryStockDisplay(count: energyProvider.pendingBatteries),
                      const SizedBox(width: 12),
                      Text(
                        'ストック: ${energyProvider.pendingBatteries} 個',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.directions_walk,
                  label: '今日の歩数',
                  value: '${today.totalSteps}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.bolt,
                  label: '今日の発電量',
                  value: '${today.totalEnergyWh.toStringAsFixed(1)} Wh',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.emoji_events,
            label: '累積発電量',
            value:
                '${energyProvider.lifetimeEnergyWh.toStringAsFixed(1)} Wh',
            fullWidth: true,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              lastSyncedAt == null
                  ? '最終同期: 未同期'
                  : '最終同期: ${_formatSyncTime(lastSyncedAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _sync(context),
            icon: const Icon(Icons.sync),
            label: const Text('同期'),
          ),
          const SizedBox(height: 24),
          Text('メニュー', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TownScreen()),
                  ),
                  icon: const Icon(Icons.location_city),
                  label: const Text('町'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  ),
                  icon: const Icon(Icons.history),
                  label: const Text('履歴'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  icon: const Icon(Icons.settings),
                  label: const Text('設定'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HowToPlayScreen()),
            ),
            icon: const Icon(Icons.help_outline),
            label: const Text('遊び方'),
          ),
        ],
      ),
    );
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  String _formatSyncTime(DateTime time) {
    final now = DateTime.now();
    final timeStr = '${_pad(time.hour)}:${_pad(time.minute)}';
    final isToday = time.year == now.year &&
        time.month == now.month &&
        time.day == now.day;
    if (isToday) return timeStr;
    return '${time.month}/${time.day} $timeStr';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool fullWidth;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: fullWidth
            ? Row(
                children: [
                  _icon(colorScheme),
                  const SizedBox(width: 12),
                  Text(label, style: TextStyle(color: colorScheme.outline)),
                  const Spacer(),
                  Text(
                    value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _icon(colorScheme),
                  const SizedBox(height: 8),
                  Text(label, style: TextStyle(color: colorScheme.outline)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _icon(ColorScheme colorScheme) => CircleAvatar(
        radius: 16,
        backgroundColor: colorScheme.secondaryContainer,
        child: Icon(icon, size: 18, color: colorScheme.onSecondaryContainer),
      );
}
