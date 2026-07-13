import 'package:flutter/material.dart';

import '../constants/building_definitions.dart';
import '../constants/game_constants.dart';
import '../constants/town_stages.dart';
import '../domain/models/building.dart';

/// 操作説明とクリア条件を表示する画面
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final finalStage = TownStages.stages.last;

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
              _Step(number: 3, text: '町画面でストックした電池を使い、建てたい建物を選んで建設します。'),
              _Step(number: 4, text: '建物が増えると町が発展し、蓄電池容量や発電効率が上がります。'),
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
            icon: Icons.location_city,
            title: '建物の種類',
            children: [
              for (final type in BuildingType.values)
                _BuildingRow(type: type),
            ],
          ),
          _SectionCard(
            icon: Icons.landscape,
            title: '町の発展段階',
            children: [
              for (final stage in TownStages.stages)
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
                              : '${stage.name}（${stage.minLevel}棟〜）',
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
                '建物が ${finalStage.minLevel} 棟に達し「${finalStage.name}」段階になると、'
                'ロケットが初めて発射されます。これがメインの目標です。',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'ロケット建設段階以降は、${GameConstants.rocketLaunchInterval}棟建てるごとに'
                'ロケットが再発射されます。クリア後も町は成長し続け、'
                '実績の解除や文明スコアの向上を目指せます。',
                style: TextStyle(color: colorScheme.outline),
              ),
            ],
          ),
          _SectionCard(
            icon: Icons.menu_book,
            title: '画面の見方',
            children: const [
              _Bullet(text: 'ホーム — 蓄電池の状態・今日の歩数・発電量・同期'),
              _Bullet(text: '町 — 建物マップ・ストック電池の消費・発展段階'),
              _Bullet(text: '履歴 — 日次記録・満タンイベント・ロケット発射・実績'),
              _Bullet(text: '設定 — 体重・速度・発電係数・GPS速度計測'),
            ],
          ),
          _SectionCard(
            icon: Icons.lightbulb_outline,
            title: 'ヒント',
            children: const [
              _Bullet(text: '発電所を建てると蓄電池容量が増え、満タンにしやすくなります。'),
              _Bullet(text: '公園を建てると発電効率が上がり、同じ歩数でより多く発電できます。'),
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

class _BuildingRow extends StatelessWidget {
  final BuildingType type;

  const _BuildingRow({required this.type});

  @override
  Widget build(BuildContext context) {
    final def = BuildingDefinitions.of(type);
    final colorScheme = Theme.of(context).colorScheme;

    final effect = switch (type) {
      BuildingType.house => '人口 +${def.population}',
      BuildingType.powerPlant =>
        '蓄電池容量 +${BuildingDefinitions.powerPlantCapacityBonusWh.toStringAsFixed(0)} Wh',
      BuildingType.park =>
        '発電効率 ×${BuildingDefinitions.parkCoefficientMultiplier}',
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
