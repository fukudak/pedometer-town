import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/building_definitions.dart';
import '../constants/game_constants.dart';
import '../constants/town_stages.dart';
import '../domain/models/building.dart';
import '../providers/town_provider.dart';

class TownScreen extends StatefulWidget {
  const TownScreen({super.key});

  @override
  State<TownScreen> createState() => _TownScreenState();
}

class _TownScreenState extends State<TownScreen> {
  BuildingType? _selectedType;

  Future<void> _pickBuildingType(TownProvider townProvider) async {
    final type = await showModalBottomSheet<BuildingType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _BuildPickerSheet(townProvider: townProvider),
    );
    if (type == null || !mounted) return;
    setState(() => _selectedType = type);
  }

  void _cancelPlacement() {
    setState(() => _selectedType = null);
  }

  Future<void> _onTileTap(TownProvider townProvider, int x, int y) async {
    final building = townProvider.town.buildingAt(x, y);
    if (building != null) {
      _showBuildingInfo(building);
      return;
    }

    final type = _selectedType;
    if (type == null) return;

    final ok = await townProvider.buildBuilding(type, x, y);
    if (!mounted) return;
    if (ok) {
      setState(() => _selectedType = null);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('エネルギーが不足しています')),
      );
    }
  }

  void _showBuildingInfo(Building building) {
    final def = BuildingDefinitions.of(building.type);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(def.icon),
        title: Text(def.displayName),
        content: Text('座標: (${building.x}, ${building.y})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final townProvider = context.watch<TownProvider>();
    final town = townProvider.town;
    final colorScheme = Theme.of(context).colorScheme;
    const gridSize = GameConstants.townGridSize;
    final selectedType = _selectedType;
    final level = town.townLevel;
    final stage = TownStages.forLevel(level);
    final nextStage = TownStages.next(level);

    return Scaffold(
      appBar: AppBar(title: const Text('町')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            color: colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(stage.icon, color: colorScheme.onTertiaryContainer),
                      const SizedBox(width: 12),
                      Text(
                        '${stage.name}（建物 $level 棟）',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                  if (nextStage != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (level - stage.minLevel) /
                            (nextStage.minLevel - stage.minLevel),
                        backgroundColor: colorScheme.surface,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '次は「${nextStage.name}」まであと '
                      '${nextStage.minLevel - level} 棟',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (selectedType == null)
            FilledButton.icon(
              onPressed: () => _pickBuildingType(townProvider),
              icon: const Icon(Icons.add_business),
              label: const Text('建物を建てる'),
            )
          else
            Card(
              color: colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(BuildingDefinitions.of(selectedType).icon,
                        color: colorScheme.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${BuildingDefinitions.of(selectedType).displayName} を配置する場所をタップ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _cancelPlacement,
                      child: const Text('キャンセル'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            '草原',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8BC34A),
                borderRadius: BorderRadius.circular(24),
              ),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridSize,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: gridSize * gridSize,
                itemBuilder: (context, index) {
                  final x = index % gridSize;
                  final y = index ~/ gridSize;
                  final building = town.buildingAt(x, y);
                  return _GrassTile(
                    key: ValueKey('tile_${x}_$y'),
                    building: building,
                    placementActive: selectedType != null && building == null,
                    onTap: () => _onTileTap(townProvider, x, y),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrassTile extends StatefulWidget {
  final Building? building;
  final bool placementActive;
  final VoidCallback onTap;

  const _GrassTile({
    required super.key,
    required this.building,
    required this.placementActive,
    required this.onTap,
  });

  @override
  State<_GrassTile> createState() => _GrassTileState();
}

class _GrassTileState extends State<_GrassTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      // すでに建設済みの状態で画面を開いた場合はアニメーションせず即表示する。
      value: widget.building != null ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(_GrassTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 空きマス→建設済みに変わった瞬間だけ「建つ」アニメーションを再生する。
    if (oldWidget.building == null && widget.building != null) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: widget.placementActive
              ? const Color(0xFFC8E6A0)
              : const Color(0xFFA5D86E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.placementActive
                ? colorScheme.primary
                : const Color(0xFF7CB342),
            width: widget.placementActive ? 2 : 1,
          ),
        ),
        child: widget.building == null
            ? null
            : Center(
                child: ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _controller,
                    curve: Curves.elasticOut,
                  ),
                  child: Icon(
                    BuildingDefinitions.of(widget.building!.type).icon,
                    color: colorScheme.primary,
                  ),
                ),
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
