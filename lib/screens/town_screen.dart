import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/building_definitions.dart';
import '../constants/game_constants.dart';
import '../constants/town_atmosphere.dart';
import '../constants/town_stages.dart';
import '../domain/models/building.dart';
import '../domain/models/construction_event.dart';
import '../domain/models/town_state.dart';
import '../providers/energy_provider.dart';
import '../providers/town_provider.dart';
import '../widgets/battery_stock_display.dart';

class TownScreen extends StatefulWidget {
  final DateTime Function() now;

  const TownScreen({
    super.key,
    this.now = DateTime.now,
  });

  const TownScreen.withClock({
    super.key,
    required this.now,
  });

  @override
  State<TownScreen> createState() => _TownScreenState();
}

class _TownScreenState extends State<TownScreen> with TickerProviderStateMixin {
  late final AnimationController _constructionController;
  late final AnimationController _pulseController;
  Timer? _constructionClearTimer;
  DateTime? _lastHandledConstructionAt;
  ConstructionEvent? _activeConstruction;

  @override
  void initState() {
    super.initState();
    _constructionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCelebrations());
  }

  @override
  void dispose() {
    _constructionClearTimer?.cancel();
    _constructionController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _showCelebrations() async {
    final townProvider = context.read<TownProvider>();
    final stagePending = townProvider.pendingStageCelebrations;
    townProvider.clearPendingStageCelebrations();

    for (final stage in stagePending) {
      if (!mounted) return;
      final story = TownAtmosphere.stageStory(stage.id);
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          icon: Icon(TownAtmosphere.stageIcon(stage), size: 40, color: Colors.amber),
          title: Text(story.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                stage.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(story.description),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('つづきを歩く'),
            ),
          ],
        ),
      );
    }

    final pending = townProvider.pendingCelebrations;
    townProvider.clearPendingCelebrations();
    for (final achievement in pending) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          icon: Icon(achievement.icon, size: 40, color: Colors.amber),
          title: const Text('実績解除！'),
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

  Future<void> _handleConstructionEvent(ConstructionEvent event) async {
    setState(() => _activeConstruction = event);
    _constructionController
      ..reset()
      ..forward();
    _constructionClearTimer?.cancel();
    _constructionClearTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _activeConstruction = null);
    });

    await HapticFeedback.mediumImpact();
    if (!mounted) return;
    final def = BuildingDefinitions.of(event.type);
    final effectText = switch (event.type) {
      BuildingType.house => '人口 +${def.population}',
      BuildingType.powerPlant =>
        '蓄電池容量 +${BuildingDefinitions.powerPlantCapacityBonusWh.toStringAsFixed(0)} Wh',
      BuildingType.park => '発電効率 ×${BuildingDefinitions.parkCoefficientMultiplier}',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('${def.displayName}が完成しました（$effectText）'),
      ),
    );
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
    final placed = await townProvider.buildChosen(type);
    if (!placed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('空きマスがありません')),
      );
      return;
    }
    await _showCelebrations();
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
    final timeOfDay = TownAtmosphere.timeOfDay(widget.now());
    final palette = TownAtmosphere.paletteOf(timeOfDay);
    final pendingConstruction = townProvider.pendingConstructionEvent;
    if (pendingConstruction != null &&
        _lastHandledConstructionAt != pendingConstruction.createdAt) {
      _lastHandledConstructionAt = pendingConstruction.createdAt;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        townProvider.clearConstructionEvent();
        await _handleConstructionEvent(pendingConstruction);
      });
    }

    final buildingCounts = <BuildingType, int>{};
    for (final b in town.buildings) {
      buildingCounts[b.type] = (buildingCounts[b.type] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('町')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([
              _constructionController,
              _pulseController,
            ]),
            builder: (context, _) => _TownGridMap(
              town: town,
              skyColor: palette.skyColor,
              tileColor: palette.tileColor,
              timeOfDay: timeOfDay,
              isFinalStage: isFinalStage,
              constructionEvent: _activeConstruction,
              constructionScale: Tween<double>(begin: 0.3, end: 1.0)
                  .transform(Curves.elasticOut.transform(_constructionController.value)),
              pulseValue: _pulseController.value,
            ),
          ),
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
                      'ストック: $pendingBatteries 個',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 40),
                    ),
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
  final Color skyColor;
  final Color tileColor;
  final TownTimeOfDay timeOfDay;
  final bool isFinalStage;
  final ConstructionEvent? constructionEvent;
  final double constructionScale;
  final double pulseValue;

  const _TownGridMap({
    required this.town,
    required this.skyColor,
    required this.tileColor,
    required this.timeOfDay,
    required this.isFinalStage,
    required this.constructionEvent,
    required this.constructionScale,
    required this.pulseValue,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: skyColor,
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
            final isConstructedCell = constructionEvent != null &&
                constructionEvent!.x == x &&
                constructionEvent!.y == y;
            return Container(
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(6),
                border: isConstructedCell
                    ? Border.all(
                        color: Colors.amberAccent,
                        width: 2.0,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (building != null)
                    Center(
                      child: Transform.scale(
                        scale: isConstructedCell ? constructionScale : 1.0,
                        child: Opacity(
                          opacity: _iconOpacity(building),
                          child: Icon(
                            BuildingDefinitions.of(building.type).icon,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  if (building?.type == BuildingType.house &&
                      (timeOfDay == TownTimeOfDay.night ||
                          timeOfDay == TownTimeOfDay.evening))
                    const Positioned(
                      right: 6,
                      top: 6,
                      child: Icon(Icons.light_mode, size: 10, color: Color(0xFFFFF176)),
                    ),
                  if (building?.type == BuildingType.park &&
                      timeOfDay == TownTimeOfDay.night)
                    const Positioned(
                      left: 5,
                      bottom: 5,
                      child: Icon(Icons.circle, size: 7, color: Color(0xFFFFF59D)),
                    ),
                  if (isFinalStage && building?.type == BuildingType.powerPlant)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Opacity(
                        opacity: 0.35 + (0.65 * pulseValue),
                        child: const Icon(Icons.circle, size: 8, color: Colors.redAccent),
                      ),
                    ),
                  if (isConstructedCell)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _SparkleOverlay(progress: pulseValue),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  double _iconOpacity(Building building) {
    if (building.type == BuildingType.powerPlant) {
      return 0.65 + 0.35 * pulseValue;
    }
    return 1.0;
  }
}

class _SparkleOverlay extends StatelessWidget {
  final double progress;

  const _SparkleOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    final twinkle = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(progress * math.pi * 2));
    return Stack(
      children: [
        Positioned(
          top: 4,
          left: 10,
          child: Opacity(
            opacity: twinkle,
            child: const Icon(Icons.auto_awesome, size: 10, color: Colors.yellowAccent),
          ),
        ),
        Positioned(
          right: 6,
          top: 12,
          child: Opacity(
            opacity: twinkle * 0.85,
            child: const Icon(Icons.auto_awesome, size: 9, color: Colors.white),
          ),
        ),
        Positioned(
          left: 8,
          bottom: 6,
          child: Opacity(
            opacity: twinkle * 0.75,
            child: const Icon(Icons.auto_awesome, size: 8, color: Colors.amber),
          ),
        ),
      ],
    );
  }
}
