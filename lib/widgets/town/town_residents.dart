import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants/town_atmosphere.dart';
import '../../constants/game_constants.dart';
import '../../domain/models/building.dart';
import '../../domain/models/town_state.dart';

class TownResidentsOverlay extends StatefulWidget {
  final TownState town;
  final TownTimeOfDay timeOfDay;
  final int maxResidents;

  const TownResidentsOverlay({
    super.key,
    required this.town,
    required this.timeOfDay,
    this.maxResidents = 8,
  });

  @override
  State<TownResidentsOverlay> createState() => _TownResidentsOverlayState();
}

class _TownResidentsOverlayState extends State<TownResidentsOverlay> {
  static const _moveDuration = Duration(seconds: 4);
  static const _replanInterval = Duration(seconds: 4);
  static const _bubbleDuration = Duration(seconds: 2);
  static const _bubbleTexts = [
    'いい天気',
    '公園まで散歩',
    '町が明るくなったね',
  ];

  final _random = math.Random();
  final List<_ResidentState> _residents = [];
  Timer? _replanTimer;
  Timer? _bubbleClearTimer;
  int? _bubbleResidentIndex;
  String _bubbleText = '';

  @override
  void initState() {
    super.initState();
    _syncResidents();
    _replanTimer = Timer.periodic(_replanInterval, (_) {
      if (!mounted) return;
      _replanResidents();
      _maybeShowBubble();
    });
  }

  @override
  void didUpdateWidget(covariant TownResidentsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.town != widget.town ||
        oldWidget.timeOfDay != widget.timeOfDay ||
        oldWidget.maxResidents != widget.maxResidents) {
      _syncResidents();
    }
  }

  @override
  void dispose() {
    _replanTimer?.cancel();
    _bubbleClearTimer?.cancel();
    super.dispose();
  }

  void _syncResidents() {
    final houseCount = widget.town.buildings
        .where((b) => b.type == BuildingType.house)
        .length;
    final targetCount = TownAtmosphere.residentDisplayCount(
      houseCount: houseCount,
      timeOfDay: widget.timeOfDay,
      maxResidents: widget.maxResidents,
    );

    if (_residents.length < targetCount) {
      for (var i = _residents.length; i < targetCount; i++) {
        final pos = _randomWalkablePosition();
        _residents.add(_ResidentState(x: pos.$1, y: pos.$2));
      }
    } else if (_residents.length > targetCount) {
      _residents.removeRange(targetCount, _residents.length);
    }

    _replanResidents();
    if (_bubbleResidentIndex != null && _bubbleResidentIndex! >= _residents.length) {
      _bubbleResidentIndex = null;
      _bubbleText = '';
    }
    setState(() {});
  }

  void _replanResidents() {
    for (final resident in _residents) {
      final target = _nextTargetPosition();
      resident.targetX = target.$1;
      resident.targetY = target.$2;
    }
    setState(() {});
  }

  (double, double) _nextTargetPosition() {
    final parks = widget.town.buildings.where((b) => b.type == BuildingType.park).toList();
    final tryPark = parks.isNotEmpty && _random.nextDouble() < 0.35;
    if (tryPark) {
      final park = parks[_random.nextInt(parks.length)];
      final around = [
        (park.x - 1, park.y),
        (park.x + 1, park.y),
        (park.x, park.y - 1),
        (park.x, park.y + 1),
      ].where((p) => _isWalkableCell(p.$1, p.$2)).toList();
      if (around.isNotEmpty) {
        final picked = around[_random.nextInt(around.length)];
        return _toCellOffset(picked.$1, picked.$2);
      }
    }
    return _randomWalkablePosition();
  }

  bool _isWalkableCell(int x, int y) {
    if (x < 0 || y < 0 || x >= GameConstants.townGridSize || y >= GameConstants.townGridSize) {
      return false;
    }
    return widget.town.buildingAt(x, y) == null;
  }

  (double, double) _randomWalkablePosition() {
    final walkable = <(int, int)>[];
    for (var y = 0; y < GameConstants.townGridSize; y++) {
      for (var x = 0; x < GameConstants.townGridSize; x++) {
        if (_isWalkableCell(x, y)) walkable.add((x, y));
      }
    }
    if (walkable.isEmpty) {
      final x = _random.nextInt(GameConstants.townGridSize);
      final y = _random.nextInt(GameConstants.townGridSize);
      return _toCellOffset(x, y);
    }
    final picked = walkable[_random.nextInt(walkable.length)];
    return _toCellOffset(picked.$1, picked.$2);
  }

  (double, double) _toCellOffset(int x, int y) {
    // 建物マスの中央を塞がないよう、セル内の端寄りに配置する。
    final dx = 0.2 + _random.nextDouble() * 0.6;
    final dy = 0.2 + _random.nextDouble() * 0.6;
    return (x + dx, y + dy);
  }

  void _maybeShowBubble() {
    if (_residents.isEmpty) return;
    if (_random.nextDouble() > 0.2) return;
    final idx = _random.nextInt(_residents.length);
    final text = _bubbleTexts[_random.nextInt(_bubbleTexts.length)];
    setState(() {
      _bubbleResidentIndex = idx;
      _bubbleText = text;
    });
    _bubbleClearTimer?.cancel();
    _bubbleClearTimer = Timer(_bubbleDuration, () {
      if (!mounted) return;
      setState(() {
        _bubbleResidentIndex = null;
        _bubbleText = '';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellW = constraints.maxWidth / GameConstants.townGridSize;
          final cellH = constraints.maxHeight / GameConstants.townGridSize;
          final color = widget.timeOfDay == TownTimeOfDay.night
              ? Colors.white70
              : Theme.of(context).colorScheme.onSurface;
          return Stack(
            children: [
              for (var i = 0; i < _residents.length; i++)
                AnimatedPositioned(
                  duration: _moveDuration,
                  curve: Curves.easeInOut,
                  left: (_residents[i].targetX * cellW) - 6,
                  top: (_residents[i].targetY * cellH) - 6,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_bubbleResidentIndex == i && _bubbleText.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _bubbleText,
                            style: const TextStyle(fontSize: 9, color: Colors.black87),
                          ),
                        ),
                      Icon(Icons.person, size: 12, color: color),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ResidentState {
  double x;
  double y;
  double targetX;
  double targetY;

  _ResidentState({
    required this.x,
    required this.y,
  })  : targetX = x,
        targetY = y;
}
