import 'dart:async';
import 'dart:io';

import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/local_storage.dart';
import '../utils/date_key.dart';

/// [HealthService.normalizeAndroidSteps] の結果
class AndroidStepNormalizationResult {
  /// 今日これまでに同期した歩数の累計（呼び出し元はこれと前回値の差を新規歩数として扱う）。
  final int todaySteps;

  /// 最終同期日（記録用。正規化の計算には使わない）。
  final String baselineDate;

  /// 最終同期時点のセンサー累積値（次回の増分計算の起点）。
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
  // 「最終同期時点のセンサー値」をベースラインとして LocalStorage に永続化し、
  // 前回同期からの増分を算出する。

  Future<void> configure() async {
    if (Platform.isAndroid) return;
    try {
      await _health.configure();
    } catch (_) {
      throw const HealthServiceException('健康データの初期設定に失敗しました');
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

    bool granted;
    try {
      granted = await _health.requestAuthorization(_types);
    } catch (_) {
      throw const HealthServiceException('歩数へのアクセス許可を確認できませんでした');
    }
    if (!granted) {
      throw const HealthServiceException('歩数へのアクセスが必要です');
    }
  }

  /// 今日これまでに同期した歩数の累計を取得する。
  /// 呼び出し元は「戻り値 − 今日の記録の lastSyncedSteps」を新規歩数として加算する。
  ///
  /// - iOS: HealthKit が直接「今日0:00〜現在」を返す
  /// - Android: センサーは端末起動からの累積値を返すため、最終同期時点のベースラインとの
  ///   増分を、今日すでに同期済みの歩数に足し込んで返す（[normalizeAndroidSteps]）
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
    final todayKey = formatDateKey(DateTime.now());
    final cursor = storage.loadTodaySyncedCursor();
    final alreadySyncedToday = cursor.date == todayKey ? cursor.steps : 0;

    final result = normalizeAndroidSteps(
      rawSteps: rawSteps,
      todayKey: todayKey,
      storedBaselineSteps: baseline.steps,
      alreadySyncedToday: alreadySyncedToday,
    );

    await storage.saveAndroidStepBaseline(
      result.baselineDate,
      result.baselineSteps,
    );
    return result.todaySteps;
  }

  /// センサーの累積値（端末起動からの累計）を、呼び出し元が期待する
  /// 「今日これまでに同期した歩数の累計」に正規化する純粋関数。
  ///
  /// ベースラインは **最終同期時点のセンサー値** を意味し、同期のたびに前進する。
  /// そのため戻り値は常に `[alreadySyncedToday] + 前回同期からの増分` となり、
  /// 呼び出し元（EnergyProvider）が `戻り値 - 今日の記録の lastSyncedSteps` を
  /// 新規歩数として加算する規約と噛み合う。
  ///
  /// - 日付をまたいでも増分は失われない（アプリを数日開かなくても取りこぼさない）
  /// - 日付をまたいだ翌日は [alreadySyncedToday] が 0 に戻るため、
  ///   前日までに加算済みの歩数が二重計上されることもない
  /// - 端末再起動でセンサーがリセットされた場合（rawSteps がベースラインより小さい）は
  ///   現在値をそのまま増分として扱う
  static AndroidStepNormalizationResult normalizeAndroidSteps({
    required int rawSteps,
    required String todayKey,
    int? storedBaselineSteps,
    int alreadySyncedToday = 0,
  }) {
    // 初回起動（ベースライン未設定）: 起点がないため増分は0とし、現在値を起点にする。
    if (storedBaselineSteps == null) {
      return AndroidStepNormalizationResult(
        todaySteps: alreadySyncedToday,
        baselineDate: todayKey,
        baselineSteps: rawSteps,
      );
    }

    // 端末再起動でセンサーがリセットされた場合は現在値がそのまま増分。
    final delta =
        rawSteps < storedBaselineSteps ? rawSteps : rawSteps - storedBaselineSteps;

    return AndroidStepNormalizationResult(
      todaySteps: alreadySyncedToday + delta,
      baselineDate: todayKey,
      baselineSteps: rawSteps,
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

  Future<int> _getStepsFromHealthKit() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    int? steps;
    try {
      steps = await _health.getTotalStepsInInterval(startOfDay, now);
    } catch (_) {
      throw const HealthServiceException('歩数データを取得できませんでした');
    }
    if (steps == null) {
      throw const HealthServiceException('歩数データを取得できませんでした');
    }
    return steps;
  }

  /// 指定した日（0:00〜24:00）の歩数を取得する。
  /// アプリを開かなかった日をさかのぼって集計するために使う。
  ///
  /// - iOS: HealthKit は日付を指定した過去の集計にも対応しているため取得できる
  /// - Android: センサーは「現在の累積値」しか返せず、過去の任意の日を
  ///   個別に取得する手段がないため、常に null を返す
  ///   （Android は代わりに [normalizeAndroidSteps] のベースライン繰り越しで対応する）
  ///
  /// 取得できない場合は例外を投げず null を返す（さかのぼり取得はベストエフォートのため）。
  Future<int?> getStepsForDate(DateTime date) async {
    if (Platform.isAndroid) return null;

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    try {
      return await _health.getTotalStepsInInterval(startOfDay, endOfDay);
    } catch (_) {
      return null;
    }
  }
}
