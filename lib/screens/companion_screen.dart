import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/companion_stages.dart';
import '../domain/companion_logic.dart';
import '../domain/models/feed_event.dart';
import '../providers/companion_provider.dart';
import '../providers/energy_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/battery_stock_display.dart';
import '../widgets/companion/companion_avatar.dart';

class CompanionScreen extends StatefulWidget {
  const CompanionScreen({super.key});

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
  bool _investing = false;

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
      await _showCelebrationDialog(
        stage: stage,
        title: '灯りが広がった',
        heading: '地球が少し明るくなった',
        description: '歩いて集めたエネルギーが、夜の地球に灯りをともした。',
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
                  interactive: false,
                  autoSpin: false,
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        content: Text('電力を投入した（発展度 +1）'),
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

  /// ストック電池1個を投入してまちを1段階発展させる。
  /// ストック消費と発展更新は [CompanionProvider.investBattery] 内で
  /// 呼び出し側から見て単一の操作としてまとめられており、連打しても
  /// ストック数以上には投入できない。
  Future<void> _investBattery() async {
    if (_investing) return;
    setState(() => _investing = true);
    try {
      final companionProvider = context.read<CompanionProvider>();
      final invested = await companionProvider.investBattery();
      if (invested) {
        await _showCelebrations();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投入に失敗しました。もう一度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _investing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final companionProvider = context.watch<CompanionProvider>();
    final energyProvider = context.watch<EnergyProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final pendingBatteries = energyProvider.pendingBatteries;
    final companion = companionProvider.companion;
    final level = companion.level;
    final stage = CompanionStages.forLevel(level);
    final nextStage = CompanionStages.next(level);
    final companionName = settingsProvider.settings.companionName.trim();
    final displayName = companionName.isEmpty ? 'わたしのまち' : companionName;
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
                stage: stage,
                mood: companionProvider.mood,
                developmentLevel: level,
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
            child: Text(
              '累積発電量 ${energyProvider.lifetimeEnergyWh.toStringAsFixed(1)} Wh',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
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
                      onPressed: pendingBatteries == 0 || _investing
                          ? null
                          : _investBattery,
                      child: const Text('投入'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (nextStage != null)
              _NextMilestoneCard(
                remaining: nextStage.minLevel - level,
                progress: (level - stage.minLevel) /
                    (nextStage.minLevel - stage.minLevel),
              )
            else
              const _NextMilestoneCard.postRocket(),
          ],
        ],
      ),
    );
  }
}

class _NextMilestoneCard extends StatelessWidget {
  final int remaining;
  final double progress;
  final bool postRocket;

  const _NextMilestoneCard({
    required this.remaining,
    required this.progress,
  }) : postRocket = false;

  const _NextMilestoneCard.postRocket()
      : remaining = 1,
        progress = 0,
        postRocket = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (postRocket) {
      return Card(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '次の投入で',
                style: TextStyle(fontSize: 13, color: colorScheme.outline),
              ),
              const SizedBox(height: 4),
              const Text(
                '地球の灯りがさらに広がる',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
              'あと $remaining 回投入すると灯りが広がる',
              style: TextStyle(fontSize: 13, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 夜の地球ビュー（宇宙背景＋衛星写真の灯り）。
class _CompanionStage extends StatelessWidget {
  final CompanionStage stage;
  final CompanionMood mood;
  final int developmentLevel;
  final double idleValue;
  final double feedScale;
  final bool showPatHeart;
  final double patValue;
  final VoidCallback onTap;

  const _CompanionStage({
    required this.stage,
    required this.mood,
    required this.developmentLevel,
    required this.idleValue,
    required this.feedScale,
    required this.showPatHeart,
    required this.patValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF000000),
              Color(0xFF050814),
              Color(0xFF0A1020),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 遠い星
            Positioned.fill(
              child: CustomPaint(
                painter: _StarfieldPainter(seed: developmentLevel),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Transform.scale(
                scale: feedScale,
                child: CompanionAvatar(
                  stage: stage,
                  mood: mood,
                  size: 250,
                  idleValue: idleValue,
                  developmentLevel: developmentLevel,
                  onTap: onTap,
                  autoSpin: true,
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
          ],
        ),
      ),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  final int seed;

  _StarfieldPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed + 17);
    final paint = Paint()..color = const Color(0x66FFFFFF);
    for (var i = 0; i < 56; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = 0.35 + rnd.nextDouble() * 1.0;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) =>
      oldDelegate.seed != seed;
}
