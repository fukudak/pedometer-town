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
  Timer? _feedClearTimer;
  DateTime? _lastHandledFeedAt;
  FeedEvent? _activeFeedEvent;
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCelebrations());
  }

  @override
  void dispose() {
    _feedClearTimer?.cancel();
    _idleController.dispose();
    _feedController.dispose();
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
        heading: '星が少し明るくなった',
        description: '歩いて集めたエネルギーが、夜の星に灯りをともした。',
        buttonLabel: 'もっと歩く',
      );
    }

    final starCompletions = companionProvider.pendingStarCompletions;
    companionProvider.clearPendingStarCompletions();
    for (final starCount in starCompletions) {
      if (!mounted) return;
      await HapticFeedback.heavyImpact();
      if (!mounted) return;
      await _showCelebrationDialog(
        achievementIcon: Icons.auto_awesome,
        title: '星が完成した！',
        heading: '完成した星 $starCount 個',
        description: '歩いて集めたエネルギーが、ひとつの星を灯し切った。\nまた新しい星が生まれ、灯りが広がっていく。',
        buttonLabel: 'つづける',
        celebratory: true,
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

  /// 進化段階・実績・星の完成、どの祝福ダイアログにも使う共通のレイアウト。
  /// [celebratory] が true のときは星の完成専用の演出（紙吹雪＋強調表示）を出す。
  Future<void> _showCelebrationDialog({
    CompanionStage? stage,
    IconData? achievementIcon,
    required String title,
    required String heading,
    required String description,
    required String buttonLabel,
    bool celebratory = false,
  }) {
    final icon = stage != null
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
        : Icon(
            achievementIcon ?? Icons.emoji_events,
            size: celebratory ? 48 : 40,
            color: Colors.amber,
          );

    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: celebratory
            ? SizedBox(
                width: double.infinity,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned.fill(child: _ConfettiBurst()),
                    icon,
                  ],
                ),
              )
            : icon,
        title: Text(
          title,
          style: celebratory
              ? const TextStyle(color: Color(0xFFFFA000), fontWeight: FontWeight.w800)
              : null,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              heading,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(description, textAlign: TextAlign.center),
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

  /// ストック電池1個を投入して星を1段階発展させる。
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
    final displayName = companionName.isEmpty ? 'わたしの星' : companionName;
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([
              _idleController,
              _feedController,
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
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  stage.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '発展度 $level',
                  style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '累積発電量 ${energyProvider.lifetimeEnergyWh.toStringAsFixed(1)} Wh',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
            _EarthStockCard(
              earthCount: CompanionStages.earthCount(level),
              remaining: CompanionStages.remainingForNextEarth(level) ?? 0,
              progress: 1 -
                  (CompanionStages.remainingForNextEarth(level) ?? 0) /
                      CompanionStages.stages.last.minLevel,
            ),
        ],
      ),
    );
  }
}

class _NextMilestoneCard extends StatelessWidget {
  final int remaining;
  final double progress;

  const _NextMilestoneCard({
    required this.remaining,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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

/// 最終段階到達後に積み上がる「完成した地球」の数と、次の1個までの進捗。
class _EarthStockCard extends StatelessWidget {
  final int earthCount;
  final int remaining;
  final double progress;

  const _EarthStockCard({
    required this.earthCount,
    required this.remaining,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('🌍', style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text(
                  '完成した星 $earthCount 個',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'あと $remaining 回投入すると次の星が完成する',
              style: TextStyle(fontSize: 13, color: colorScheme.onSecondaryContainer),
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

  const _CompanionStage({
    required this.stage,
    required this.mood,
    required this.developmentLevel,
    required this.idleValue,
    required this.feedScale,
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
                  autoSpin: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 星の完成を祝う紙吹雪。短時間だけ弾け飛んで消える。
class _ConfettiBurst extends StatefulWidget {
  const _ConfettiBurst();

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    final rnd = math.Random();
    _particles = List.generate(28, (_) => _ConfettiParticle.random(rnd));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(particles: _particles, progress: _controller.value),
        ),
      ),
    );
  }
}

class _ConfettiParticle {
  final double startX;
  final double speed;
  final double phase;
  final double size;
  final Color color;
  final double spin;

  const _ConfettiParticle({
    required this.startX,
    required this.speed,
    required this.phase,
    required this.size,
    required this.color,
    required this.spin,
  });

  factory _ConfettiParticle.random(math.Random rnd) {
    const colors = [
      Color(0xFFFFD54F),
      Color(0xFFFF8A65),
      Color(0xFF4FC3F7),
      Color(0xFFAED581),
      Color(0xFFBA68C8),
    ];
    return _ConfettiParticle(
      startX: rnd.nextDouble(),
      speed: 0.6 + rnd.nextDouble() * 0.8,
      phase: rnd.nextDouble() * math.pi * 2,
      size: 4 + rnd.nextDouble() * 5,
      color: colors[rnd.nextInt(colors.length)],
      spin: (rnd.nextBool() ? 1 : -1) * (2 + rnd.nextDouble() * 4),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final particle in particles) {
      final fallY = progress * progress * size.height * 1.6 * particle.speed;
      final y = -12 + fallY;
      if (y > size.height) continue;
      final driftX =
          math.sin(particle.phase + progress * 6) * size.width * 0.08;
      final x = particle.startX * size.width + driftX;
      final alpha = (1 - progress).clamp(0.0, 1.0);

      paint.color = particle.color.withValues(alpha: alpha);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * particle.spin);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: particle.size,
          height: particle.size * 0.6,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
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
