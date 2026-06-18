import 'dart:async';

import 'package:geolocator/geolocator.dart';

class SpeedMeasurementService {
  // 0.5 km/h 未満は停止とみなし平均から除外する
  static const double _minValidSpeedKmh = 0.5;

  Future<void> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const SpeedMeasurementException(
          '位置情報サービスが無効です。設定から有効にしてください。');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const SpeedMeasurementException(
          '位置情報の権限が必要です。設定から許可してください。');
    }
  }

  Stream<double?> _speedStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).map((pos) => pos.speed >= 0 ? pos.speed * 3.6 : null);
  }

  /// [duration] の間 GPS 速度をサンプリングし、有効な速度の平均を返す。
  /// 有効サンプルが0件（ずっと停止していた場合）は null を返す。
  Future<double?> measureAverageSpeed({
    Duration duration = const Duration(seconds: 30),
    void Function(double? currentKmh, int remainingSeconds)? onUpdate,
  }) async {
    await requestPermission();

    final samples = <double>[];
    final completer = Completer<double?>();
    late StreamSubscription<double?> sub;
    final endTime = DateTime.now().add(duration);

    sub = _speedStream().listen(
      (speedKmh) {
        final remaining = endTime.difference(DateTime.now()).inSeconds;
        onUpdate?.call(speedKmh, remaining.clamp(0, duration.inSeconds));
        if (speedKmh != null && speedKmh >= _minValidSpeedKmh) {
          samples.add(speedKmh);
        }
      },
      onError: (Object e) {
        sub.cancel();
        if (!completer.isCompleted) {
          completer.completeError(SpeedMeasurementException('GPS エラー: $e'));
        }
      },
    );

    Timer(duration, () {
      sub.cancel();
      if (!completer.isCompleted) {
        final avg = samples.isEmpty
            ? null
            : samples.reduce((a, b) => a + b) / samples.length;
        completer.complete(avg);
      }
    });

    return completer.future;
  }
}

class SpeedMeasurementException implements Exception {
  final String message;
  const SpeedMeasurementException(this.message);
  @override
  String toString() => message;
}
