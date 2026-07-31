import 'feed_item_type.dart';

/// 給餌直後に一時的にUI演出へ渡すイベント（非永続化）。
class FeedEvent {
  final FeedItemType type;
  final DateTime createdAt;

  const FeedEvent({
    required this.type,
    required this.createdAt,
  });
}
