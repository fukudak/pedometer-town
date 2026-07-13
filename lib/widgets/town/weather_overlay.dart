import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants/town_atmosphere.dart';

enum _ParticleKind { rain, snow, petal, leaf }

class _Particle {
  final _ParticleKind kind;
  final double x;
  final double y;
  final double speed;
  final double size;
  final double phase;
  final double drift;

  const _Particle({
    required this.kind,
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.phase,
    required this.drift,
  });
}

/// 町マップ上に天気・季節の軽いパーティクルを描画する。
class TownWeatherOverlay extends StatefulWidget {
  final TownWeather weather;
  final TownSeason season;

  const TownWeatherOverlay({
    super.key,
    required this.weather,
    required this.season,
  });

  @override
  State<TownWeatherOverlay> createState() => _TownWeatherOverlayState();
}

class _TownWeatherOverlayState extends State<TownWeatherOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _WeatherPainter(
                weather: widget.weather,
                season: widget.season,
                progress: _controller.value,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _WeatherPainter extends CustomPainter {
  final TownWeather weather;
  final TownSeason season;
  final double progress;

  _WeatherPainter({
    required this.weather,
    required this.season,
    required this.progress,
  });

  static List<_ParticleKind> _activeKinds(
    TownWeather weather,
    TownSeason season,
  ) {
    if (weather == TownWeather.rainy) {
      return const [_ParticleKind.rain];
    }
    switch (season) {
      case TownSeason.spring:
        return const [_ParticleKind.petal];
      case TownSeason.summer:
        return const [];
      case TownSeason.autumn:
        return const [_ParticleKind.leaf];
      case TownSeason.winter:
        return const [_ParticleKind.snow];
    }
  }

  static List<_Particle> _buildParticles(
    TownWeather weather,
    TownSeason season,
  ) {
    final kinds = _activeKinds(weather, season);
    if (kinds.isEmpty) return const [];

    final seed = weather.index * 17 + season.index * 31;
    final random = math.Random(seed);
    final particles = <_Particle>[];
    const count = 14;

    for (var i = 0; i < count; i++) {
      final kind = kinds[i % kinds.length];
      particles.add(
        _Particle(
          kind: kind,
          x: random.nextDouble(),
          y: random.nextDouble(),
          speed: 0.12 + random.nextDouble() * 0.18,
          size: 1.5 + random.nextDouble() * 2.5,
          phase: random.nextDouble() * math.pi * 2,
          drift: (random.nextDouble() - 0.5) * 0.04,
        ),
      );
    }
    return particles;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final particles = _buildParticles(weather, season);
    if (particles.isEmpty) return;

    for (final particle in particles) {
      final y = ((particle.y + progress * particle.speed) % 1.2) - 0.1;
      final x = particle.x +
          math.sin(progress * math.pi * 2 + particle.phase) * particle.drift;
      final px = x * size.width;
      final py = y * size.height;

      switch (particle.kind) {
        case _ParticleKind.rain:
          final paint = Paint()
            ..color = const Color(0xFF90CAF9).withValues(alpha: 0.55)
            ..strokeWidth = 1.2;
          canvas.drawLine(
            Offset(px, py),
            Offset(px - 2, py + 8 + particle.size),
            paint,
          );
        case _ParticleKind.snow:
          final paint = Paint()
            ..color = Colors.white.withValues(alpha: 0.75)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(px, py), particle.size, paint);
        case _ParticleKind.petal:
          final paint = Paint()
            ..color = const Color(0xFFF48FB1).withValues(alpha: 0.7)
            ..style = PaintingStyle.fill;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(px, py),
              width: particle.size * 2.2,
              height: particle.size * 1.4,
            ),
            paint,
          );
        case _ParticleKind.leaf:
          final paint = Paint()
            ..color = const Color(0xFF8D6E63).withValues(alpha: 0.75)
            ..style = PaintingStyle.fill;
          canvas.save();
          canvas.translate(px, py);
          canvas.rotate(particle.phase + progress * math.pi);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: particle.size * 2.4,
              height: particle.size * 1.6,
            ),
            paint,
          );
          canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.weather != weather ||
        oldDelegate.season != season;
  }
}
