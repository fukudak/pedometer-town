import 'package:health/health.dart';

/// Health 権限拒否・取得失敗時に投げる例外
class HealthServiceException implements Exception {
  final String message;

  const HealthServiceException(this.message);

  @override
  String toString() => 'HealthServiceException: $message';
}

/// `health` パッケージのラッパー（iOS: HealthKit / Android: Health Connect）
class HealthService {
  final Health _health;

  HealthService({Health? health}) : _health = health ?? Health();

  static const _types = [HealthDataType.STEPS];

  /// `health` パッケージの初期化。main() 内で呼び出すこと。
  Future<void> configure() async {
    await _health.configure();
  }

  /// 歩数の読み取り権限をリクエストする。
  ///
  /// 拒否された場合は [HealthServiceException] を throw する。
  Future<void> requestPermissions() async {
    final granted = await _health.requestAuthorization(_types);
    if (!granted) {
      throw const HealthServiceException('歩数へのアクセスが必要です');
    }
  }

  /// 今日（端末ローカル日付 0:00〜現在）の歩数合計を取得する。
  ///
  /// 取得に失敗した場合は [HealthServiceException] を throw する。
  Future<int> getTodaySteps() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final steps = await _health.getTotalStepsInInterval(startOfDay, now);
    if (steps == null) {
      throw const HealthServiceException('歩数データを取得できませんでした');
    }
    return steps;
  }
}
