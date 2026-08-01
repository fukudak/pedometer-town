import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants/companion_stages.dart';
import '../../domain/companion_logic.dart';

/// 正面から見た町。家 → 街 → 工業地帯 → ロケット打ち上げまで育つ。
class CompanionAvatar extends StatelessWidget {
  final CompanionStage stage;
  final CompanionMood mood;
  final double size;
  final double idleValue;
  final double walkPhase;
  final bool facingRight;
  final bool showSparkles;
  /// 0〜1。最終段階のロケット打ち上げ進行度（片道）。
  final double launchProgress;
  /// 発展度。ロケット到達後の建物密集度に使う。
  final int developmentLevel;

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
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TownFrontPainter(
          stageId: stage.id,
          mood: mood,
          idleValue: idleValue,
          showSparkles: showSparkles,
          launchProgress: launchProgress,
          developmentLevel: developmentLevel > 0 ? developmentLevel : stage.minLevel,
        ),
      ),
    );
  }
}

class _TownFrontPainter extends CustomPainter {
  final String stageId;
  final CompanionMood mood;
  final double idleValue;
  final bool showSparkles;
  final double launchProgress;
  final int developmentLevel;

  _TownFrontPainter({
    required this.stageId,
    required this.mood,
    required this.idleValue,
    required this.showSparkles,
    required this.launchProgress,
    required this.developmentLevel,
  });

  static const _grass = Color(0xFF81C784);
  static const _road = Color(0xFF78909C);
  static const _wood = Color(0xFFA1887F);
  static const _woodDark = Color(0xFF6D4C41);
  static const _plaster = Color(0xFFEFEBE9);
  static const _shop = Color(0xFFFFCC80);
  static const _concrete = Color(0xFF90A4AE);
  static const _factory = Color(0xFF607D8B);
  static const _factoryDark = Color(0xFF455A64);
  static const _roof = Color(0xFF5D4037);
  static const _roofDark = Color(0xFF37474F);
  static const _outline = Color(0xFF3E2723);
  static const _darkWindow = Color(0xFF37474F);
  static const _litWarm = Color(0xFFFFF59D);
  static const _litHot = Color(0xFFFFCC80);
  static const _neon = Color(0xFF00E5FF);
  static const _wire = Color(0xFF455A64);
  static const _accent = Color(0xFFFFB300);
  static const _flame = Color(0xFFFF6D00);
  static const _rocket = Color(0xFFECEFF1);
  static const _pad = Color(0xFF546E7A);

  int get _tier {
    switch (stageId) {
      case 'egg':
        return 0;
      case 'crack':
        return 1;
      case 'hatch':
        return 2;
      case 'kid':
        return 3;
      case 'charged':
        return 4;
      case 'reliable':
        return 5;
      case 'radiant':
        return 6;
      case 'star':
        return 7;
      default:
        return 2;
    }
  }

  bool get _hasPower => _tier >= 2 && mood != CompanionMood.none;
  bool get _powerDim => mood == CompanionMood.lonely;

  Color get _windowLit {
    if (!_hasPower) return _darkWindow;
    if (_powerDim) return _litHot.withValues(alpha: 0.55);
    final pulse = 0.8 + 0.2 * math.sin(idleValue * math.pi * 2);
    return Color.lerp(_litHot, _litWarm, pulse)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 160);

    _paintSkyGlow(canvas);
    _paintGround(canvas);
    if (_tier >= 2) _paintHills(canvas);

    switch (_tier) {
      case 0:
        _paintEmptyLand(canvas);
      case 1:
        // 小さな家（まだ暗い）
        _paintHouse(canvas, const Offset(0, 18), floors: 1, lit: false, width: 36);
      case 2:
        // 電灯の村
        _paintHouse(canvas, const Offset(-40, 18), floors: 1, lit: true, width: 30);
        _paintHouse(canvas, const Offset(0, 14), floors: 1, lit: true, width: 36);
        _paintHouse(canvas, const Offset(42, 18), floors: 1, lit: true, width: 28);
        _paintStreetLamp(canvas, const Offset(-18, 28));
        _paintStreetLamp(canvas, const Offset(22, 28));
        _paintPole(canvas, const Offset(-28, 30));
        _paintPole(canvas, const Offset(28, 30));
        _paintWire(canvas, const Offset(-28, -8), const Offset(28, -8));
      case 3:
        // にぎわう街
        _paintHouse(canvas, const Offset(-54, 16), floors: 1, lit: true, width: 28);
        _paintShop(canvas, const Offset(-18, 12));
        _paintHouse(canvas, const Offset(20, 10), floors: 2, lit: true, width: 36);
        _paintHouse(canvas, const Offset(54, 16), floors: 1, lit: true, width: 28);
        _paintFullWires(canvas, poles: [-40.0, 0.0, 40.0]);
        _paintStreetLamp(canvas, const Offset(-30, 28));
        _paintStreetLamp(canvas, const Offset(8, 28));
        _paintStreetLamp(canvas, const Offset(44, 28));
      case 4:
        // ビルの街
        _paintHouse(canvas, const Offset(-56, 12), floors: 2, lit: true, width: 28);
        _paintShop(canvas, const Offset(-24, 10));
        _paintHouse(canvas, const Offset(10, -2), floors: 4, lit: true, width: 40);
        _paintHouse(canvas, const Offset(50, 6), floors: 3, lit: true, width: 32);
        _paintFullWires(canvas, poles: [-48.0, -8.0, 32.0, 58.0]);
        for (final x in [-36.0, -4.0, 28.0, 54.0]) {
          _paintStreetLamp(canvas, Offset(x, 28));
        }
        _paintTownGlow(canvas, strong: false);
      case 5:
        // 工業地帯
        _paintHouse(canvas, const Offset(-58, 14), floors: 2, lit: true, width: 24);
        _paintFactory(canvas, const Offset(-20, 8), stacks: 2);
        _paintFactory(canvas, const Offset(28, 4), stacks: 3, wide: true);
        _paintHouse(canvas, const Offset(58, 14), floors: 2, lit: true, width: 24);
        _paintFullWires(canvas, poles: [-44.0, -4.0, 36.0]);
        _paintStreetLamp(canvas, const Offset(-34, 28));
        _paintStreetLamp(canvas, const Offset(48, 28));
        _paintTownGlow(canvas, strong: false);
        _paintIndustrialSmoke(canvas);
      case 6:
        // 宇宙基地（工場＋発射台）
        _paintFactory(canvas, const Offset(-48, 10), stacks: 2);
        _paintLab(canvas, const Offset(-10, 6));
        _paintLaunchPad(canvas, const Offset(36, 20), withRocket: true, launching: false);
        _paintFullWires(canvas, poles: [-56.0, -20.0, 12.0, 52.0]);
        _paintTownGlow(canvas, strong: true);
        _paintBeacon(canvas, const Offset(-10, -36));
      default:
        // ロケット打ち上げ（到達後は建物が増えて密集）
        _paintPostRocketSkyline(canvas);
        _paintFullWires(canvas, poles: [-60.0, -28.0, 4.0]);
        _paintTownGlow(canvas, strong: true);
        _paintExhaustClouds(canvas);
    }

    if (showSparkles || _tier >= 6) {
      _paintSparks(canvas);
    }

    canvas.restore();
  }

  void _paintSkyGlow(Canvas canvas) {
    if (!_hasPower) return;
    final alpha = _tier >= 6 ? 0.2 : (_tier >= 4 ? 0.12 : 0.07);
    canvas.drawCircle(
      const Offset(0, -24),
      72,
      Paint()
        ..color = (_tier >= 6 ? _neon : _litWarm).withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
  }

  void _paintGround(Canvas canvas) {
    final groundColor = _tier >= 5
        ? const Color(0xFF78909C).withValues(alpha: 0.45)
        : _grass.withValues(alpha: 0.55);
    canvas.drawRect(const Rect.fromLTRB(-80, 36, 80, 70), Paint()..color = groundColor);
    if (_tier >= 2) {
      canvas.drawRect(
        const Rect.fromLTRB(-80, 42, 80, 52),
        Paint()..color = _road.withValues(alpha: 0.55),
      );
      final dash = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 1.2;
      for (var x = -70.0; x < 70; x += 14) {
        canvas.drawLine(Offset(x, 47), Offset(x + 7, 47), dash);
      }
    }
  }

  void _paintHills(Canvas canvas) {
    final hill = Path()
      ..moveTo(-80, 40)
      ..quadraticBezierTo(-40, 10, 0, 28)
      ..quadraticBezierTo(40, 8, 80, 36)
      ..lineTo(80, 40)
      ..close();
    canvas.drawPath(
      hill,
      Paint()..color = const Color(0xFF66BB6A).withValues(alpha: _tier >= 5 ? 0.12 : 0.25),
    );
  }

  void _paintPostRocketSkyline(Canvas canvas) {
    final growth = developmentLevel <= 17 ? 0 : developmentLevel - 17;
    // 背景に増える細かい建物（ロケット後のみ密度アップ）
    final extras = (growth * 1.2).clamp(0, 14).round();
    for (var i = 0; i < extras; i++) {
      final x = -70.0 + (i * 11) % 140;
      final floors = 1 + (i % 4);
      _paintHouse(
        canvas,
        Offset(x, 16 - floors.toDouble()),
        floors: floors,
        lit: true,
        width: 14 + (i % 3) * 2,
      );
    }
    _paintFactory(canvas, const Offset(-54, 12), stacks: 1 + (growth > 3 ? 1 : 0));
    _paintLab(canvas, const Offset(-22, 8));
    _paintHouse(canvas, const Offset(8, 10), floors: 2 + (growth > 6 ? 1 : 0), lit: true, width: 26);
    _paintLaunchPad(canvas, const Offset(42, 22), withRocket: true, launching: true);
    if (growth > 0) {
      _paintFactory(canvas, const Offset(62, 14), stacks: 1, wide: false);
    }
  }

  void _paintEmptyLand(Canvas canvas) {
    final p = Paint()
      ..color = const Color(0xFF558B2F)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final x in [-40.0, -20.0, 0.0, 24.0, 44.0]) {
      canvas.drawLine(Offset(x, 40), Offset(x - 3, 30), p);
      canvas.drawLine(Offset(x, 40), Offset(x + 3, 28), p);
    }
  }

  void _paintHouse(
    Canvas canvas,
    Offset base, {
    required int floors,
    required bool lit,
    required double width,
  }) {
    final floorH = 15.0;
    final h = floors * floorH + 6;
    final wall = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(base.dx, base.dy - h / 2 + 10), width: width, height: h),
      const Radius.circular(2),
    );
    final color = floors >= 3 ? _concrete : (floors >= 2 ? _plaster : _wood);
    canvas.drawRRect(wall, Paint()..color = color);
    _strokeRRect(canvas, wall);

    final top = base.dy - h + 10;
    if (floors >= 3) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(base.dx, top - 3), width: width + 4, height: 8),
          const Radius.circular(1),
        ),
        Paint()..color = _roofDark,
      );
    } else {
      final roof = Path()
        ..moveTo(base.dx - width / 2 - 4, top + 2)
        ..lineTo(base.dx, top - 14)
        ..lineTo(base.dx + width / 2 + 4, top + 2)
        ..close();
      canvas.drawPath(roof, Paint()..color = _roof);
      canvas.drawPath(
        roof,
        Paint()
          ..color = _outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    for (var f = 0; f < floors; f++) {
      final y = base.dy - 4 - f * floorH;
      if (width > 34) {
        _paintWindow(canvas, Offset(base.dx - 9, y), lit: lit, w: 8, h: 8);
        _paintWindow(canvas, Offset(base.dx + 9, y), lit: lit, w: 8, h: 8);
      } else {
        _paintWindow(canvas, Offset(base.dx, y), lit: lit, w: 9, h: 8);
      }
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(base.dx, base.dy + 4), width: 8, height: 12),
        const Radius.circular(1),
      ),
      Paint()..color = _woodDark,
    );
  }

  void _paintShop(Canvas canvas, Offset base) {
    final wall = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(base.dx, base.dy - 6), width: 38, height: 32),
      const Radius.circular(2),
    );
    canvas.drawRRect(wall, Paint()..color = _shop);
    _strokeRRect(canvas, wall);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(base.dx, base.dy - 22), width: 42, height: 8),
        const Radius.circular(1),
      ),
      Paint()..color = _accent,
    );
    final win = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(base.dx, base.dy - 4), width: 26, height: 12),
      const Radius.circular(2),
    );
    canvas.drawRRect(win, Paint()..color = _windowLit);
    canvas.drawRRect(
      win,
      Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  void _paintFactory(Canvas canvas, Offset base, {required int stacks, bool wide = false}) {
    final w = wide ? 52.0 : 40.0;
    final h = wide ? 42.0 : 36.0;
    final wall = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(base.dx, base.dy - h / 2 + 12), width: w, height: h),
      const Radius.circular(2),
    );
    canvas.drawRRect(wall, Paint()..color = _factory);
    _strokeRRect(canvas, wall);

    // 帯パネル
    canvas.drawRect(
      Rect.fromCenter(center: Offset(base.dx, base.dy - 4), width: w * 0.7, height: 6),
      Paint()..color = _factoryDark,
    );

    // 小さな明かり窓
    for (var i = 0; i < 3; i++) {
      _paintWindow(
        canvas,
        Offset(base.dx - w * 0.25 + i * w * 0.25, base.dy - 14),
        lit: true,
        w: 7,
        h: 6,
      );
    }

    // 煙突
    for (var i = 0; i < stacks; i++) {
      final sx = base.dx - (stacks - 1) * 8 + i * 16;
      final top = base.dy - h + 4;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(sx, top - 14), width: 8, height: 28),
        Paint()..color = _factoryDark,
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(sx, top - 28), width: 12, height: 5),
        Paint()..color = _outline,
      );
    }
  }

  void _paintLab(Canvas canvas, Offset base) {
    final wall = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(base.dx, base.dy - 10), width: 36, height: 40),
      const Radius.circular(3),
    );
    canvas.drawRRect(wall, Paint()..color = const Color(0xFFB0BEC5));
    _strokeRRect(canvas, wall);
    // ドーム
    canvas.drawArc(
      Rect.fromCenter(center: Offset(base.dx, base.dy - 30), width: 28, height: 22),
      math.pi,
      math.pi,
      true,
      Paint()..color = _neon.withValues(alpha: 0.55),
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(base.dx, base.dy - 30), width: 28, height: 22),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _paintWindow(canvas, Offset(base.dx - 8, base.dy - 6), lit: true, w: 8, h: 10);
    _paintWindow(canvas, Offset(base.dx + 8, base.dy - 6), lit: true, w: 8, h: 10);
  }

  void _paintLaunchPad(Canvas canvas, Offset base, {required bool withRocket, required bool launching}) {
    // 台座
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: base, width: 44, height: 10),
        const Radius.circular(2),
      ),
      Paint()..color = _pad,
    );
    // 塔（ガントリー）
    canvas.drawRect(
      Rect.fromCenter(center: Offset(base.dx - 16, base.dy - 28), width: 6, height: 48),
      Paint()..color = _factoryDark,
    );
    canvas.drawLine(
      Offset(base.dx - 13, base.dy - 40),
      Offset(base.dx - 2, base.dy - 36),
      Paint()
        ..color = _concrete
        ..strokeWidth = 2,
    );

    if (!withRocket) return;

    final lift = Curves.easeIn.transform(launchProgress.clamp(0.0, 1.0));
    final rocketY = launching
        ? base.dy - 36 - 90 * lift
        : base.dy - 36;
    _paintRocket(canvas, Offset(base.dx + 4, rocketY), launching: launching && launchProgress > 0.02);
  }

  void _paintRocket(Canvas canvas, Offset c, {required bool launching}) {
    // 胴体
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: 14, height: 36),
      const Radius.circular(4),
    );
    canvas.drawRRect(body, Paint()..color = _rocket);
    canvas.drawRRect(
      body,
      Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // 窓
    canvas.drawCircle(Offset(c.dx, c.dy - 6), 3, Paint()..color = _neon);
    // 先端
    final nose = Path()
      ..moveTo(c.dx - 7, c.dy - 18)
      ..lineTo(c.dx, c.dy - 30)
      ..lineTo(c.dx + 7, c.dy - 18)
      ..close();
    canvas.drawPath(nose, Paint()..color = const Color(0xFFE57373));
    // フィン
    final finL = Path()
      ..moveTo(c.dx - 7, c.dy + 10)
      ..lineTo(c.dx - 16, c.dy + 18)
      ..lineTo(c.dx - 7, c.dy + 16)
      ..close();
    final finR = Path()
      ..moveTo(c.dx + 7, c.dy + 10)
      ..lineTo(c.dx + 16, c.dy + 18)
      ..lineTo(c.dx + 7, c.dy + 16)
      ..close();
    canvas.drawPath(finL, Paint()..color = _accent);
    canvas.drawPath(finR, Paint()..color = _accent);

    if (launching) {
      // 噴射
      final flameLen = 18 + 8 * math.sin(idleValue * math.pi * 4);
      final flame = Path()
        ..moveTo(c.dx - 5, c.dy + 18)
        ..lineTo(c.dx, c.dy + 18 + flameLen)
        ..lineTo(c.dx + 5, c.dy + 18)
        ..close();
      canvas.drawPath(flame, Paint()..color = _flame);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - 2.5, c.dy + 18)
          ..lineTo(c.dx, c.dy + 18 + flameLen * 0.65)
          ..lineTo(c.dx + 2.5, c.dy + 18)
          ..close(),
        Paint()..color = _litWarm,
      );
    }
  }

  void _paintIndustrialSmoke(Canvas canvas) {
    final t = idleValue * math.pi * 2;
    for (var i = 0; i < 5; i++) {
      final x = -28.0 + i * 14 + 2 * math.sin(t + i);
      final y = -42.0 - i * 5 - 3 * math.cos(t * 0.7 + i);
      canvas.drawCircle(
        Offset(x, y),
        5.0 + i * 0.8,
        Paint()..color = Colors.white.withValues(alpha: 0.28 - i * 0.03),
      );
    }
  }

  void _paintExhaustClouds(Canvas canvas) {
    final t = idleValue * math.pi * 2;
    for (var i = 0; i < 6; i++) {
      final x = 30.0 + i * 6 + 4 * math.sin(t + i);
      final y = 28.0 - i * 3;
      canvas.drawCircle(
        Offset(x, y),
        6.0 + i * 1.2,
        Paint()..color = Colors.white.withValues(alpha: 0.35 - i * 0.04),
      );
    }
  }

  void _paintWindow(Canvas canvas, Offset c, {required bool lit, double w = 10, double h = 9}) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: w, height: h),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(rect, Paint()..color = lit ? _windowLit : _darkWindow);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = _outline.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    if (lit && _hasPower) {
      canvas.drawCircle(
        c,
        w * 0.7,
        Paint()
          ..color = _litWarm.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  void _paintPole(Canvas canvas, Offset base) {
    canvas.drawLine(
      base,
      Offset(base.dx, base.dy - 40),
      Paint()
        ..color = _woodDark
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(base.dx - 8, base.dy - 38),
      Offset(base.dx + 8, base.dy - 38),
      Paint()
        ..color = _woodDark
        ..strokeWidth = 2.2,
    );
    if (_hasPower) {
      final pulse = 0.6 + 0.4 * math.sin(idleValue * math.pi * 2 + base.dx);
      canvas.drawCircle(
        Offset(base.dx, base.dy - 42),
        2.4,
        Paint()..color = _accent.withValues(alpha: pulse),
      );
    }
  }

  void _paintWire(Canvas canvas, Offset a, Offset b) {
    final mid = Offset((a.dx + b.dx) / 2, math.max(a.dy, b.dy) + 8);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = _wire
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    if (_hasPower) {
      final t = (idleValue + (a.dx + 80) / 160) % 1.0;
      final x = _quad(a.dx, mid.dx, b.dx, t);
      final y = _quad(a.dy, mid.dy, b.dy, t);
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = _neon.withValues(alpha: 0.85));
    }
  }

  double _quad(double p0, double p1, double p2, double t) {
    final u = 1 - t;
    return u * u * p0 + 2 * u * t * p1 + t * t * p2;
  }

  void _paintFullWires(Canvas canvas, {required List<double> poles}) {
    for (final x in poles) {
      _paintPole(canvas, Offset(x, 30));
    }
    for (var i = 0; i < poles.length - 1; i++) {
      _paintWire(canvas, Offset(poles[i], -10), Offset(poles[i + 1], -10));
    }
  }

  void _paintStreetLamp(Canvas canvas, Offset base) {
    canvas.drawLine(
      base,
      Offset(base.dx, base.dy - 22),
      Paint()
        ..color = _concrete
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(base.dx, base.dy - 22),
      Offset(base.dx + 6, base.dy - 20),
      Paint()
        ..color = _concrete
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    final lit = _hasPower;
    canvas.drawCircle(
      Offset(base.dx + 6, base.dy - 18),
      3.2,
      Paint()..color = lit ? _windowLit : _darkWindow,
    );
    if (lit) {
      canvas.drawCircle(
        Offset(base.dx + 6, base.dy - 14),
        8,
        Paint()
          ..color = _litWarm.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  void _paintTownGlow(Canvas canvas, {required bool strong}) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 20), width: 140, height: 36),
      Paint()
        ..color = _litWarm.withValues(alpha: strong ? 0.22 : 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }

  void _paintBeacon(Canvas canvas, Offset c) {
    canvas.drawCircle(c, 5, Paint()..color = _neon);
    canvas.drawCircle(
      c,
      12 + 3 * math.sin(idleValue * math.pi * 2),
      Paint()
        ..color = _neon.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  void _paintSparks(Canvas canvas) {
    final t = idleValue * math.pi * 2;
    final pts = [
      Offset(-55, -25 + 2 * math.sin(t)),
      Offset(58, -18 + 2 * math.cos(t)),
      const Offset(-30, -40),
      const Offset(35, -50),
    ];
    for (var i = 0; i < pts.length; i++) {
      final a = 0.35 + 0.4 * (0.5 + 0.5 * math.sin(t + i));
      canvas.drawCircle(pts[i], 2 + i % 2, Paint()..color = _accent.withValues(alpha: a));
    }
  }

  void _strokeRRect(Canvas canvas, RRect r) {
    canvas.drawRRect(
      r,
      Paint()
        ..color = _outline.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _TownFrontPainter oldDelegate) {
    return oldDelegate.stageId != stageId ||
        oldDelegate.mood != mood ||
        oldDelegate.idleValue != idleValue ||
        oldDelegate.showSparkles != showSparkles ||
        oldDelegate.launchProgress != launchProgress ||
        oldDelegate.developmentLevel != developmentLevel;
  }
}
