import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants/companion_stages.dart';
import '../../domain/companion_logic.dart';

/// 真っ暗な地球儀。街の明かりだけがともり、自転する。
/// 発展度（投入した電力量）に応じて明かりが増える。
///
/// 参考: NASA ISS Earth Views /
/// https://images.nasa.gov/details/NHQ_2019_0626_Earth%20Views%20from%20the%20ISS
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

  static const assetPath = 'assets/earth/iss_night_lights.jpg';

  @override
  State<CompanionAvatar> createState() => _CompanionAvatarState();
}

class _CompanionAvatarState extends State<CompanionAvatar>
    with SingleTickerProviderStateMixin {
  /// ユーザー操作による経度オフセット（0〜1）。
  double _userLon = 0.12;
  double _lat = -0.06;
  bool _dragging = false;

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
      _lat = (_lat + details.delta.dy / scale * 0.45).clamp(-0.35, 0.28);
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
    final lights = EarthLights.intensityFor(level);
    final size = widget.fullBleed
        ? math.max(widget.size, 220.0)
        : widget.size;

    Widget globe = AnimatedBuilder(
      animation: _spin,
      builder: (context, _) {
        final lon = _displayLon;
        return SizedBox(
          width: size,
          height: size,
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 真っ暗な地球本体
                const ColoredBox(color: Color(0xFF000000)),
                // 街明かりだけ（黒は透過、灯りだけ見える）
                Opacity(
                  opacity: lights.opacity,
                  child: ColorFiltered(
                    colorFilter: _cityLightsFilter(lights.boost),
                    child: ColorFiltered(
                      colorFilter: _lightsAlphaFilter,
                      child: _WrappedNightMap(
                        size: size,
                        lon: lon,
                        lat: _lat,
                      ),
                    ),
                  ),
                ),
                // 明るい都市核
                if (lights.core > 0)
                  Opacity(
                    opacity: lights.core,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Color(0xFFFFF8E1),
                        BlendMode.modulate,
                      ),
                      child: ColorFiltered(
                        colorFilter: _lightsAlphaFilter,
                        child: _WrappedNightMap(
                          size: size,
                          lon: lon,
                          lat: _lat,
                        ),
                      ),
                    ),
                  ),
                // 薄い大気リムだけで球体だと分かるようにする
                CustomPaint(
                  painter: _IssNightGlobePainter(
                    mood: widget.mood,
                    showSparkles:
                        widget.showSparkles || widget.launchProgress > 0,
                    idleValue: widget.idleValue,
                    launchProgress: widget.launchProgress,
                    level: level,
                    lights: lights.opacity,
                  ),
                ),
              ],
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

class _WrappedNightMap extends StatelessWidget {
  final double size;
  final double lon;
  final double lat;

  const _WrappedNightMap({
    required this.size,
    required this.lon,
    required this.lat,
  });

  @override
  Widget build(BuildContext context) {
    final tileW = size * 2.1;
    final tileH = size * 1.2;
    final shiftX = -lon * tileW;
    final shiftY = lat * size * 0.5;

    Widget tile() => SizedBox(
          width: tileW,
          height: tileH,
          child: Image.asset(
            CompanionAvatar.assetPath,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
        );

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        minWidth: 0,
        minHeight: 0,
        maxWidth: tileW * 3,
        maxHeight: tileH,
        child: Transform.translate(
          offset: Offset(shiftX - tileW, shiftY),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [tile(), tile(), tile()],
          ),
        ),
      ),
    );
  }
}

/// 発展度（投入した電力量の代理）→ 街明かりの強さ。
class EarthLights {
  EarthLights._();

  static ({double opacity, double boost, double core}) intensityFor(int level) {
    if (level <= 0) {
      // ほぼ真っ暗。ごくわずかな点しか出ない
      return (opacity: 0.04, boost: 1.0, core: 0.0);
    }
    final t = (level / 17.0).clamp(0.0, 2.0);
    final curved = 1 - math.exp(-3.2 * t.clamp(0.0, 1.0));
    final post = level > 17
        ? (1 - math.exp(-(level - 17) / 22.0)) * 0.08
        : 0.0;
    final opacity = (0.12 + curved * 0.88 + post).clamp(0.04, 1.0);
    final boost = 1.15 + opacity * 0.95;
    final core = ((opacity - 0.2) * 1.15).clamp(0.0, 0.9);
    return (opacity: opacity, boost: boost, core: core);
  }

  /// 互換: 旧 reveal API
  static double revealFor(int level) => intensityFor(level).opacity;
}

ColorFilter _cityLightsFilter(double boost) {
  final g = boost.clamp(0.9, 2.2);
  final lift = 6.0 * (g - 0.9);
  // 黒はそのまま、明るい画素だけ強調（真っ暗な地球＋灯り）
  return ColorFilter.matrix(<double>[
    g * 1.4, 0, 0, 0, lift,
    0, g * 1.15, 0, 0, lift * 0.55,
    0, 0, g * 0.65, 0, lift * 0.2,
    0, 0, 0, 1, 0,
  ]);
}

/// 暗い画素を透明にし、街明かりだけを残す。
const ColorFilter _lightsAlphaFilter = ColorFilter.matrix(<double>[
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0.35, 0.55, 0.25, 0, 0,
]);

/// 真っ暗な球体＋薄い大気リム。地表ディテールは出さない。
class _IssNightGlobePainter extends CustomPainter {
  final CompanionMood mood;
  final bool showSparkles;
  final double idleValue;
  final double launchProgress;
  final int level;
  final double lights;

  _IssNightGlobePainter({
    required this.mood,
    required this.showSparkles,
    required this.idleValue,
    required this.launchProgress,
    required this.level,
    required this.lights,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    // 縁だけ落とすごく弱い球面感（中心の灯りは潰さない）
    final edgeShade = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.transparent,
          const Color(0x66000000),
        ],
        stops: const [0.0, 0.72, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, edgeShade);

    // ISS風の細い大気リム
    final atmosphere = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Color.lerp(
            const Color(0x3326C6DA),
            const Color(0x5582B1FF),
            0.35 + 0.4 * lights,
          )!,
          const Color(0x88E3F2FD),
        ],
        stops: const [0.86, 0.95, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, atmosphere);

    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.03
      ..color = Color.lerp(
        const Color(0x2226C6DA),
        const Color(0x44B3E5FC),
        lights,
      )!
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.03);
    canvas.drawCircle(center, radius * 0.99, halo);

    final moodTint = switch (mood) {
      CompanionMood.happy => const Color(0x12FFECB3),
      CompanionMood.lonely => const Color(0x121976D2),
      CompanionMood.none => const Color(0x18000000),
      CompanionMood.normal => Colors.transparent,
    };
    if (moodTint.a > 0) {
      canvas.drawCircle(center, radius, Paint()..color = moodTint);
    }

    if (showSparkles || launchProgress > 0) {
      final rnd = math.Random(42);
      for (var i = 0; i < 14; i++) {
        final ang = idleValue * math.pi * 2 + i * 0.45 + launchProgress * 2;
        final r = radius * (0.55 + 0.35 * rnd.nextDouble());
        final p = Offset(
          center.dx + math.cos(ang) * r,
          center.dy + math.sin(ang) * r * 0.78,
        );
        canvas.drawCircle(
          p,
          0.9 + (i % 3) * 0.45,
          Paint()
            ..color = const Color(0xAAFFF59D)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
        );
      }
    }

    if (level >= CompanionStages.stages.last.minLevel) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.82),
        -math.pi * 0.9,
        math.pi * 0.5,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.028
          ..color = Color.lerp(
            const Color(0x5500E676),
            const Color(0xAA69F0AE),
            (0.5 + 0.5 * math.sin(idleValue * math.pi * 2 + launchProgress))
                .clamp(0.0, 1.0),
          )!,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _IssNightGlobePainter oldDelegate) =>
      oldDelegate.mood != mood ||
      oldDelegate.showSparkles != showSparkles ||
      oldDelegate.idleValue != idleValue ||
      oldDelegate.launchProgress != launchProgress ||
      oldDelegate.level != level ||
      oldDelegate.lights != lights;
}
