import 'building.dart';

/// 建設直後に一時的にUI演出へ渡すイベント（非永続化）。
class ConstructionEvent {
  final BuildingType type;
  final int x;
  final int y;
  final DateTime createdAt;

  const ConstructionEvent({
    required this.type,
    required this.x,
    required this.y,
    required this.createdAt,
  });
}
