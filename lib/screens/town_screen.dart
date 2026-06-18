import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/building_definitions.dart';
import '../domain/models/building.dart';
import '../providers/town_provider.dart';

class TownScreen extends StatefulWidget {
  const TownScreen({super.key});

  @override
  State<TownScreen> createState() => _TownScreenState();
}

class _TownScreenState extends State<TownScreen> {
  Future<void> _build(TownProvider townProvider, BuildingType type) async {
    final ok = await townProvider.buildBuilding(type);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('エネルギーが不足しています')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final townProvider = context.watch<TownProvider>();
    final town = townProvider.town;

    return Scaffold(
      appBar: AppBar(title: const Text('町')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text('町レベル: ${town.townLevel}'),
          const SizedBox(height: 16),
          const Text('建設済みの建物', style: TextStyle(fontWeight: FontWeight.bold)),
          if (town.buildings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('まだ建物がありません'),
            )
          else
            ...town.buildings.map(
              (building) => ListTile(
                leading: const Icon(Icons.location_city),
                title: Text(BuildingDefinitions.of(building.type).displayName),
              ),
            ),
          const Divider(height: 32),
          const Text('建設可能な建物', style: TextStyle(fontWeight: FontWeight.bold)),
          ...BuildingType.values.map((type) {
            final definition = BuildingDefinitions.of(type);
            final canBuild = townProvider.canBuild(type);
            return ListTile(
              leading: const Icon(Icons.add_business),
              title: Text(definition.displayName),
              subtitle: Text('コスト: ${definition.costWh.toStringAsFixed(0)} Wh'),
              trailing: ElevatedButton(
                onPressed: canBuild ? () => _build(townProvider, type) : null,
                child: const Text('建設'),
              ),
            );
          }),
        ],
      ),
    );
  }
}
