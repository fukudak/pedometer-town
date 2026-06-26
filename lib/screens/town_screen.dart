import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/building_definitions.dart';
import '../constants/town_stages.dart';
import '../domain/models/building.dart';
import '../providers/energy_provider.dart';
import '../providers/town_provider.dart';

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
          _HorizonScene(
            stage: stage,
            launches: launches,
            isFinalStage: isFinalStage,
            houseCount: buildingCounts[BuildingType.house] ?? 0,
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
                  Icon(Icons.battery_charging_full, color: colorScheme.primary),
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
                    onPressed: pendingBatteries == 0
                        ? null
                        : () => energyProvider.useStockedBatteries(),
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

/// 街の発展段階を表す地平線シーン。
/// 発展段階が変わるとアイコンがバウンドして切り替わり、
/// ロケット建設段階では発射回数が増えるたびにロケットが飛んでいくアニメーションを再生する。
/// 空の色は発展段階に加えて、実際の時刻（朝・昼・夕・夜）でも変化する。
class _HorizonScene extends StatefulWidget {
  final TownStage stage;
  final int launches;
  final bool isFinalStage;
  final int houseCount;

  const _HorizonScene({
    required this.stage,
    required this.launches,
    required this.isFinalStage,
    required this.houseCount,
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
      case '何もない地平線':
        return const [Color(0xFFE0E0E0), Color(0xFFF5F5F0)];
      case '豆電球がつく':
        return const [Color(0xFF1A1330), Color(0xFF3D2C52)];
      case '電灯がつく':
        return const [Color(0xFF2C1B47), Color(0xFFAA5A3C)];
      case '家の明かりが付く':
        return const [Color(0xFF6EC6FF), Color(0xFFBBDEFB)];
      case '工場が稼働する':
        return const [Color(0xFF607D8B), Color(0xFFCFD8DC)];
      case '街が広がる':
        return const [Color(0xFF4FA8E0), Color(0xFFA9D6F5)];
      case '都市になる':
        return const [Color(0xFF26415C), Color(0xFF4E7A9E)];
      default:
        return const [Color(0xFF0D1B2A), Color(0xFF1B263B)];
    }
  }

  /// 実際の時刻に応じた重ね色（昼間は重ねない）。
  Color? _timeOverlayColor() {
    final hour = DateTime.now().hour;
    if (hour >= 22 || hour < 5) {
      return Colors.black.withValues(alpha: 0.35); // 深夜
    }
    if ((hour >= 5 && hour < 7) || (hour >= 17 && hour < 19)) {
      return Colors.deepOrange.withValues(alpha: 0.18); // 朝焼け・夕焼け
    }
    return null; // 日中はそのまま
  }

  @override
  Widget build(BuildContext context) {
    final skyColors = _skyColorsFor(widget.stage);
    final overlayColor = _timeOverlayColor();
    final icon = widget.stage.icon;

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
            if (widget.houseCount > 0)
              Align(
                alignment: const Alignment(0, 0.65),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    children: List.generate(
                      widget.houseCount,
                      (_) => const Icon(
                        Icons.house,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            if (icon != null)
              Center(
                child: ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _stageController,
                    curve: Curves.elasticOut,
                  ),
                  child: Icon(
                    icon,
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
            if (overlayColor != null)
              IgnorePointer(
                child: Container(color: overlayColor),
              ),
          ],
        ),
      ),
    );
  }
}
