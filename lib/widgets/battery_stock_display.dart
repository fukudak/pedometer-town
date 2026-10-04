import 'package:flutter/material.dart';

/// 満タンになった蓄電池のストックを、小さい電池アイコン×個数で表す。
/// 10本ごとに大きい電池アイコン1個にまとめて表示する。
class BatteryStockDisplay extends StatelessWidget {
  final int count;

  const BatteryStockDisplay({super.key, required this.count});

  static const int _batchSize = 10;

  /// アイコン部分の最大幅。個数が多くても隣の文字やボタンを押し出さず、この幅で折り返す。
  static const double _maxWidth = 72;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bigCount = count ~/ _batchSize;
    final smallCount = count % _batchSize;

    if (count == 0) {
      return Icon(
        Icons.battery_0_bar,
        color: colorScheme.outline,
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < bigCount; i++)
            Icon(Icons.battery_full, size: 28, color: colorScheme.primary),
          for (var i = 0; i < smallCount; i++)
            Icon(Icons.battery_std, size: 16, color: colorScheme.primary),
        ],
      ),
    );
  }
}
