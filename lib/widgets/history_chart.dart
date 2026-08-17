import 'package:flutter/material.dart';

import '../domain/models/daily_step_record.dart';

/// 日次記録の発電量推移を表す棒グラフ（外部ライブラリ不使用）。
/// [records] は新しい順（日付降順）を受け取り、内部で古い順に並べ替えて描画する。
class HistoryChart extends StatelessWidget {
  final List<DailyStepRecord> records;
  final int maxDays;

  const HistoryChart({
    super.key,
    required this.records,
    this.maxDays = 14,
  });

  @override
  Widget build(BuildContext context) {
    final chronological = records.take(maxDays).toList().reversed.toList();
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 180,
      child: CustomPaint(
        size: Size.infinite,
        painter: _BarChartPainter(
          records: chronological,
          barColor: colorScheme.primary,
          gridColor: colorScheme.outlineVariant,
          labelColor: colorScheme.outline,
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<DailyStepRecord> records;
  final Color barColor;
  final Color gridColor;
  final Color labelColor;

  static const double _labelHeight = 20;
  static const double _valueLabelHeight = 16;

  _BarChartPainter({
    required this.records,
    required this.barColor,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (records.isEmpty) return;

    final chartHeight = size.height - _labelHeight - _valueLabelHeight;
    final maxValue = records
        .map((r) => r.totalEnergyWh)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final scaleMax = maxValue <= 0 ? 1.0 : maxValue;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, _valueLabelHeight + chartHeight),
      Offset(size.width, _valueLabelHeight + chartHeight),
      gridPaint,
    );

    final slotWidth = size.width / records.length;
    final barWidth = (slotWidth * 0.55).clamp(4.0, 40.0);
    final barPaint = Paint()..color = barColor;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      final slotCenter = slotWidth * i + slotWidth / 2;
      final barHeight = scaleMax == 0
          ? 0.0
          : (record.totalEnergyWh / scaleMax) * chartHeight;
      final top = _valueLabelHeight + chartHeight - barHeight;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            slotCenter - barWidth / 2,
            top,
            barWidth,
            barHeight,
          ),
          const Radius.circular(3),
        ),
        barPaint,
      );

      if (record.totalEnergyWh > 0) {
        textPainter.text = TextSpan(
          text: record.totalEnergyWh.toStringAsFixed(0),
          style: TextStyle(fontSize: 10, color: labelColor),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(slotCenter - textPainter.width / 2, top - textPainter.height - 2),
        );
      }

      final showLabel = records.length <= 7 ||
          i == 0 ||
          i == records.length - 1 ||
          i % (records.length ~/ 6).clamp(1, records.length) == 0;
      if (showLabel) {
        final label = _shortDate(record.date);
        textPainter.text = TextSpan(
          text: label,
          style: TextStyle(fontSize: 10, color: labelColor),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            slotCenter - textPainter.width / 2,
            _valueLabelHeight + chartHeight + 4,
          ),
        );
      }
    }
  }

  String _shortDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    return '${parts[1]}/${parts[2]}';
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.records != records ||
      oldDelegate.barColor != barColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor;
}
