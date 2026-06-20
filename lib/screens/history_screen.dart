import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/models/daily_step_record.dart';
import '../providers/history_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('全履歴を削除'),
        content: const Text('過去の歩数・発電量の記録をすべて削除します。元に戻せません。'),
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
    if (confirmed == true && context.mounted) {
      await context.read<HistoryProvider>().clearHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<DailyStepRecord> records =
        context.watch<HistoryProvider>().loadHistory();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('履歴'),
        actions: [
          if (records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '全履歴を削除',
              onPressed: () => _confirmClearAll(context),
            ),
        ],
      ),
      body: records.isEmpty
          ? Center(
              child: Text(
                '記録がありません',
                style: TextStyle(color: colorScheme.outline),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
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
                    child: Icon(Icons.delete,
                        color: colorScheme.onErrorContainer),
                  ),
                  confirmDismiss: (_) async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('この記録を削除'),
                        content:
                            Text('${_formatDate(record.date)} の記録を削除します。'),
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
                        child: Icon(Icons.calendar_today,
                            size: 18,
                            color: colorScheme.onSecondaryContainer),
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
              },
            ),
    );
  }

  String _formatDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    return '${parts[0]}/${parts[1]}/${parts[2]}';
  }
}
