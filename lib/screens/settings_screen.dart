import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/game_constants.dart';
import '../providers/settings_provider.dart';
import '../services/speed_measurement_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _weightKg;
  late double _speedKmh;
  late double _coefficient;

  late TextEditingController _weightController;
  late TextEditingController _speedController;
  late TextEditingController _coefficientController;
  late FocusNode _weightFocus;
  late FocusNode _speedFocus;
  late FocusNode _coefficientFocus;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _weightKg = settings.weightKg;
    _speedKmh = settings.defaultSpeedKmh;
    _coefficient = settings.energyCoefficient;

    _weightController = TextEditingController(text: _weightKg.toStringAsFixed(0));
    _speedController = TextEditingController(text: _speedKmh.toStringAsFixed(1));
    _coefficientController = TextEditingController(text: _coefficient.toStringAsFixed(4));
    _weightFocus = FocusNode()..addListener(() {
      if (!_weightFocus.hasFocus) _applyWeightText();
    });
    _speedFocus = FocusNode()..addListener(() {
      if (!_speedFocus.hasFocus) _applySpeedText();
    });
    _coefficientFocus = FocusNode()..addListener(() {
      if (!_coefficientFocus.hasFocus) _applyCoefficientText();
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _speedController.dispose();
    _coefficientController.dispose();
    _weightFocus.dispose();
    _speedFocus.dispose();
    _coefficientFocus.dispose();
    super.dispose();
  }

  void _applyWeightText() {
    final v = double.tryParse(_weightController.text);
    if (v == null) {
      _weightController.text = _weightKg.toStringAsFixed(0);
      return;
    }
    final clamped = v.clamp(GameConstants.minWeightKg, GameConstants.maxWeightKg);
    setState(() => _weightKg = clamped);
    _weightController.text = clamped.toStringAsFixed(0);
  }

  void _applySpeedText() {
    final v = double.tryParse(_speedController.text);
    if (v == null) {
      _speedController.text = _speedKmh.toStringAsFixed(1);
      return;
    }
    final clamped = v.clamp(GameConstants.minSpeedKmh, GameConstants.maxSpeedKmh);
    setState(() => _speedKmh = clamped);
    _speedController.text = clamped.toStringAsFixed(1);
  }

  void _applyCoefficientText() {
    final v = double.tryParse(_coefficientController.text);
    if (v == null) {
      _coefficientController.text = _coefficient.toStringAsFixed(4);
      return;
    }
    final clamped = v.clamp(
      GameConstants.minEnergyCoefficient,
      GameConstants.maxEnergyCoefficient,
    );
    setState(() => _coefficient = clamped);
    _coefficientController.text = clamped.toStringAsFixed(4);
  }

  Future<void> _save() async {
    final provider = context.read<SettingsProvider>();
    await provider.updateWeight(_weightKg);
    await provider.updateSpeed(_speedKmh);
    await provider.updateCoefficient(_coefficient);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保存しました')),
    );
  }

  Future<void> _openMeasurement() async {
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _SpeedMeasurementSheet(),
    );
    if (result != null && mounted) {
      final clamped = result.clamp(
        GameConstants.minSpeedKmh,
        GameConstants.maxSpeedKmh,
      );
      setState(() => _speedKmh = clamped);
      _speedController.text = clamped.toStringAsFixed(1);
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _SettingsSection(
            icon: Icons.directions_walk,
            title: '身体情報',
            children: [
              _LabeledField(
                label: '体重',
                unit: 'kg',
                controller: _weightController,
                focusNode: _weightFocus,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
                onSubmitted: (_) => _applyWeightText(),
              ),
              Slider(
                value: _weightKg,
                min: GameConstants.minWeightKg,
                max: GameConstants.maxWeightKg,
                divisions:
                    (GameConstants.maxWeightKg - GameConstants.minWeightKg)
                        .toInt(),
                label: _weightKg.toStringAsFixed(0),
                onChanged: (value) {
                  setState(() => _weightKg = value);
                  _weightController.text = value.toStringAsFixed(0);
                },
              ),
              const SizedBox(height: 12),
              _LabeledField(
                label: '歩行速度',
                unit: 'km/h',
                controller: _speedController,
                focusNode: _speedFocus,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onSubmitted: (_) => _applySpeedText(),
              ),
              Slider(
                value: _speedKmh,
                min: GameConstants.minSpeedKmh,
                max: GameConstants.maxSpeedKmh,
                divisions:
                    ((GameConstants.maxSpeedKmh - GameConstants.minSpeedKmh) *
                            10)
                        .toInt(),
                label: _speedKmh.toStringAsFixed(1),
                onChanged: (value) {
                  setState(() => _speedKmh = value);
                  _speedController.text = value.toStringAsFixed(1);
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _openMeasurement,
                  icon: const Icon(Icons.speed, size: 18),
                  label: const Text('歩行速度を計測する'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            icon: Icons.bolt,
            title: '発電設定',
            children: [
              _LabeledField(
                label: '発電変換係数',
                unit: '',
                controller: _coefficientController,
                focusNode: _coefficientFocus,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onSubmitted: (_) => _applyCoefficientText(),
              ),
              Slider(
                value: _coefficient,
                min: GameConstants.minEnergyCoefficient,
                max: GameConstants.maxEnergyCoefficient,
                divisions: 99,
                label: _coefficient.toStringAsFixed(4),
                onChanged: (value) {
                  setState(() => _coefficient = value);
                  _coefficientController.text = value.toStringAsFixed(4);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'バージョン ${GameConstants.appVersion}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.secondaryContainer,
                  child:
                      Icon(icon, size: 18, color: colorScheme.onSecondaryContainer),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String unit;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType keyboardType;
  final ValueChanged<String> onSubmitted;

  const _LabeledField({
    required this.label,
    required this.unit,
    required this.controller,
    required this.focusNode,
    required this.keyboardType,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label),
        const Spacer(),
        SizedBox(
          width: 100,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              suffixText: unit,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            ),
            onSubmitted: onSubmitted,
          ),
        ),
      ],
    );
  }
}

enum _MeasureState { idle, measuring, done, error }

class _SpeedMeasurementSheet extends StatefulWidget {
  const _SpeedMeasurementSheet();

  @override
  State<_SpeedMeasurementSheet> createState() => _SpeedMeasurementSheetState();
}

class _SpeedMeasurementSheetState extends State<_SpeedMeasurementSheet> {
  static const _measureDuration = Duration(seconds: 30);

  final _service = SpeedMeasurementService();
  _MeasureState _state = _MeasureState.idle;
  double? _currentSpeedKmh;
  int _remainingSeconds = _measureDuration.inSeconds;
  double? _resultKmh;
  String? _errorMessage;

  Future<void> _start() async {
    setState(() {
      _state = _MeasureState.measuring;
      _currentSpeedKmh = null;
      _remainingSeconds = _measureDuration.inSeconds;
    });

    try {
      final result = await _service.measureAverageSpeed(
        duration: _measureDuration,
        onUpdate: (speedKmh, remaining) {
          if (mounted) {
            setState(() {
              _currentSpeedKmh = speedKmh;
              _remainingSeconds = remaining;
            });
          }
        },
      );
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _state = _MeasureState.error;
          _errorMessage = '有効な速度が計測できませんでした。\n屋外を歩きながら計測してください。';
        });
      } else {
        setState(() {
          _state = _MeasureState.done;
          _resultKmh = result;
        });
      }
    } on SpeedMeasurementException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _MeasureState.error;
        _errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '歩行速度を計測',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _MeasureState.idle:
        return Column(
          children: [
            const Text(
              '屋外を実際に歩きながら30秒間計測します。\n計測した速度をエネルギー計算に反映できます。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow),
              label: const Text('計測開始'),
            ),
          ],
        );

      case _MeasureState.measuring:
        return Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: (_measureDuration.inSeconds - _remainingSeconds) /
                        _measureDuration.inSeconds,
                    strokeWidth: 6,
                  ),
                ),
                Text(
                  '$_remainingSeconds',
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _currentSpeedKmh != null
                  ? '現在の速度: ${_currentSpeedKmh!.toStringAsFixed(1)} km/h'
                  : 'GPS 取得中...',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '歩き続けてください',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        );

      case _MeasureState.done:
        return Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 12),
            Text(
              '計測結果: ${_resultKmh!.toStringAsFixed(1)} km/h',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_resultKmh),
              child: const Text('この速度を設定する'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _state = _MeasureState.idle),
              child: const Text('やり直す'),
            ),
          ],
        );

      case _MeasureState.error:
        return Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'エラーが発生しました',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() => _state = _MeasureState.idle),
              child: const Text('戻る'),
            ),
          ],
        );
    }
  }
}
