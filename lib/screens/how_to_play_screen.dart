import 'package:flutter/material.dart';

import '../constants/companion_stages.dart';
import '../constants/feed_item_definitions.dart';
import '../constants/game_constants.dart';
import '../domain/companion_logic.dart';
import '../domain/models/feed_item_type.dart';
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
              _Step(number: 3, text: 'まち画面でストックした電池を使い、建設アイテムを選んで町を発展させます。'),
              _Step(number: 4, text: '建設するたびに発展度が上がり、土地に家と電灯が増えていきます。'),
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
            icon: Icons.electrical_services,
            title: '建設アイテム',
            children: [
              for (final type in FeedItemType.values)
                _FeedItemRow(type: type),
            ],
          ),
          _SectionCard(
            icon: Icons.location_city,
            title: 'まちの発展段階（正面ビュー）',
            children: [
              for (final stage in CompanionStages.stages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      CompanionAvatar(
                        stage: stage,
                        mood: CompanionMood.happy,
                        size: 48,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          stage.minLevel == 0
                              ? stage.name
                              : '${stage.name}（発展度${stage.minLevel}〜）',
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
                '発展度が ${finalStage.minLevel} に達し「${finalStage.name}」になると、'
                '初めての「きらめきタイム」が起こります。これがメインの目標です。',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '最終段階以降は、${GameConstants.sparkleMomentInterval}回建設するごとに'
                'きらめきタイムが再び起こります。クリア後もまちは育ち続け、'
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
              _Bullet(text: 'まち — 正面から見た町・電灯と電線の広がり・建設'),
              _Bullet(text: '履歴 — 日次記録・満タンイベント・きらめきタイム・実績'),
              _Bullet(text: '設定 — 体重・速度・発電係数・まちの名前・天気演出'),
            ],
          ),
          _SectionCard(
            icon: Icons.lightbulb_outline,
            title: 'ヒント',
            children: const [
              _Bullet(text: '配線キットを使うと蓄電池容量が増え、満タンにしやすくなります。'),
              _Bullet(text: '街灯アップすると発電効率が上がり、同じ歩数でより多く発電できます。'),
              _Bullet(text: 'まちをタップすると、ハートがふわっと出ます。'),
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
      FeedItemType.meal => '発展度 +1',
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
