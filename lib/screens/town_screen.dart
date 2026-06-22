import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/building_definitions.dart';
import '../constants/town_stages.dart';
import '../domain/models/building.dart';
import '../providers/town_provider.dart';

class TownScreen extends StatefulWidget {
  const TownScreen({super.key});

  @override
  State<TownScreen> createState() => _TownScreenState();
}

class _TownScreenState extends State<TownScreen> {
  Future<void> _build(TownProvider townProvider, BuildingType type) async {
    final pos = townProvider.nextAvailablePosition();
    if (pos == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('これ以上建物を建てられません')),
      );
      return;
    }

    final ok = await townProvider.buildBuilding(type, pos.x, pos.y);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('エネルギーが不足しています')),
      );
    }
  }

  Future<void> _pickBuildingType(TownProvider townProvider) async {
    final type = await showModalBottomSheet<BuildingType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _BuildPickerSheet(townProvider: townProvider),
    );
    if (type == null || !mounted) return;
    await _build(townProvider, type);
  }

  @override
  Widget build(BuildContext context) {
    final townProvider = context.watch<TownProvider>();
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
          _HorizonScene(
            stage: stage,
            launches: launches,
            isFinalStage: isFinalStage,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '${stage.name}（建物 $level 棟）',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
          const SizedBox(height: 24),
          if (buildingCounts.isNotEmpty) ...[
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
            const SizedBox(height: 24),
          ],
          FilledButton.icon(
            onPressed: () => _pickBuildingType(townProvider),
            icon: const Icon(Icons.add_business),
            label: const Text('建物を建てる'),
          ),
        ],
      ),
    );
  }
}

/// 街の発展段階を表す地平線シーン。
/// 発展段階が変わるとアイコンがバウンドして切り替わり、
/// ロケット建造段階では発射回数が増えるたびにロケットが飛んでいくアニメーションを再生する。
class _HorizonScene extends StatefulWidget {
  final TownStage stage;
  final int launches;
  final bool isFinalStage;

  const _HorizonScene({
    required this.stage,
    required this.launches,
    required this.isFinalStage,
  });

  @override
  State<_HorizonScene> createState() => _HorizonSceneState();
}

class _HorizonSceneState extends State<_HorizonScene>
    with TickerProviderStateMixin {
  late AnimationController _stageController;
  late AnimationController _launchController;

  @override
  void initState() {
    super.initState();
    _stageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 1.0,
    );
    _launchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didUpdateWidget(_HorizonScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage.name != widget.stage.name) {
      _stageController.forward(from: 0.0);
    }
    if (widget.launches > oldWidget.launches) {
      _launchController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _stageController.dispose();
    _launchController.dispose();
    super.dispose();
  }

  List<Color> _skyColorsFor(TownStage stage) {
    switch (stage.name) {
      case 'たき火':
        return const [Color(0xFF2C1B47), Color(0xFFAA5A3C)];
      case '小さな家':
      case '大きな家':
        return const [Color(0xFF6EC6FF), Color(0xFFBBDEFB)];
      case '工場':
      case '発電所':
        return const [Color(0xFF607D8B), Color(0xFFCFD8DC)];
      default:
        return const [Color(0xFF0D1B2A), Color(0xFF1B263B)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final skyColors = _skyColorsFor(widget.stage);

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: skyColors,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.26,
                widthFactor: 1.0,
                child: Container(color: const Color(0xFF4E342E)),
              ),
            ),
            Center(
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _stageController,
                  curve: Curves.elasticOut,
                ),
                child: Icon(
                  widget.stage.icon,
                  size: 88,
                  color: Colors.white,
                ),
              ),
            ),
            if (widget.isFinalStage)
              AnimatedBuilder(
                animation: _launchController,
                builder: (context, child) {
                  final t = _launchController.value;
                  return Positioned(
                    bottom: 36 + t * 160,
                    right: 36,
                    child: Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: const Icon(
                        Icons.rocket_launch,
                        color: Colors.orangeAccent,
                        size: 28,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _BuildPickerSheet extends StatelessWidget {
  final TownProvider townProvider;

  const _BuildPickerSheet({required this.townProvider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('建てる建物を選択', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...BuildingType.values.map((type) {
              final def = BuildingDefinitions.of(type);
              final affordable = townProvider.canAfford(type);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child:
                        Icon(def.icon, color: colorScheme.onPrimaryContainer),
                  ),
                  title: Text(def.displayName),
                  subtitle: Text('コスト: ${def.costWh.toStringAsFixed(0)} Wh'),
                  enabled: affordable,
                  onTap: affordable
                      ? () => Navigator.of(context).pop(type)
                      : null,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
