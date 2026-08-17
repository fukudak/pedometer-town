import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/models/daily_step_record.dart';
import '../providers/history_provider.dart';
import '../widgets/history_chart.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('履歴をクリア'),
        content: const Text(
          '過去の歩数・発電量の記録をすべて削除します。'
          'まちの発展度・蓄電池・累積発電量も初期状態に戻ります。元に戻せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('クリア'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<HistoryProvider>().clearHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyProvider = context.watch<HistoryProvider>();
    final List<DailyStepRecord> records = historyProvider.loadHistory();
    final colorScheme = Theme.of(context).colorScheme;
    final isEmpty = records.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('履歴'),
        actions: [
          if (!isEmpty)
            TextButton(
              onPressed: () => _confirmClearAll(context),
              child: const Text('クリア'),
            ),
        ],
      ),
      body: isEmpty
          ? Center(
              child: Text(
                '記録がありません',
                style: TextStyle(color: colorScheme.outline),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Text(
                  '発電量の推移',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    child: HistoryChart(records: records),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '歩数・発電量',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...records.map((record) {
                  return Dismissible(
                    key: ValueKey(record.date),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Icon(
                        Icons.delete,
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                    confirmDismiss: (_) async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('この記録を削除'),
                          content: Text(
                            '${_formatDate(record.date)} の記録を削除します。',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('キャンセル'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('削除'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return false;
                      if (!context.mounted) return false;
                      await context.read<HistoryProvider>().deleteHistoryRecord(
                        record.date,
                      );
                      return true;
                    },
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.secondaryContainer,
                          child: Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                        title: Text(_formatDate(record.date)),
                        subtitle: Text('${record.totalSteps} 歩'),
                        trailing: Text(
                          '${record.totalEnergyWh.toStringAsFixed(1)} Wh',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => _confirmClearAll(context),
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('履歴をクリア'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
    );
  }

  String _formatDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    return '${parts[0]}/${parts[1]}/${parts[2]}';
  }
}
