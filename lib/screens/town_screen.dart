import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/building_definitions.dart';
import '../constants/game_constants.dart';
import '../constants/town_stages.dart';
import '../domain/models/building.dart';
import '../domain/models/town_state.dart';
import '../providers/energy_provider.dart';
import '../providers/town_provider.dart';
import '../widgets/battery_stock_display.dart';

class TownScreen extends StatefulWidget {
  const TownScreen({super.key});

  @override
  State<TownScreen> createState() => _TownScreenState();
}

class _TownScreenState extends State<TownScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCelebrations());
  }

  Future<void> _showCelebrations() async {
    final townProvider = context.read<TownProvider>();
    final pending = townProvider.pendingCelebrations;
    if (pending.isEmpty) return;
    townProvider.clearPendingCelebrations();

    for (final achievement in pending) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          icon: Icon(achievement.icon, size: 40, color: Colors.amber),
          title: Text('実績解除！'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                achievement.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(achievement.description),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('やったね'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _useStock() async {
    final energyProvider = context.read<EnergyProvider>();
    final townProvider = context.read<TownProvider>();
    final stock = energyProvider.pendingBatteries;

    final type = await showModalBottomSheet<BuildingType>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '建てる建物を選んでください',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            for (final type in BuildingType.values)
              Builder(
                builder: (context) {
                  final def = BuildingDefinitions.of(type);
                  final affordable = stock >= def.batteryCost;
                  return ListTile(
                    leading: Icon(def.icon),
                    title: Text(def.displayName),
                    subtitle: Text('消費電池: ${def.batteryCost}個'),
                    enabled: affordable,
                    onTap: affordable
                        ? () => Navigator.of(context).pop(type)
                        : null,
                  );
                },
              ),
          ],
        ),
      ),
    );
    if (type == null) return;

    final cost = BuildingDefinitions.of(type).batteryCost;
    final consumed = await energyProvider.consumeStockedBatteries(cost);
    if (!consumed) return;
    await townProvider.buildChosen(type);
  }

  @override
  Widget build(BuildContext context) {
    final townProvider = context.watch<TownProvider>();
    final energyProvider = context.watch<EnergyProvider>();
    final pendingBatteries = energyProvider.pendingBatteries;
    final town = townProvider.town;
    final colorScheme = Theme.of(context).colorScheme;
    final level = town.townLevel;
    final stage = TownStages.forLevel(level);
    final nextStage = TownStages.next(level);
    final isFinalStage = TownStages.isAtFinalStage(level);
    final launches = TownStages.rocketLaunchCount(level);

    final buildingCounts = <BuildingType, int>{};
    for (final b in town.buildings) {
      buildingCounts[b.type] = (buildingCounts[b.type] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('町')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _TownGridMap(town: town),
          const SizedBox(height: 16),
          Center(
            child: Text(
              level == 0 ? stage.name : '${stage.name}（建物 $level 棟）',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  BatteryStockDisplay(count: pendingBatteries),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pendingBatteries == 0
                          ? '満タンの蓄電池はストックされていません'
                          : 'ストック: $pendingBatteries 個',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  FilledButton(
                    onPressed: pendingBatteries == 0 ? null : _useStock,
                    child: const Text('使う'),
                  ),
                ],
              ),
            ),
          ),
          if (isFinalStage) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                '🚀 ロケット発射回数: $launches',
                style: TextStyle(color: colorScheme.outline),
              ),
            ),
          ],
          if (nextStage != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (level - stage.minLevel) /
                    (nextStage.minLevel - stage.minLevel),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                '次は「${nextStage.name}」まであと ${nextStage.minLevel - level} 棟',
                style: TextStyle(fontSize: 12, color: colorScheme.outline),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  icon: Icons.groups,
                  label: '人口',
                  value: '${townProvider.population}人',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatChip(
                  icon: Icons.military_tech,
                  label: '文明スコア',
                  value: '${townProvider.civilizationScore}',
                ),
              ),
            ],
          ),
          if (buildingCounts.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('建設済みの建物', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: buildingCounts.entries.map((entry) {
                final def = BuildingDefinitions.of(entry.key);
                return Chip(
                  avatar: Icon(def.icon, size: 18),
                  label: Text('${def.displayName} ×${entry.value}'),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(icon, size: 18, color: colorScheme.onSecondaryContainer),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: colorScheme.outline)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// 町を上から見下ろした5x5グリッドマップ。建設済みの建物をマス目に配置して表示する。
class _TownGridMap extends StatelessWidget {
  final TownState town;

  const _TownGridMap({required this.town});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF7CB342),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(6),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: GameConstants.townGridSize,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: GameConstants.townGridSize * GameConstants.townGridSize,
          itemBuilder: (context, index) {
            final x = index % GameConstants.townGridSize;
            final y = index ~/ GameConstants.townGridSize;
            final building = town.buildingAt(x, y);
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF8FCE52),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: building == null
                  ? null
                  : Icon(
                      BuildingDefinitions.of(building.type).icon,
                      color: colorScheme.onSurface,
                    ),
            );
          },
        ),
      ),
    );
  }
}
