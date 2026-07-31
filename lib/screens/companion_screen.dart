import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/companion_atmosphere.dart';
import '../constants/companion_stages.dart';
import '../constants/feed_item_definitions.dart';
import '../domain/companion_logic.dart';
import '../domain/models/feed_event.dart';
import '../domain/models/feed_item_type.dart';
import '../providers/companion_provider.dart';
import '../providers/energy_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/battery_stock_display.dart';
import '../widgets/companion/companion_weather_overlay.dart';

class CompanionScreen extends StatefulWidget {
  final DateTime Function() now;

  const CompanionScreen({
    super.key,
    this.now = DateTime.now,
  });

  const CompanionScreen.withClock({
    super.key,
    required this.now,
  });

  @override
  State<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends State<CompanionScreen> with TickerProviderStateMixin {
  late final AnimationController _idleController;
  late final AnimationController _feedController;
  late final AnimationController _patController;
  Timer? _feedClearTimer;
  DateTime? _lastHandledFeedAt;
  FeedEvent? _activeFeedEvent;
  bool _showPatHeart = false;
  bool _screenshotMode = false;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _feedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _patController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCelebrations());
  }

  @override
  void dispose() {
    _feedClearTimer?.cancel();
    _idleController.dispose();
    _feedController.dispose();
    _patController.dispose();
    super.dispose();
  }

  Future<void> _showCelebrations() async {
    final companionProvider = context.read<CompanionProvider>();
    final stagePending = companionProvider.pendingStageCelebrations;
    companionProvider.clearPendingStageCelebrations();

    for (final stage in stagePending) {
      if (!mounted) return;
      final story = CompanionAtmosphere.stageStory(stage.id);
      await _showCelebrationDialog(
        icon: CompanionAtmosphere.stageIcon(stage),
        title: story.title,
        heading: stage.name,
        description: story.description,
        buttonLabel: 'つづきを歩く',
      );
    }

    final pending = companionProvider.pendingCelebrations;
    companionProvider.clearPendingCelebrations();
    for (final achievement in pending) {
      if (!mounted) return;
      await _showCelebrationDialog(
        icon: achievement.icon,
        title: '実績解除！',
        heading: achievement.title,
        description: achievement.description,
        buttonLabel: 'やったね',
      );
    }
  }

  /// 進化段階・実績どちらの祝福ダイアログにも使う共通のレイアウト。
  Future<void> _showCelebrationDialog({
    required IconData icon,
    required String title,
    required String heading,
    required String description,
    required String buttonLabel,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(icon, size: 40, color: Colors.amber),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              heading,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(description),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _handleFeedEvent(FeedEvent event) async {
    setState(() => _activeFeedEvent = event);
    _feedController
      ..reset()
      ..forward();
    _feedClearTimer?.cancel();
    _feedClearTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _activeFeedEvent = null);
    });

    await HapticFeedback.mediumImpact();
    if (!mounted) return;
    final def = FeedItemDefinitions.of(event.type);
    final effectText = switch (event.type) {
      FeedItemType.meal => 'なつき度 +1',
      FeedItemType.booster =>
        '蓄電池容量 +${FeedItemDefinitions.boosterCapacityBonusWh.toStringAsFixed(0)} Wh',
      FeedItemType.toy => '発電効率 ×${FeedItemDefinitions.toyCoefficientMultiplier}',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('${def.displayName}をあげました（$effectText）'),
      ),
    );
  }

  Future<void> _pat() async {
    await HapticFeedback.lightImpact();
    setState(() => _showPatHeart = true);
    _patController
      ..reset()
      ..forward();
    Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _showPatHeart = false);
    });
  }

  Future<void> _feedFromStock() async {
    final energyProvider = context.read<EnergyProvider>();
    final companionProvider = context.read<CompanionProvider>();
    final stock = energyProvider.pendingBatteries;

    final type = await showModalBottomSheet<FeedItemType>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'あげるごはんを選んでください',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            for (final type in FeedItemType.values)
              Builder(
                builder: (context) {
                  final def = FeedItemDefinitions.of(type);
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

    final cost = FeedItemDefinitions.of(type).batteryCost;
    final consumed = await energyProvider.consumeStockedBatteries(cost);
    if (!consumed) return;
    await companionProvider.feedChosen(type);
    await _showCelebrations();
  }

  String _moodLabel(CompanionMood mood) {
    switch (mood) {
      case CompanionMood.none:
        return 'まだ生まれていない';
      case CompanionMood.happy:
        return 'ごきげん';
      case CompanionMood.normal:
        return 'ふつう';
      case CompanionMood.lonely:
        return 'さみしそう';
    }
  }

  @override
  Widget build(BuildContext context) {
    final companionProvider = context.watch<CompanionProvider>();
    final energyProvider = context.watch<EnergyProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final pendingBatteries = energyProvider.pendingBatteries;
    final companion = companionProvider.companion;
    final colorScheme = Theme.of(context).colorScheme;
    final level = companion.level;
    final stage = CompanionStages.forLevel(level);
    final nextStage = CompanionStages.next(level);
    final isFinalStage = CompanionStages.isAtFinalStage(level);
    final sparkles = CompanionStages.sparkleCount(level);
    final now = widget.now();
    final timeOfDay = CompanionAtmosphere.timeOfDay(now);
    final weather = CompanionAtmosphere.weatherOf(now);
    final season = CompanionAtmosphere.seasonOf(now);
    final palette = CompanionAtmosphere.applyWeatherAndSeason(
      CompanionAtmosphere.paletteOf(timeOfDay),
      weather: weather,
      season: season,
    );
    final companionName = settingsProvider.settings.companionName.trim();
    final displayName = companionName.isEmpty ? 'あいぼう' : companionName;
    final weatherFxEnabled = settingsProvider.settings.companionWeatherFxEnabled;
    final firstSparkleDate = companionProvider.firstSparkleDate;
    final pendingFeed = companionProvider.pendingFeedEvent;
    if (pendingFeed != null && _lastHandledFeedAt != pendingFeed.createdAt) {
      _lastHandledFeedAt = pendingFeed.createdAt;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        companionProvider.clearFeedEvent();
        await _handleFeedEvent(pendingFeed);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        actions: [
          IconButton(
            tooltip: 'スクリーンショットモード',
            onPressed: () {
              setState(() => _screenshotMode = !_screenshotMode);
            },
            icon: Icon(
              _screenshotMode ? Icons.visibility_off : Icons.photo_camera,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_idleController, _feedController, _patController]),
            builder: (context, _) => _CompanionStage(
              skyColor: palette.skyColor,
              stage: stage,
              isFinalStage: isFinalStage,
              weather: weather,
              season: season,
              weatherFxEnabled: weatherFxEnabled,
              idleValue: _idleController.value,
              feedScale: _activeFeedEvent == null
                  ? 1.0
                  : Tween<double>(begin: 0.6, end: 1.0)
                      .transform(Curves.elasticOut.transform(_feedController.value)),
              showPatHeart: _showPatHeart,
              patValue: _patController.value,
              onTap: _pat,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  displayName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  level == 0 ? stage.name : '${stage.name}（なつき度 $level）',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _moodLabel(companionProvider.mood),
                  style: TextStyle(color: colorScheme.outline),
                ),
              ],
            ),
          ),
          if (!_screenshotMode && firstSparkleDate != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Chip(
                avatar: const Icon(Icons.auto_awesome, size: 18),
                label: Text('初きらめき: $firstSparkleDate'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (!_screenshotMode) ...[
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
                      onPressed: pendingBatteries == 0 ? null : _feedFromStock,
                      child: const Text('あげる'),
                    ),
                  ],
                ),
              ),
            ),
            if (isFinalStage) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '✨ きらめきタイム回数: $sparkles',
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
                  '次は「${nextStage.name}」まであと ${nextStage.minLevel - level} 回',
                  style: TextStyle(fontSize: 12, color: colorScheme.outline),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _StatChip(
              icon: Icons.favorite,
              label: '愛着スコア',
              value: '${companionProvider.bondScore}',
            ),
            const SizedBox(height: 24),
            Text('あげたごはん', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FeedItemType.values.map((type) {
                final def = FeedItemDefinitions.of(type);
                return Chip(
                  avatar: Icon(def.icon, size: 18),
                  label: Text('${def.displayName} ×${companion.countOf(type)}'),
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
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(icon, size: 18, color: colorScheme.onSecondaryContainer),
            ),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: colorScheme.outline)),
            const Spacer(),
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

/// 相棒本体の表示エリア（背景の時間帯・天気演出＋中央の相棒アイコン）。
class _CompanionStage extends StatelessWidget {
  final Color skyColor;
  final CompanionStage stage;
  final bool isFinalStage;
  final CompanionWeather weather;
  final CompanionSeason season;
  final bool weatherFxEnabled;
  final double idleValue;
  final double feedScale;
  final bool showPatHeart;
  final double patValue;
  final VoidCallback onTap;

  const _CompanionStage({
    required this.skyColor,
    required this.stage,
    required this.isFinalStage,
    required this.weather,
    required this.season,
    required this.weatherFxEnabled,
    required this.idleValue,
    required this.feedScale,
    required this.showPatHeart,
    required this.patValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bounce = math.sin(idleValue * math.pi) * 6;
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: skyColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: Offset(0, -bounce),
                child: Transform.scale(
                  scale: feedScale,
                  child: Icon(
                    CompanionAtmosphere.stageIcon(stage),
                    size: 96,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (isFinalStage)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Opacity(
                    opacity: 0.4 + 0.6 * (0.5 + 0.5 * math.sin(idleValue * math.pi * 2)),
                    child: const Icon(Icons.auto_awesome, size: 20, color: Colors.amber),
                  ),
                ),
              if (showPatHeart)
                Positioned(
                  top: 24,
                  child: Opacity(
                    opacity: 1.0 - patValue,
                    child: Transform.translate(
                      offset: Offset(0, -20 * patValue),
                      child: const Icon(Icons.favorite, color: Colors.pinkAccent, size: 28),
                    ),
                  ),
                ),
              if (weatherFxEnabled)
                Positioned.fill(
                  child: CompanionWeatherOverlay(
                    weather: weather,
                    season: season,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
