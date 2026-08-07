import 'package:flutter/material.dart';

import '../constants/companion_stages.dart';
import '../constants/game_constants.dart';
import '../domain/companion_logic.dart';
import '../widgets/companion/companion_avatar.dart';

/// 操作説明とクリア条件を表示する画面
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final finalStage = CompanionStages.stages.last;

    return Scaffold(
      appBar: AppBar(title: const Text('遊び方')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _SectionCard(
            icon: Icons.directions_walk,
            title: '基本の流れ',
            children: const [
              _Step(number: 1, text: '歩くと歩数が自動で同期され、蓄電池にエネルギーが溜まります。'),
              _Step(number: 2, text: '蓄電池が満タンになると「ストック」に電池が1個追加されます。'),
              _Step(number: 3, text: 'まち画面でストックした電池を「投入」すると、地球に灯りが広がります。'),
              _Step(number: 4, text: '投入するたびに発展度が上がり、夜の地球の街明かりが増えていきます。'),
            ],
          ),
          _SectionCard(
            icon: Icons.bolt,
            title: '発電の仕組み',
            children: [
              const Text(
                '歩数・体重・歩行速度・発電係数からエネルギー(Wh)が計算されます。',
              ),
              const SizedBox(height: 8),
              Text(
                '目安: 70kg・5km/h・係数1.0 なら '
                '${GameConstants.initialBatteryCapacityWh.toStringAsFixed(0)}歩 ≒ '
                '${GameConstants.initialBatteryCapacityWh.toStringAsFixed(0)} Wh（蓄電池1個分）',
                style: TextStyle(color: colorScheme.outline, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                '体重・速度・係数は設定画面で変更できます。GPS計測で実際の歩行速度を測ることもできます。',
              ),
            ],
          ),
          _SectionCard(
            icon: Icons.battery_charging_full,
            title: '電力の投入',
            children: const [
              Text('ストックした電池は、まち画面の「投入」ボタンで1個ずつ使います。'),
              SizedBox(height: 8),
              Text('1回の投入で発展度が +1 され、夜の地球の灯りが進みます。種類の選択はありません。'),
            ],
          ),
          _SectionCard(
            icon: Icons.public,
            title: '地球の灯り',
            children: [
              const Text('投入を重ねるほど、夜の地球に街の明かりが増えていきます。'),
              const SizedBox(height: 12),
              for (final stage in CompanionStages.stages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      CompanionAvatar(
                        stage: stage,
                        mood: CompanionMood.happy,
                        size: 48,
                        interactive: false,
                        autoSpin: false,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          stage.minLevel == 0
                              ? 'はじまり'
                              : '発展度 ${stage.minLevel}〜',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          _SectionCard(
            icon: Icons.flag,
            title: 'クリア条件',
            children: [
              Text(
                '発展度が ${finalStage.minLevel} に達すると、'
                '初めての「きらめきタイム」が起こります。これがメインの目標です。',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '最終段階以降は、${GameConstants.sparkleMomentInterval}回投入するごとに'
                'きらめきタイムが再び起こります。クリア後も地球の灯りは広がり続け、'
                '実績の解除やまちスコアの向上を目指せます。',
                style: TextStyle(color: colorScheme.outline),
              ),
            ],
          ),
          _SectionCard(
            icon: Icons.menu_book,
            title: '画面の見方',
            children: const [
              _Bullet(text: 'ホーム — 蓄電池の状態・今日の歩数・発電量・同期'),
              _Bullet(text: 'まち — 夜の地球の灯り・電池の投入'),
              _Bullet(text: '履歴 — 日次の歩数・発電量'),
              _Bullet(text: '設定 — 体重・速度・発電係数・まちの名前・天気演出'),
            ],
          ),
          _SectionCard(
            icon: Icons.lightbulb_outline,
            title: 'ヒント',
            children: const [
              _Bullet(text: '電池が溜まったらまち画面で「投入」すると地球に灯りが広がります。'),
              _Bullet(text: '地球を左右にドラッグすると回せます。タップでハートが出ます。'),
              _Bullet(text: 'アプリを開くと自動で歩数が同期されます。'),
              _Bullet(text: 'データはすべて端末内に保存され、外部へ送信されません。'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.secondaryContainer,
                  child: Icon(icon, size: 18, color: colorScheme.onSecondaryContainer),
                ),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
