import 'dart:async';
import 'dart:io';

import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

/// Health 権限拒否・取得失敗時に投げる例外
class HealthServiceException implements Exception {
  final String message;

  const HealthServiceException(this.message);

  @override
  String toString() => 'HealthServiceException: $message';
}

/// 歩数取得サービス
/// - iOS: HealthKit（health パッケージ）
/// - Android: ハードウェアステップカウンターセンサー（pedometer_plus）
class HealthService {
  final Health _health;

  HealthService({Health? health}) : _health = health ?? Health();

  static const _types = [HealthDataType.STEPS];

  Future<void> configure() async {
    if (!Platform.isAndroid) {
      await _health.configure();
    }
  }

  /// 権限をリクエストする。
  /// - Android: ACTIVITY_RECOGNITION（歩数センサー用）
  /// - iOS: HealthKit の歩数読み取り権限
  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        throw const HealthServiceException('歩数センサーへのアクセスが必要です');
      }
      return;
    }

    final granted = await _health.requestAuthorization(_types);
    if (!granted) {
      throw const HealthServiceException('歩数へのアクセスが必要です');
    }
  }

  /// 歩数を取得する。
  /// - iOS: 今日 0:00〜現在の合計歩数（HealthKit）
  /// - Android: 最後の再起動からの累計歩数（センサー直読み）
  ///
  /// 取得に失敗した場合は [HealthServiceException] を throw する。
  Future<int> getTodaySteps() async {
    if (Platform.isAndroid) {
      return _getStepsFromSensor();
    }
    return _getStepsFromHealthKit();
  }

  Future<int> _getStepsFromSensor() async {
    try {
      final event = await Pedometer.stepCountStream.first
          .timeout(const Duration(seconds: 5));
      return event.steps;
    } on TimeoutException {
      throw const HealthServiceException('歩数センサーがデータを返しませんでした');
    } catch (e) {
      throw HealthServiceException('歩数センサーを読み取れませんでした: $e');
    }
  }

  Future<int> _getStepsFromHealthKit() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final steps = await _health.getTotalStepsInInterval(startOfDay, now);
    if (steps == null) {
      throw const HealthServiceException('歩数データを取得できませんでした');
    }
    return steps;
  }
}
