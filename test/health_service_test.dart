import 'package:flutter_test/flutter_test.dart';

import 'package:pedometer_town/services/health_service.dart';

void main() {
  group('HealthService.normalizeAndroidSteps', () {
    test('初回起動（ベースライン未設定）は現在値を起点にして今日の歩数は0になる', () {
      final result = HealthService.normalizeAndroidSteps(
        rawSteps: 12345,
        todayKey: '2026-06-19',
      );
      expect(result.todaySteps, 0);
      expect(result.baselineDate, '2026-06-19');
      expect(result.baselineSteps, 12345);
    });

    test('同日内の再同期は起点との差分を返す', () {
      final result = HealthService.normalizeAndroidSteps(
        rawSteps: 12500,
        todayKey: '2026-06-19',
        storedBaselineDate: '2026-06-19',
        storedBaselineSteps: 12345,
      );
      expect(result.todaySteps, 155);
      expect(result.baselineDate, '2026-06-19');
      expect(result.baselineSteps, 12345);
    });

    test('日付が変わると前日までの累積値はリセットされ今日の歩数は0になる', () {
      // 前日のセンサー累積値が 12345（再起動なし）だった状態で日付が変わったケース
      final result = HealthService.normalizeAndroidSteps(
        rawSteps: 12345,
        todayKey: '2026-06-20',
        storedBaselineDate: '2026-06-19',
        storedBaselineSteps: 0,
      );
      expect(result.todaySteps, 0);
      expect(result.baselineDate, '2026-06-20');
      expect(result.baselineSteps, 12345);
    });

    test('日付が変わった直後に歩いた分は新しいベースラインからの差分になる', () {
      final result = HealthService.normalizeAndroidSteps(
        rawSteps: 12400,
        todayKey: '2026-06-20',
        storedBaselineDate: '2026-06-20',
        storedBaselineSteps: 12345,
      );
      expect(result.todaySteps, 55);
    });

    test('端末再起動でセンサーがリセットされた場合は現在値をそのまま今日の歩数とする', () {
      final result = HealthService.normalizeAndroidSteps(
        rawSteps: 80,
        todayKey: '2026-06-19',
        storedBaselineDate: '2026-06-19',
        storedBaselineSteps: 12345,
      );
      expect(result.todaySteps, 80);
      expect(result.baselineSteps, 0);
    });
  });
}
