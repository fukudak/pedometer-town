import 'dart:async';

import 'package:flutter/material.dart';

import 'constants/companion_atmosphere.dart';
import 'constants/companion_stages.dart';
import 'domain/companion_logic.dart';
import 'widgets/companion/companion_avatar.dart';

/// まちの発展デモ（土地 → ロケット → その後は人口・建物が増え続ける）。
/// 起動例: `flutter run -t lib/demo_stages_main.dart -d chrome`
void main() {
  runApp(const DemoStagesApp());
}

class DemoStagesApp extends StatelessWidget {
  const DemoStagesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'まちの発展デモ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const DemoStagesPage(),
    );
  }
}

class DemoStagesPage extends StatefulWidget {
  const DemoStagesPage({super.key});

  @override
  State<DemoStagesPage> createState() => _DemoStagesPageState();
}

class _DemoStagesPageState extends State<DemoStagesPage>
    with TickerProviderStateMixin {
  late final PageController _controller;
  late final AnimationController _idle;
  late final AnimationController _launch;
  Timer? _autoPlay;

  /// ストーリー段階インデックス（0..stages.length-1）
  int _index = 0;

  /// ロケット到達後の発展度（17〜）。growth モードで増加。
  int _growthLevel = 17;

  bool _autoPlaying = true;
  bool _inGrowth = false;
  bool _finishedGrowth = false;

  static const _dwell = Duration(milliseconds: 2000);
  static const _growthDwell = Duration(milliseconds: 1100);
  static const _launchDuration = Duration(milliseconds: 2800);
  static const _growthEndLevel = 32;

  List<CompanionStage> get _stages => CompanionStages.stages;

  int get _displayLevel =>
      _inGrowth ? _growthLevel : _stages[_index].minLevel;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _launch = AnimationController(
      vsync: this,
      duration: _launchDuration,
    );
    _scheduleAdvance();
  }

  @override
  void dispose() {
    _autoPlay?.cancel();
    _controller.dispose();
    _idle.dispose();
    _launch.dispose();
    super.dispose();
  }

  void _scheduleAdvance() {
    _autoPlay?.cancel();
    if (!_autoPlaying || _finishedGrowth) return;

    if (_inGrowth) {
      if (_growthLevel >= _growthEndLevel) {
        setState(() {
          _finishedGrowth = true;
          _autoPlaying = false;
        });
        return;
      }
      _autoPlay = Timer(_growthDwell, () {
        if (!mounted || !_autoPlaying || !_inGrowth) return;
        setState(() => _growthLevel++);
        _scheduleAdvance();
      });
      return;
    }

    if (_index >= _stages.length - 1) {
      _playLaunchThenGrowth();
      return;
    }

    _autoPlay = Timer(_dwell, () {
      if (!mounted || !_autoPlaying) return;
      _goToStage(_index + 1);
    });
  }

  Future<void> _playLaunchThenGrowth() async {
    _launch
      ..reset()
      ..forward();
    await Future<void>.delayed(_launchDuration + const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _inGrowth = true;
      _growthLevel = 17;
      _launch.value = 1;
    });
    _scheduleAdvance();
  }

  Future<void> _goToStage(int i, {bool fromUser = false}) async {
    if (i < 0 || i >= _stages.length) return;
    if (fromUser) {
      _autoPlay?.cancel();
      setState(() {
        _autoPlaying = false;
        _inGrowth = false;
        _finishedGrowth = false;
        _growthLevel = 17;
      });
      _launch.stop();
      _launch.value = 0;
    }

    setState(() {
      _index = i;
      if (i < _stages.length - 1) {
        _launch.value = 0;
      }
    });

    await _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );

    if (!fromUser) {
      _scheduleAdvance();
    } else if (i == _stages.length - 1) {
      _launch
        ..reset()
        ..forward();
    }
  }

  void _toggleAutoPlay() {
    if (_finishedGrowth) {
      _replay();
      return;
    }
    setState(() => _autoPlaying = !_autoPlaying);
    if (_autoPlaying) {
      _scheduleAdvance();
    } else {
      _autoPlay?.cancel();
    }
  }

  void _replay() {
    _autoPlay?.cancel();
    _launch.stop();
    _launch.value = 0;
    setState(() {
      _finishedGrowth = false;
      _inGrowth = false;
      _autoPlaying = true;
      _index = 0;
      _growthLevel = 17;
    });
    _controller.jumpToPage(0);
    _scheduleAdvance();
  }

  void _enterGrowthManually() {
    _autoPlay?.cancel();
    setState(() {
      _autoPlaying = false;
      _inGrowth = true;
      _finishedGrowth = false;
      _index = _stages.length - 1;
      _growthLevel = 17;
      _launch.value = 1;
    });
    _controller.jumpToPage(_stages.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final stages = _stages;
    final stage = _inGrowth ? stages.last : stages[_index];
    final colorScheme = Theme.of(context).colorScheme;
    final level = _displayLevel;
    final buildings = TownStats.buildingCount(level);
    final population = TownStats.population(level);
    final story = _inGrowth
        ? (
            title: 'まちが広がり続ける',
            description: 'ロケット到達後は新しい段階はなく、建物と人口だけが増えていく。',
          )
        : (_index == 0
            ? (title: 'はじまり', description: 'まだ何もない土地。ここからまちが育っていく。')
            : CompanionAtmosphere.stageStory(stage.id));

    final progress = _inGrowth
        ? 0.85 + 0.15 * ((_growthLevel - 17) / (_growthEndLevel - 17)).clamp(0.0, 1.0)
        : (_index / stages.length);

    return Scaffold(
      appBar: AppBar(
        title: const Text('まちの発展デモ'),
        actions: [
          IconButton(
            tooltip: _finishedGrowth
                ? '最初から'
                : (_autoPlaying ? '一時停止' : '自動再生'),
            onPressed: _toggleAutoPlay,
            icon: Icon(
              _finishedGrowth
                  ? Icons.replay
                  : (_autoPlaying ? Icons.pause : Icons.play_arrow),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      _inGrowth
                          ? '拡大フェーズ  発展度 $level'
                          : '${_index + 1} / ${stages.length}',
                      style: TextStyle(color: colorScheme.outline),
                    ),
                    const Spacer(),
                    Text(
                      _finishedGrowth
                          ? 'デモ完了'
                          : (_inGrowth
                              ? '建物・人口が増加中…'
                              : (_autoPlaying ? '自動再生中…' : '手動')),
                      style: TextStyle(
                        color: _finishedGrowth || _inGrowth
                            ? colorScheme.primary
                            : colorScheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          // 人口・建物
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.apartment,
                    label: '建物',
                    value: '$buildings',
                    unit: '棟',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    icon: Icons.groups,
                    label: '人口',
                    value: '$population',
                    unit: '人',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: Listenable.merge([_idle, _launch]),
              builder: (context, _) {
                if (_inGrowth) {
                  return _StageSlide(
                    stage: stages.last,
                    idleValue: _idle.value,
                    launchProgress: 1,
                    developmentLevel: _growthLevel,
                  );
                }
                return PageView.builder(
                  controller: _controller,
                  itemCount: stages.length,
                  onPageChanged: (i) {
                    setState(() => _index = i);
                    if (i < stages.length - 1) {
                      _launch.value = 0;
                    }
                  },
                  itemBuilder: (context, i) {
                    final s = stages[i];
                    return _StageSlide(
                      stage: s,
                      idleValue: _idle.value,
                      launchProgress: s.id == 'star' ? _launch.value : 0,
                      developmentLevel: s.minLevel,
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Text(
                  story.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  story.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.outline, height: 1.4),
                ),
                if (!_inGrowth && CompanionStages.nextMilestone(level) != null) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final m = CompanionStages.nextMilestone(level)!;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'あと ${m.remaining} 回投入 →「${m.stage.name}」（${m.hint}）\n'
                          '到達時: 建物 ${m.buildings} 棟・人口 ${m.population} 人',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      );
                    },
                  ),
                ],
                if (_inGrowth) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'あと 1 回投入 → 建物 ${TownStats.buildingCount(level + 1)} 棟・'
                      '人口 ${TownStats.population(level + 1)} 人'
                      '（+${TownStats.buildingCount(level + 1) - buildings} 棟 / '
                      '+${TownStats.population(level + 1) - population} 人）',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!_inGrowth)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: stages.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  return ChoiceChip(
                    label: Text(stages[i].name, style: const TextStyle(fontSize: 12)),
                    selected: i == _index,
                    onSelected: (_) => _goToStage(i, fromUser: true),
                  );
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'ロケット到達後: 建物 ${TownStats.buildingCount(17)}→$buildings 棟 / '
                '人口 ${TownStats.population(17)}→$population 人',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colorScheme.outline),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: _inGrowth
                      ? () {
                          setState(() {
                            _inGrowth = false;
                            _autoPlaying = false;
                            _finishedGrowth = false;
                            _growthLevel = 17;
                            _launch.value = 1;
                            _index = stages.length - 1;
                          });
                          _controller.jumpToPage(stages.length - 1);
                        }
                      : (_index <= 0
                          ? null
                          : () => _goToStage(_index - 1, fromUser: true)),
                  child: Text(_inGrowth ? '段階へ戻る' : '戻る'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _finishedGrowth
                        ? _replay
                        : (_inGrowth
                            ? () {
                                setState(() {
                                  if (_growthLevel < _growthEndLevel) {
                                    _growthLevel++;
                                  } else {
                                    _finishedGrowth = true;
                                    _autoPlaying = false;
                                  }
                                });
                              }
                            : (_index >= stages.length - 1
                                ? () async {
                                    await _launch.forward(from: 0);
                                    if (!mounted) return;
                                    _enterGrowthManually();
                                  }
                                : () => _goToStage(_index + 1, fromUser: true))),
                    child: Text(
                      _finishedGrowth
                          ? '最初からもう一度'
                          : (_inGrowth
                              ? 'もう少し拡大'
                              : (_index >= stages.length - 1
                                  ? '打ち上げ → 拡大へ'
                                  : '次へ')),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: colorScheme.outline)),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: value,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: ' $unit',
                          style: TextStyle(fontSize: 13, color: colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageSlide extends StatelessWidget {
  final CompanionStage stage;
  final double idleValue;
  final double launchProgress;
  final int developmentLevel;

  const _StageSlide({
    required this.stage,
    required this.idleValue,
    required this.launchProgress,
    required this.developmentLevel,
  });

  @override
  Widget build(BuildContext context) {
    final isNightish = stage.id == 'charged' ||
        stage.id == 'reliable' ||
        stage.id == 'radiant' ||
        stage.id == 'star';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isNightish
                ? const [Color(0xFF1A237E), Color(0xFF3949AB), Color(0xFFE8EAF6)]
                : const [Color(0xFF81D4FA), Color(0xFFE8F5E9)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: CompanionAvatar(
                stage: stage,
                mood: CompanionMood.happy,
                size: 260,
                idleValue: idleValue,
                launchProgress: launchProgress,
                developmentLevel: developmentLevel,
                showSparkles: stage.id == 'star' || stage.id == 'radiant',
              ),
            ),
            if (stage.id == 'star' && launchProgress > 0.85)
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        '🚀 打ち上げ成功！',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
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
