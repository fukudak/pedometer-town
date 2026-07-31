import 'feed_item_type.dart';

/// 相棒の状態（ごはんの種類別に与えた回数）
class CompanionState {
  final int mealCount;
  final int boosterCount;
  final int toyCount;

  const CompanionState({
    this.mealCount = 0,
    this.boosterCount = 0,
    this.toyCount = 0,
  });

  factory CompanionState.initial() => const CompanionState();

  /// 与えた回数の合計に連動するなつき度レベル
  int get level => mealCount + boosterCount + toyCount;

  int countOf(FeedItemType type) {
    switch (type) {
      case FeedItemType.meal:
        return mealCount;
      case FeedItemType.booster:
        return boosterCount;
      case FeedItemType.toy:
        return toyCount;
    }
  }

  CompanionState copyWith({
    int? mealCount,
    int? boosterCount,
    int? toyCount,
  }) {
    return CompanionState(
      mealCount: mealCount ?? this.mealCount,
      boosterCount: boosterCount ?? this.boosterCount,
      toyCount: toyCount ?? this.toyCount,
    );
  }

  CompanionState addFeed(FeedItemType type) {
    switch (type) {
      case FeedItemType.meal:
        return copyWith(mealCount: mealCount + 1);
      case FeedItemType.booster:
        return copyWith(boosterCount: boosterCount + 1);
      case FeedItemType.toy:
        return copyWith(toyCount: toyCount + 1);
    }
  }

  Map<String, dynamic> toJson() => {
        'mealCount': mealCount,
        'boosterCount': boosterCount,
        'toyCount': toyCount,
      };

  factory CompanionState.fromJson(Map<String, dynamic> json) => CompanionState(
        mealCount: json['mealCount'] as int? ?? 0,
        boosterCount: json['boosterCount'] as int? ?? 0,
        toyCount: json['toyCount'] as int? ?? 0,
      );
}
