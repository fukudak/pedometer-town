import 'dart:async';

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
import '../widgets/companion/companion_avatar.dart';
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
        stage: stage,
        title: story.title,
        heading: stage.name,
        description: story.description,
        buttonLabel: 'もっと歩く',
      );
    }

    final pending = companionProvider.pendingCelebrations;
    companionProvider.clearPendingCelebrations();
    for (final achievement in pending) {
      if (!mounted) return;
      await _showCelebrationDialog(
        achievementIcon: achievement.icon,
        title: '実績解除！',
        heading: achievement.title,
        description: achievement.description,
        buttonLabel: 'やったね',
      );
    }
  }

  /// 進化段階・実績どちらの祝福ダイアログにも使う共通のレイアウト。
  Future<void> _showCelebrationDialog({
    CompanionStage? stage,
    IconData? achievementIcon,
    required String title,
    required String heading,
    required String description,
    required String buttonLabel,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: stage != null
            ? SizedBox(
                width: 72,
                height: 72,
                child: CompanionAvatar(
                  stage: stage,
                  mood: CompanionMood.happy,
                  size: 72,
                ),
              )
            : Icon(achievementIcon ?? Icons.emoji_events, size: 40, color: Colors.amber),
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
      FeedItemType.meal => '発展度 +1',
      FeedItemType.booster =>
        '蓄電池容量 +${FeedItemDefinitions.boosterCapacityBonusWh.toStringAsFixed(0)} Wh',
      FeedItemType.toy => '発電効率 ×${FeedItemDefinitions.toyCoefficientMultiplier}',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('${def.displayName}を使った（$effectText）'),
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
                'まちに使うアイテムを選んでください',
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
        return 'お休み中';
      case CompanionMood.happy:
        return '元気に稼働中';
      case CompanionMood.normal:
        return 'ふつう';
      case CompanionMood.lonely:
        return '電力が足りない…';
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
    final displayName = companionName.isEmpty ? 'わたしのまち' : companionName;
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
            animation: Listenable.merge([
              _idleController,
              _feedController,
              _patController,
            ]),
            builder: (context, _) {
              return _CompanionStage(
                skyColor: palette.skyColor,
                stage: stage,
                mood: companionProvider.mood,
                isFinalStage: isFinalStage,
                developmentLevel: level,
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
              );
            },
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
                  level == 0 ? stage.name : '${stage.name}（発展度 $level）',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _moodLabel(companionProvider.mood),
                  style: TextStyle(color: colorScheme.outline),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.apartment, size: 18),
                      label: Text('建物 ${TownStats.buildingCount(level)} 棟'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.groups, size: 18),
                      label: Text('人口 ${TownStats.population(level)} 人'),
                    ),
                  ],
                ),
                if (isFinalStage) ...[
                  const SizedBox(height: 6),
                  Text(
                    CompanionStages.postRocketGrowth(level) == 0
                        ? 'ロケット到達！これからは建物と人口が増えていく'
                        : '拡大中（+${CompanionStages.postRocketGrowth(level)}）',
                    style: TextStyle(fontSize: 12, color: colorScheme.outline),
                  ),
                ],
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
                      child: const Text('建設'),
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
              const SizedBox(height: 12),
              _NextMilestoneCard.postRocket(
                nextBuildings: TownStats.buildingCount(level + 1),
                nextPopulation: TownStats.population(level + 1),
                currentBuildings: TownStats.buildingCount(level),
                currentPopulation: TownStats.population(level),
              ),
            ],
            if (nextStage != null) ...[
              const SizedBox(height: 16),
              _NextMilestoneCard(
                remaining: nextStage.minLevel - level,
                nextName: nextStage.name,
                hint: CompanionStages.nextMilestone(level)!.hint,
                nextBuildings: TownStats.buildingCount(nextStage.minLevel),
                nextPopulation: TownStats.population(nextStage.minLevel),
                progress: (level - stage.minLevel) /
                    (nextStage.minLevel - stage.minLevel),
              ),
            ],
            const SizedBox(height: 16),
            _StatChip(
              icon: Icons.location_city,
              label: 'まちスコア',
              value: '${companionProvider.bondScore}',
            ),
            const SizedBox(height: 24),
            Text('使った建設', style: Theme.of(context).textTheme.titleMedium),
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

class _NextMilestoneCard extends StatelessWidget {
  final int remaining;
  final String nextName;
  final String hint;
  final int nextBuildings;
  final int nextPopulation;
  final double progress;
  final bool postRocket;
  final int? currentBuildings;
  final int? currentPopulation;

  const _NextMilestoneCard({
    required this.remaining,
    required this.nextName,
    required this.hint,
    required this.nextBuildings,
    required this.nextPopulation,
    required this.progress,
  })  : postRocket = false,
        currentBuildings = null,
        currentPopulation = null;

  const _NextMilestoneCard.postRocket({
    required this.nextBuildings,
    required this.nextPopulation,
    required this.currentBuildings,
    required this.currentPopulation,
  })  : remaining = 1,
        nextName = '',
        hint = '',
        progress = 0,
        postRocket = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (postRocket) {
      final bGain = nextBuildings - (currentBuildings ?? 0);
      final pGain = nextPopulation - (currentPopulation ?? 0);
      return Card(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '次の建設で',
                style: TextStyle(fontSize: 13, color: colorScheme.outline),
              ),
              const SizedBox(height: 4),
              Text(
                '建物 +$bGain 棟 ／ 人口 +$pGain 人',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '→ 建物 $nextBuildings 棟・人口 $nextPopulation 人',
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'あと $remaining 回建設すると',
              style: TextStyle(fontSize: 13, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 4),
            Text(
              nextName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '到達時: 建物 $nextBuildings 棟・人口 $nextPopulation 人',
              style: TextStyle(fontSize: 12, color: colorScheme.outline),
            ),
          ],
        ),
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

/// まちの正面ビュー（時間帯・天気＋スカイライン）。
class _CompanionStage extends StatelessWidget {
  final Color skyColor;
  final CompanionStage stage;
  final CompanionMood mood;
  final bool isFinalStage;
  final int developmentLevel;
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
    required this.mood,
    required this.isFinalStage,
    required this.developmentLevel,
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
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                skyColor,
                Color.lerp(skyColor, const Color(0xFFFFF8E1), 0.35)!,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                left: 24,
                right: 24,
                bottom: 28,
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Transform.scale(
                  scale: feedScale,
                child: CompanionAvatar(
                    stage: stage,
                    mood: mood,
                    size: 220,
                    idleValue: idleValue,
                    showSparkles: isFinalStage,
                    developmentLevel: developmentLevel,
                  ),
                ),
              ),
              if (showPatHeart)
                Align(
                  alignment: Alignment.center,
                  child: Transform.translate(
                    offset: Offset(0, -50 - 28 * patValue),
                    child: Opacity(
                      opacity: 1.0 - patValue,
                      child: Transform.scale(
                        scale: 0.8 + 0.4 * (1 - patValue),
                        child: const Icon(
                          Icons.favorite,
                          color: Color(0xFFFF8A80),
                          size: 34,
                        ),
                      ),
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
