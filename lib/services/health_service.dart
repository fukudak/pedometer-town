import 'dart:async';
import 'dart:io';

import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/local_storage.dart';

/// [HealthService.normalizeAndroidSteps] の結果
class AndroidStepNormalizationResult {
  final int todaySteps;
  final String baselineDate;
  final int baselineSteps;

  const AndroidStepNormalizationResult({
    required this.todaySteps,
    required this.baselineDate,
    required this.baselineSteps,
  });
}

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
  final LocalStorage? _storage;

  HealthService({Health? health, this._storage})
      : _health = health ?? Health();

  static const _types = [HealthDataType.STEPS];

  // Android センサーは端末起動時からの累積値を返すため、
  // 「今日0:00時点のセンサー値」をベースラインとして LocalStorage に永続化し、
  // 今日分の歩数に正規化する。

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

  /// 今日 0:00〜現在の合計歩数を取得する。
  /// - iOS: HealthKit が直接「今日0:00〜現在」を返す
  /// - Android: センサーは端末起動からの累積値を返すため、
  ///   永続化したベースラインとの差分から今日分に正規化する
  ///
  /// 取得に失敗した場合は [HealthServiceException] を throw する。
  Future<int> getTodaySteps() async {
    if (Platform.isAndroid) {
      return _getStepsFromSensor();
    }
    return _getStepsFromHealthKit();
  }

  Future<int> _getStepsFromSensor() async {
    final storage = _storage;
    if (storage == null) {
      throw StateError(
        'HealthService に LocalStorage が注入されていません（Android歩数の正規化に必要）。',
      );
    }

    final rawSteps = await _readRawSensorSteps();
    final baseline = storage.loadAndroidStepBaseline();

    final result = normalizeAndroidSteps(
      rawSteps: rawSteps,
      todayKey: _dateKey(DateTime.now()),
      storedBaselineDate: baseline.date,
      storedBaselineSteps: baseline.steps,
    );

    await storage.saveAndroidStepBaseline(
      result.baselineDate,
      result.baselineSteps,
    );
    return result.todaySteps;
  }

  /// センサーの累積値（端末起動からの累計）を「今日0:00からの歩数」に正規化する純粋関数。
  /// 日付が変わった場合は現在値を新しいベースラインとし、
  /// 端末再起動でセンサーがリセットされた場合（rawSteps が前回ベースラインより小さい）は
  /// ベースラインを0にして rawSteps をそのまま今日の歩数として扱う。
  static AndroidStepNormalizationResult normalizeAndroidSteps({
    required int rawSteps,
    required String todayKey,
    String? storedBaselineDate,
    int? storedBaselineSteps,
  }) {
    int baseline;
    if (storedBaselineDate != todayKey) {
      baseline = rawSteps;
    } else {
      baseline = storedBaselineSteps ?? rawSteps;
      if (rawSteps < baseline) {
        baseline = 0;
      }
    }
    return AndroidStepNormalizationResult(
      todaySteps: rawSteps - baseline,
      baselineDate: todayKey,
      baselineSteps: baseline,
    );
  }

  Future<int> _readRawSensorSteps() async {
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

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
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
