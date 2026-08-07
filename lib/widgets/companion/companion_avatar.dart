import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/companion_stages.dart';
import '../../domain/companion_logic.dart';

/// 真っ暗な地球儀。街の明かりだけが点としてともり、自転する。
/// 発展度（投入した電力量）に応じて、ともる点の数が増えていく。
///
/// 灯りの位置は NASA Black Marble の夜間光マップから抽出した実際の都市座標。
/// 球面上の緯度経度として持ち、正射投影で描くので裏側の点は消え、
/// 縁に近い点ほど暗く小さくなる。
class CompanionAvatar extends StatefulWidget {
  final CompanionStage stage;
  final CompanionMood mood;
  final double size;
  final double idleValue;
  final double walkPhase;
  final bool facingRight;
  final bool showSparkles;
  final double launchProgress;
  final int developmentLevel;
  final bool interactive;
  final bool autoSpin;
  final VoidCallback? onTap;

  /// 互換用。true でも丸い夜側地球儀として描画する。
  final bool fullBleed;

  const CompanionAvatar({
    super.key,
    required this.stage,
    this.mood = CompanionMood.normal,
    this.size = 160,
    this.idleValue = 0,
    this.walkPhase = 0,
    this.facingRight = true,
    this.showSparkles = false,
    this.launchProgress = 0,
    this.developmentLevel = 0,
    this.interactive = true,
    this.autoSpin = true,
    this.onTap,
    this.fullBleed = false,
  });

  static const assetPath = _NightLights.asset;

  @override
  State<CompanionAvatar> createState() => _CompanionAvatarState();
}

class _CompanionAvatarState extends State<CompanionAvatar>
    with SingleTickerProviderStateMixin {
  /// ユーザー操作による経度オフセット（0〜1）。
  double _userLon = 0.12;

  /// 視点の傾き（ラジアン）。北を上げると北半球が見える。
  double _tilt = -0.06;
  bool _dragging = false;

  List<_CityLight> _lights = const [];

  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    // ゆっくりだがはっきり分かる自転（約36秒で1周）
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 36),
    );
    if (widget.autoSpin) {
      _spin.repeat();
    }
    _NightLights.load().then(
      (lights) {
        if (!mounted) return;
        setState(() => _lights = lights);
      },
      // 灯りが出ないと理由が分からなくなるので、握り潰さず明示的に報告する。
      onError: (Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'companion_avatar',
            context: ErrorDescription('夜の地球の街明かりを読み込めなかった'),
          ),
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant CompanionAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldSpin = widget.autoSpin && !_dragging;
    if (shouldSpin && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!shouldSpin && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails _) {
    if (!widget.interactive) return;
    setState(() => _dragging = true);
    _spin.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.interactive) return;
    final scale = math.max(widget.size, 1.0);
    setState(() {
      _userLon = (_userLon - details.delta.dx / scale) % 1.0;
      if (_userLon < 0) _userLon += 1.0;
      _tilt = (_tilt + details.delta.dy / scale * 0.45).clamp(-0.35, 0.28);
    });
  }

  void _onPanEnd(DragEndDetails _) {
    if (!widget.interactive) return;
    setState(() => _dragging = false);
    if (widget.autoSpin) _spin.repeat();
  }

  double get _displayLon {
    final auto = widget.autoSpin && !_dragging ? _spin.value : 0.0;
    return (_userLon + auto) % 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.developmentLevel > 0
        ? widget.developmentLevel
        : widget.stage.minLevel;
    final size = widget.fullBleed ? math.max(widget.size, 220.0) : widget.size;
    // 小さなサムネイルでは点が潰れて白い塊になるので、密度を落とす。
    final density = (size / 220).clamp(0.35, 1.0);
    final lightCount = (EarthLights.countFor(level) * density).round();

    Widget globe = AnimatedBuilder(
      animation: _spin,
      builder: (context, _) {
        return SizedBox(
          width: size,
          height: size,
          child: ClipOval(
            child: CustomPaint(
              size: Size(size, size),
              painter: _NightGlobePainter(
                lights: _lights,
                lightCount: lightCount,
                spin: _displayLon,
                tilt: _tilt,
                mood: widget.mood,
                showSparkles:
                    widget.showSparkles || widget.launchProgress > 0,
                idleValue: widget.idleValue,
                launchProgress: widget.launchProgress,
                glow: EarthLights.glowFor(level),
              ),
            ),
          ),
        );
      },
    );

    if (widget.interactive) {
      globe = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: () {
          setState(() => _dragging = false);
          if (widget.autoSpin) _spin.repeat();
        },
        child: globe,
      );
    } else if (widget.onTap != null) {
      globe = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: globe,
      );
    }

    if (widget.fullBleed) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(
            constraints.maxWidth.isFinite ? constraints.maxWidth : size,
            constraints.maxHeight.isFinite ? constraints.maxHeight : size,
          );
          return Center(
            child: SizedBox(
              width: side * 0.92,
              height: side * 0.92,
              child: FittedBox(child: globe),
            ),
          );
        },
      );
    }

    return globe;
  }
}

/// 発展度 → 地球儀にともる街明かりの数と、大気リムの明るさ。
class EarthLights {
  EarthLights._();

  /// 「灯り都市」1つあたりに置く光点の数。都市を面として見せるための倍率。
  static const _lightsPerCity = 12;

  /// 描画コストの上限。これ以上は増やしても見た目が変わらない。
  static const _maxLights = 1400;

  /// ともる光点の数。UI に出している「灯り都市の数」と同じ指標から導く。
  static int countFor(int level) =>
      math.min(TownStats.buildingCount(level) * _lightsPerCity, _maxLights);

  /// 大気リムの明るさ（0〜1）。発展するほど地球の輪郭がはっきりする。
  static double glowFor(int level) =>
      (level / CompanionStages.stages.last.minLevel).clamp(0.0, 1.0);
}

/// 球面上の街明かり1点。毎フレームの三角関数を避けるため展開して持つ。
class _CityLight {
  final double sinLat;
  final double cosLat;
  final double sinLon;
  final double cosLon;

  /// 0〜1。大きいほど明るく、先にともる。
  final double brightness;

  /// 明るさから決まる光色（暗い灯りほど暖色）。
  final Color tone;

  const _CityLight({
    required this.sinLat,
    required this.cosLat,
    required this.sinLon,
    required this.cosLon,
    required this.brightness,
    required this.tone,
  });
}

/// 夜間光マップから街明かりの緯度経度を抽出する。結果はアプリ全体で使い回す。
class _NightLights {
  _NightLights._();

  /// 正距円筒図法（2:1）の夜間光マップ。緯度経度に直接対応する。
  static const asset = 'assets/earth/black_marble_2016.jpg';

  /// サンプリング用の縮小サイズ。2:1 を保つ。
  static const _sampleW = 720;
  static const _sampleH = 360;

  /// 1セルにつき最も明るい画素を1点だけ採用し、点が固まるのを防ぐ。
  static const _gridW = 240;
  static const _gridH = 120;

  /// これより暗い画素は街明かりとみなさない。
  static const _threshold = 0.16;

  /// 極域はオーロラや地図の継ぎ目が明るく出るので除外する。
  static const _maxLatDeg = 75.0;

  static Future<List<_CityLight>>? _pending;

  static Future<List<_CityLight>> load() => _pending ??= _sample();

  static Future<List<_CityLight>> _sample() async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: _sampleW,
      targetHeight: _sampleH,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    codec.dispose();
    if (bytes == null) {
      throw StateError('$asset の画素を読み出せなかった');
    }
    return _extract(bytes.buffer.asUint8List());
  }

  static List<_CityLight> _extract(Uint8List rgba) {
    // セルごとの最大輝度
    final peak = Float32List(_gridW * _gridH);
    for (var y = 0; y < _sampleH; y++) {
      final rowBase = y * _sampleW * 4;
      final cellRow = (y * _gridH ~/ _sampleH) * _gridW;
      for (var x = 0; x < _sampleW; x++) {
        final i = rowBase + x * 4;
        final lum = (0.2126 * rgba[i] +
                0.7152 * rgba[i + 1] +
                0.0722 * rgba[i + 2]) /
            255.0;
        if (lum < _threshold) continue;
        final cell = cellRow + (x * _gridW ~/ _sampleW);
        if (lum > peak[cell]) peak[cell] = lum;
      }
    }

    final lights = <_CityLight>[];
    for (var gy = 0; gy < _gridH; gy++) {
      final latDeg = 90.0 - (gy + 0.5) / _gridH * 180.0;
      if (latDeg.abs() > _maxLatDeg) continue;
      final lat = latDeg * math.pi / 180.0;
      final sinLat = math.sin(lat);
      final cosLat = math.cos(lat);
      for (var gx = 0; gx < _gridW; gx++) {
        final lum = peak[gy * _gridW + gx];
        if (lum <= 0) continue;
        final lon = ((gx + 0.5) / _gridW * 2 - 1) * math.pi;
        // しきい値ぶんを引き伸ばして 0〜1 に正規化する
        final brightness =
            ((lum - _threshold) / (1 - _threshold)).clamp(0.0, 1.0);
        lights.add(
          _CityLight(
            sinLat: sinLat,
            cosLat: cosLat,
            sinLon: math.sin(lon),
            cosLon: math.cos(lon),
            brightness: brightness,
            tone: Color.lerp(
              const Color(0xFFFFA726),
              const Color(0xFFFFFDE7),
              brightness,
            )!,
          ),
        );
      }
    }
    // 明るい大都市から先にともるように並べる
    lights.sort((a, b) => b.brightness.compareTo(a.brightness));
    return lights;
  }
}

/// 真っ暗な球体に街明かりを正射投影で描く。地表ディテールは出さない。
class _NightGlobePainter extends CustomPainter {
  final List<_CityLight> lights;
  final int lightCount;

  /// 自転位相（0〜1）。
  final double spin;

  /// 視点の傾き（ラジアン）。
  final double tilt;
  final CompanionMood mood;
  final bool showSparkles;
  final double idleValue;
  final double launchProgress;
  final double glow;

  _NightGlobePainter({
    required this.lights,
    required this.lightCount,
    required this.spin,
    required this.tilt,
    required this.mood,
    required this.showSparkles,
    required this.idleValue,
    required this.launchProgress,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    // 真っ暗な地球本体
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF000000));

    _paintCityLights(canvas, center, radius);
    _paintAtmosphere(canvas, center, radius);

    final moodTint = switch (mood) {
      CompanionMood.happy => const Color(0x12FFECB3),
      CompanionMood.lonely => const Color(0x121976D2),
      CompanionMood.none => const Color(0x18000000),
      CompanionMood.normal => Colors.transparent,
    };
    if (moodTint.a > 0) {
      canvas.drawCircle(center, radius, Paint()..color = moodTint);
    }

    if (showSparkles) {
      _paintSparkles(canvas, center, radius);
    }
  }

  /// 球面上の点を正射投影する。裏側（z <= 0）は描かず、
  /// 縁に近い点ほど暗く小さくすることで球体に見せる。
  void _paintCityLights(Canvas canvas, Offset center, double radius) {
    final count = math.min(lightCount, lights.length);
    if (count <= 0) return;

    final angle = spin * 2 * math.pi;
    final cosS = math.cos(angle);
    final sinS = math.sin(angle);
    final cosT = math.cos(tilt);
    final sinT = math.sin(tilt);
    final baseR = radius * 0.011;

    final core = Paint();
    final halo = Paint();

    for (var i = 0; i < count; i++) {
      final light = lights[i];
      // 経度を自転ぶん回す（加法定理で三角関数の再計算を避ける）
      final sinLon = light.sinLon * cosS + light.cosLon * sinS;
      final cosLon = light.cosLon * cosS - light.sinLon * sinS;

      final x = light.cosLat * sinLon;
      final yUp = light.sinLat;
      final zFront = light.cosLat * cosLon;

      // 視点の傾きぶん X 軸まわりに回す
      final y = yUp * cosT - zFront * sinT;
      final z = yUp * sinT + zFront * cosT;
      if (z <= 0) continue;

      // 縁ほど 0 に近づく。球面の陰影と縁での消失をこれ1つで表す。
      final limb = math.pow(z, 0.6).toDouble();
      final alpha = (0.35 + 0.65 * light.brightness) * limb;
      if (alpha <= 0.01) continue;

      final p = Offset(center.dx + x * radius, center.dy - y * radius);
      final r = math.max(
        baseR * (0.55 + 0.75 * light.brightness) * (0.6 + 0.4 * limb),
        0.4,
      );

      halo.color = light.tone.withValues(alpha: alpha * 0.22);
      canvas.drawCircle(p, r * 2.8, halo);
      core.color = light.tone.withValues(alpha: alpha);
      canvas.drawCircle(p, r, core);
    }
  }

  /// ISS から見たときのような細い大気リム。真っ暗でも球の輪郭が分かる。
  void _paintAtmosphere(Canvas canvas, Offset center, double radius) {
    final rim = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Color.lerp(
            const Color(0x3326C6DA),
            const Color(0x5582B1FF),
            0.35 + 0.4 * glow,
          )!,
          const Color(0x88E3F2FD),
        ],
        stops: const [0.86, 0.95, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, rim);

    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.03
      ..color = Color.lerp(
        const Color(0x2226C6DA),
        const Color(0x44B3E5FC),
        glow,
      )!
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.03);
    canvas.drawCircle(center, radius * 0.99, halo);
  }

  void _paintSparkles(Canvas canvas, Offset center, double radius) {
    final rnd = math.Random(42);
    final paint = Paint()
      ..color = const Color(0xAAFFF59D)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
    for (var i = 0; i < 14; i++) {
      final ang = idleValue * math.pi * 2 + i * 0.45 + launchProgress * 2;
      final r = radius * (0.55 + 0.35 * rnd.nextDouble());
      canvas.drawCircle(
        Offset(
          center.dx + math.cos(ang) * r,
          center.dy + math.sin(ang) * r * 0.78,
        ),
        0.9 + (i % 3) * 0.45,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NightGlobePainter oldDelegate) =>
      !identical(oldDelegate.lights, lights) ||
      oldDelegate.lightCount != lightCount ||
      oldDelegate.spin != spin ||
      oldDelegate.tilt != tilt ||
      oldDelegate.mood != mood ||
      oldDelegate.showSparkles != showSparkles ||
      oldDelegate.idleValue != idleValue ||
      oldDelegate.launchProgress != launchProgress ||
      oldDelegate.glow != glow;
}
