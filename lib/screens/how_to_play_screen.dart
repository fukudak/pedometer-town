import 'package:flutter/material.dart';

import '../constants/companion_stages.dart';
import '../constants/feed_item_definitions.dart';
import '../constants/game_constants.dart';
import '../domain/models/feed_item_type.dart';

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
              _Step(number: 3, text: '相棒画面でストックした電池を使い、あげたいごはんを選んで与えます。'),
              _Step(number: 4, text: 'ごはんをあげるたびに相棒はなついていき、進化していきます。'),
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
                '目安: 70kg・5km/h・係数1.0 なら 1,000歩 ≒ ${GameConstants.initialBatteryCapacityWh.toStringAsFixed(0)} Wh（蓄電池1個分）',
                style: TextStyle(color: colorScheme.outline, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                '体重・速度・係数は設定画面で変更できます。GPS計測で実際の歩行速度を測ることもできます。',
              ),
            ],
          ),
          _SectionCard(
            icon: Icons.pets,
            title: 'ごはんの種類',
            children: [
              for (final type in FeedItemType.values)
                _FeedItemRow(type: type),
            ],
          ),
          _SectionCard(
            icon: Icons.auto_awesome,
            title: '相棒の進化段階',
            children: [
              for (final stage in CompanionStages.stages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      if (stage.icon != null) ...[
                        Icon(stage.icon, size: 18, color: colorScheme.primary),
                        const SizedBox(width: 8),
                      ] else
                        const SizedBox(width: 26),
                      Expanded(
                        child: Text(
                          stage.minLevel == 0
                              ? stage.name
                              : '${stage.name}（なつき度${stage.minLevel}〜）',
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
                'なつき度が ${finalStage.minLevel} に達し「${finalStage.name}」段階になると、'
                '初めての「きらめきタイム」が起こります。これがメインの目標です。',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '最終進化段階以降は、${GameConstants.sparkleMomentInterval}回ごはんをあげるごとに'
                'きらめきタイムが再び起こります。クリア後も相棒との時間は続き、'
                '実績の解除や愛着スコアの向上を目指せます。',
                style: TextStyle(color: colorScheme.outline),
              ),
            ],
          ),
          _SectionCard(
            icon: Icons.menu_book,
            title: '画面の見方',
            children: const [
              _Bullet(text: 'ホーム — 蓄電池の状態・今日の歩数・発電量・同期'),
              _Bullet(text: '相棒 — 相棒の姿・ストック電池の消費・進化段階'),
              _Bullet(text: '履歴 — 日次記録・満タンイベント・きらめきタイム・実績'),
              _Bullet(text: '設定 — 体重・速度・発電係数・GPS速度計測'),
            ],
          ),
          _SectionCard(
            icon: Icons.lightbulb_outline,
            title: 'ヒント',
            children: const [
              _Bullet(text: 'げんきの素をあげると蓄電池容量が増え、満タンにしやすくなります。'),
              _Bullet(text: 'おもちゃをあげると発電効率が上がり、同じ歩数でより多く発電できます。'),
              _Bullet(text: '相棒をタップすると、なでてあげられます。'),
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

class _FeedItemRow extends StatelessWidget {
  final FeedItemType type;

  const _FeedItemRow({required this.type});

  @override
  Widget build(BuildContext context) {
    final def = FeedItemDefinitions.of(type);
    final colorScheme = Theme.of(context).colorScheme;

    final effect = switch (type) {
      FeedItemType.meal => 'なつき度 +1',
      FeedItemType.booster =>
        '蓄電池容量 +${FeedItemDefinitions.boosterCapacityBonusWh.toStringAsFixed(0)} Wh',
      FeedItemType.toy =>
        '発電効率 ×${FeedItemDefinitions.toyCoefficientMultiplier}',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(def.icon, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${def.displayName}（電池 ${def.batteryCost} 個）',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(effect, style: TextStyle(fontSize: 13, color: colorScheme.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
