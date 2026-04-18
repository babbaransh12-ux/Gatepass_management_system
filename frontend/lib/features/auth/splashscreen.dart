import 'dart:async';
import 'dart:math' as math;

import 'package:e_gatepass/core/navigation/role_router.dart';
import 'package:e_gatepass/core/services/auth_service.dart';
import 'package:flutter/material.dart';

import 'loginscreen.dart';

// ── Brand Palette (matches app theme) ───────────────────────────────────────
class _C {
  static const deepNavy    = Color(0xFF0A0F2E);   // darkest background
  static const navyBlue    = Color(0xFF12183D);   // mid background
  static const royalBlue   = Color(0xFF2D5AF0);   // primary — matches main.dart
  static const violet      = Color(0xFF7B4DFF);   // secondary — matches login gradient
  static const lavender    = Color(0xFFA78BFA);   // light accent
  static const mist        = Color(0xFFE8F0FE);   // text / mist
}

// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ── Animation Controllers ─────────────────────────────────────────────────
  late AnimationController _bgCtrl;          // background gradient drift
  late AnimationController _gridCtrl;        // grid pulse
  late AnimationController _radarCtrl;       // radar rings expand
  late AnimationController _shieldCtrl;      // shield float + reveal
  late AnimationController _scanCtrl;        // scan-line sweep
  late AnimationController _checkCtrl;       // check-mark draw
  late AnimationController _textCtrl;        // app name slide-up
  late AnimationController _loaderCtrl;      // progress bar
  late AnimationController _particleCtrl;    // floating particles

  // ── Derived Animations ────────────────────────────────────────────────────
  late Animation<double> _shieldScale;
  late Animation<double> _shieldOpacity;
  late Animation<double> _scanLine;
  late Animation<double> _checkDraw;
  late Animation<double> _checkOpacity;
  late Animation<double> _scanOpacity;
  late Animation<Alignment> _bgAlign;
  late Animation<double> _textSlide;
  late Animation<double> _textOpacity;
  late Animation<double> _loader;
  late Animation<double> _taglineOpacity;

  // ── State flags ───────────────────────────────────────────────────────────
  bool _showParticles = false;
  String? _role;

  final List<_Particle> _particles = [];
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _buildParticles();
    _initControllers();
    _startSequence();
    _fetchRole();
  }

  // ── Build random floating particles ──────────────────────────────────────
  void _buildParticles() {
    for (int i = 0; i < 22; i++) {
      _particles.add(_Particle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        size: _rng.nextDouble() * 3 + 1,
        speed: _rng.nextDouble() * 0.4 + 0.1,
        opacity: _rng.nextDouble() * 0.5 + 0.1,
        phase: _rng.nextDouble() * math.pi * 2,
      ));
    }
  }

  // ── Initialise every controller + tween ──────────────────────────────────
  void _initControllers() {
    // Background colour drift
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    _bgAlign = AlignmentTween(begin: Alignment.topLeft, end: Alignment.bottomRight).animate(
      CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut),
    );

    // Grid flicker
    _gridCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

    // Radar rings (loop)
    _radarCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

    // Particle drift
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

    // Shield (scale-in + float loop)
    _shieldCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _shieldScale   = CurvedAnimation(parent: _shieldCtrl, curve: Curves.elasticOut);
    _shieldOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shieldCtrl, curve: const Interval(0, 0.4, curve: Curves.easeIn)),
    );
    // Scan line sweep
    _scanCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scanLine  = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut),
    );
    _scanOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1, end: 1), weight: 75),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 15),
    ]).animate(_scanCtrl);

    // Check-mark draw
    _checkCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _checkDraw    = CurvedAnimation(parent: _checkCtrl, curve: Curves.easeOut);
    _checkOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _checkCtrl, curve: const Interval(0, 0.3, curve: Curves.easeIn)),
    );

    // Text slide-up
    _textCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _textSlide   = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut),
    );
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn),
    );
    _taglineOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textCtrl, curve: const Interval(0.5, 1, curve: Curves.easeIn)),
    );

    // Progress loader
    _loaderCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
    _loader = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _loaderCtrl, curve: Curves.easeInOut),
    );
  }

  // ── Animation sequence (choreographed) ───────────────────────────────────
  void _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));

    // Phase 1 – Shield enters
    _shieldCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));

    // Phase 2 – Scan begins + loader starts
    setState(() => _showParticles = true);
    _scanCtrl.forward();
    _loaderCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1000));

    // Phase 3 – Checkmark draws
    _checkCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));

    // Phase 4 – Text reveals
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1500));

    // Phase 5 – Navigate
    _navigate();
  }

  void _fetchRole() async {
    _role = await AuthService.getRole();
  }

  void _navigate() {
    if (!mounted) return;
    if (_role != null) {
      RoleRouter.navigate(context, _role!);
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (ctx2, anim, sec) => LoginScreen(),
          transitionsBuilder: (ctx2, anim, sec, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _gridCtrl.dispose();
    _radarCtrl.dispose();
    _shieldCtrl.dispose();
    _scanCtrl.dispose();
    _checkCtrl.dispose();
    _textCtrl.dispose();
    _loaderCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _C.deepNavy,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _bgCtrl, _gridCtrl, _radarCtrl, _shieldCtrl,
          _scanCtrl, _checkCtrl, _textCtrl, _loaderCtrl, _particleCtrl,
        ]),
        builder: (ctx, _) => Stack(
          children: [

            // ── 1. Background gradient ──────────────────────────────────────
            _BgGradient(align: _bgAlign.value),

            // ── 2. Grid ────────────────────────────────────────────────────
            _GridPainter(opacity: 0.06 + _gridCtrl.value * 0.035),

            // ── 3. Radar rings ─────────────────────────────────────────────
            _RadarRings(progress: _radarCtrl.value, size: size),

            // ── 4. Floating particles ──────────────────────────────────────
            if (_showParticles)
              _ParticleLayer(
                particles: _particles,
                t: _particleCtrl.value,
                size: size,
              ),

            // ── 5. Core shield + scan + check ──────────────────────────────
            Center(
              child: _buildHeroShield(size),
            ),

            // ── 6. Text block ──────────────────────────────────────────────
            _buildTextBlock(size),

            // ── 7. Progress bar ────────────────────────────────────────────
            _buildProgressBar(size),

            // ── 8. Corner branding ─────────────────────────────────────────
            _buildCornerBranding(),
          ],
        ),
      ),
    );
  }

  // ── Hero shield widget ────────────────────────────────────────────────────
  Widget _buildHeroShield(Size size) {
    // Float: oscillate ±8 px
    final floatOffset = math.sin(_particleCtrl.value * math.pi * 2) * 8.0;
    const shieldSize = 160.0;

    return Transform.translate(
      offset: Offset(0, floatOffset - 40),
      child: Opacity(
        opacity: _shieldOpacity.value,
        child: Transform.scale(
          scale: _shieldScale.value,
          child: Stack(
            alignment: Alignment.center,
            children: [

              // Glow halo — blue-violet radial
              Container(
                width: shieldSize + 70,
                height: shieldSize + 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _C.royalBlue.withValues(alpha: 0.22),
                      _C.violet.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // Shield body (custom painter)
              SizedBox(
                width: shieldSize,
                height: shieldSize,
                child: CustomPaint(
                  painter: _ShieldPainter(
                    scanProgress: _scanCtrl.value,
                    scanLineY: _scanLine.value,
                    scanOpacity: _scanOpacity.value,
                    checkProgress: _checkDraw.value,
                    checkOpacity: _checkOpacity.value,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Text block ────────────────────────────────────────────────────────────
  Widget _buildTextBlock(Size size) {
    return Positioned(
      bottom: size.height * 0.22,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: _textOpacity.value,
        child: Transform.translate(
          offset: Offset(0, _textSlide.value),
          child: Column(
            children: [
              // App name
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [_C.mist, _C.royalBlue],
                ).createShader(r),
                child: const Text(
                  'E-GatePass',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Opacity(
                opacity: _taglineOpacity.value,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 28, height: 1.5, color: _C.lavender),
                    const SizedBox(width: 10),
                    const Text(
                      'Smart Access · Secure Campus',
                      style: TextStyle(
                        color: _C.lavender,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(width: 28, height: 1.5, color: _C.lavender),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Progress bar ──────────────────────────────────────────────────────────
  Widget _buildProgressBar(Size size) {
    return Positioned(
      bottom: size.height * 0.1,
      left: size.width * 0.18,
      right: size.width * 0.18,
      child: Column(
        children: [
          // Label
          Opacity(
            opacity: _loader.value.clamp(0.0, 1.0),
            child: Text(
              _loaderLabel(_loader.value),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Track
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _loader.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [_C.royalBlue, _C.violet],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _C.violet.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _loaderLabel(double v) {
    if (v < 0.3) return 'INITIALISING SECURITY…';
    if (v < 0.6) return 'VERIFYING CREDENTIALS…';
    if (v < 0.9) return 'LOADING DASHBOARD…';
    return 'ACCESS GRANTED';
  }

  // ── Corner version tag ────────────────────────────────────────────────────
  Widget _buildCornerBranding() {
    return Positioned(
      bottom: 24,
      right: 24,
      child: Opacity(
        opacity: 0.35,
        child: Row(
          children: [
            Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(color: _C.lavender, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            const Text(
              'v1.0.0',
              style: TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background gradient widget
// ─────────────────────────────────────────────────────────────────────────────
class _BgGradient extends StatelessWidget {
  final Alignment align;
  const _BgGradient({required this.align});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: align,
          radius: 1.8,
          colors: const [
            Color(0xFF1A2468),   // royal-blue tinted deep
            Color(0xFF0D1242),   // deep indigo-navy
            Color(0xFF0A0F2E),   // almost black
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid painter
// ─────────────────────────────────────────────────────────────────────────────
class _GridPainter extends StatelessWidget {
  final double opacity;
  const _GridPainter({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridCustomPainter(opacity: opacity),
      child: const SizedBox.expand(),
    );
  }
}

class _GridCustomPainter extends CustomPainter {
  final double opacity;
  _GridCustomPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2D5AF0).withValues(alpha: opacity)
      ..strokeWidth = 0.5;
    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridCustomPainter old) => old.opacity != opacity;
}

// ─────────────────────────────────────────────────────────────────────────────
// Radar rings
// ─────────────────────────────────────────────────────────────────────────────
class _RadarRings extends StatelessWidget {
  final double progress;
  final Size size;
  const _RadarRings({required this.progress, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RadarPainter(progress: progress),
      child: const SizedBox.expand(),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  _RadarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final maxRadius = size.width * 0.65;

    for (int i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1.0;
      final radius = phase * maxRadius;
      final opacity = (1.0 - phase) * 0.22;
      // Outer rings: blue, inner rings: violet blend
      final ringColor = Color.lerp(
        const Color(0xFF2D5AF0), const Color(0xFF7B4DFF), phase)!;
      final paint = Paint()
        ..color = ringColor.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Particle layer
// ─────────────────────────────────────────────────────────────────────────────
class _Particle {
  final double x, y, size, speed, opacity, phase;
  _Particle({
    required this.x, required this.y, required this.size,
    required this.speed, required this.opacity, required this.phase,
  });
}

class _ParticleLayer extends StatelessWidget {
  final List<_Particle> particles;
  final double t;
  final Size size;
  const _ParticleLayer({required this.particles, required this.t, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ParticlePainter(particles: particles, t: t),
      child: const SizedBox.expand(),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ParticlePainter({required this.particles, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final floatY = p.y - (t * p.speed) % 1.0;
      final y = floatY < 0 ? floatY + 1.0 : floatY;
      final particleColor = (p.phase % (math.pi * 2) < math.pi)
          ? const Color(0xFF2D5AF0)
          : const Color(0xFF7B4DFF);
      final paint = Paint()
        ..color = particleColor.withValues(alpha: p.opacity * (0.6 + 0.4 * math.sin(t * math.pi * 2 + p.phase)));
      canvas.drawCircle(Offset(p.x * size.width, y * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shield custom painter — the centrepiece
// ─────────────────────────────────────────────────────────────────────────────
class _ShieldPainter extends CustomPainter {
  final double scanProgress;
  final double scanLineY;
  final double scanOpacity;
  final double checkProgress;
  final double checkOpacity;

  _ShieldPainter({
    required this.scanProgress,
    required this.scanLineY,
    required this.scanOpacity,
    required this.checkProgress,
    required this.checkOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // ── Shield outline path ──────────────────────────────────────────────────
    final shieldPath = Path()
      ..moveTo(cx, h * 0.04)
      ..lineTo(w * 0.9, h * 0.18)
      ..lineTo(w * 0.9, h * 0.55)
      ..cubicTo(w * 0.9, h * 0.78, cx, h * 0.97, cx, h * 0.97)
      ..cubicTo(cx, h * 0.97, w * 0.1, h * 0.78, w * 0.1, h * 0.55)
      ..lineTo(w * 0.1, h * 0.18)
      ..close();

    // Fill gradient — blue to violet matching app theme
    final gradPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF1E3A8A),   // deep royal blue
          const Color(0xFF3730A3),   // indigo
          const Color(0xFF4C1D95),   // deep violet
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(shieldPath, gradPaint);

    // Stroke — royal blue glow
    final strokePaint = Paint()
      ..color = const Color(0xFF2D5AF0).withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(shieldPath, strokePaint);

    // Inner highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final innerPath = Path()
      ..moveTo(cx, h * 0.08)
      ..lineTo(w * 0.84, h * 0.21)
      ..lineTo(w * 0.84, h * 0.54)
      ..cubicTo(w * 0.84, h * 0.74, cx, h * 0.91, cx, h * 0.91)
      ..cubicTo(cx, h * 0.91, w * 0.16, h * 0.74, w * 0.16, h * 0.54)
      ..lineTo(w * 0.16, h * 0.21)
      ..close();
    canvas.drawPath(innerPath, highlightPaint);

    // ── Clip subsequent drawing to shield shape ────────────────────────────
    canvas.save();
    canvas.clipPath(shieldPath);

    // ── Gate arch inside shield ────────────────────────────────────────────
    _drawGateArch(canvas, size);

    // ── Scan line sweep ────────────────────────────────────────────────────
    if (scanProgress > 0 && scanOpacity > 0) {
      _drawScanLine(canvas, size);
    }

    canvas.restore();

    // ── Check mark (drawn outside clip so it sits on top) ─────────────────
    if (checkProgress > 0) {
      _drawCheckMark(canvas, size);
    }

    // ── Corner accents ────────────────────────────────────────────────────
    _drawCornerAccents(canvas, size);
  }

  void _drawGateArch(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final gateW = w * 0.32;
    final gateH = h * 0.35;
    final gateTop = h * 0.30;
    final gateBottom = h * 0.72;

    final gatePaint = Paint()
      ..color = const Color(0xFF2D5AF0).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Left pillar
    canvas.drawLine(
      Offset(cx - gateW, gateBottom),
      Offset(cx - gateW, gateTop + gateW),
      gatePaint,
    );
    // Right pillar
    canvas.drawLine(
      Offset(cx + gateW, gateBottom),
      Offset(cx + gateW, gateTop + gateW),
      gatePaint,
    );
    // Floor
    canvas.drawLine(
      Offset(cx - gateW, gateBottom),
      Offset(cx + gateW, gateBottom),
      gatePaint,
    );
    // Arch
    final archRect = Rect.fromCenter(
      center: Offset(cx, gateTop + gateW),
      width: gateW * 2,
      height: gateW * 2,
    );
    canvas.drawArc(archRect, math.pi, math.pi, false, gatePaint);

    // Lock body inside gate — violet accent
    final lockPaint = Paint()
      ..color = const Color(0xFF7B4DFF).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final lockBodyRect = Rect.fromCenter(
      center: Offset(cx, gateTop + gateH * 0.62),
      width: gateW * 0.7,
      height: gateH * 0.35,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lockBodyRect, const Radius.circular(4)),
      lockPaint,
    );
    // Lock shackle
    final shackleRect = Rect.fromCenter(
      center: Offset(cx, lockBodyRect.top),
      width: gateW * 0.38,
      height: gateH * 0.22,
    );
    canvas.drawArc(shackleRect, math.pi, math.pi, false, lockPaint);
  }

  void _drawScanLine(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final lineY = (scanLineY + 1) / 2 * h;

    // Glow beam — royal blue to violet matching app gradient
    final beamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          const Color(0xFF2D5AF0).withValues(alpha: scanOpacity * 0.9),
          const Color(0xFF7B4DFF).withValues(alpha: scanOpacity),
          const Color(0xFF2D5AF0).withValues(alpha: scanOpacity * 0.9),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, lineY - 6, w, 12));

    canvas.drawRect(
      Rect.fromLTWH(0, lineY - 6, w, 12),
      beamPaint,
    );

    // Thin centre line — violet
    final linePaint = Paint()
      ..color = const Color(0xFF7B4DFF).withValues(alpha: scanOpacity)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(0, lineY), Offset(w, lineY), linePaint);
  }

  void _drawCheckMark(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h * 0.5;
    const r = 22.0;

    // Success circle — royal blue to violet gradient, fades in with checkOpacity
    canvas.saveLayer(
      Rect.fromCircle(center: Offset(cx, cy), radius: r + 10),
      Paint()..color = Colors.white.withValues(alpha: checkOpacity),
    );
    final circlePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF2D5AF0), Color(0xFF7B4DFF)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, circlePaint);
    canvas.restore();

    // Circle border glow — violet
    final borderPaint = Paint()
      ..color = const Color(0xFF7B4DFF).withValues(alpha: checkOpacity * 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(cx, cy), r + 2, borderPaint);

    // Animated checkmark path
    final checkPaint = Paint()
      ..color = Colors.white.withValues(alpha: checkOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const p1 = Offset(-9.0, 0.0);
    const p2 = Offset(-2.0, 7.0);
    const p3 = Offset(10.0, -7.0);

    final totalLen = (p2 - p1).distance + (p3 - p2).distance;
    final drawn = checkProgress * totalLen;
    final seg1Len = (p2 - p1).distance;

    final checkPath = Path();
    checkPath.moveTo(cx + p1.dx, cy + p1.dy);

    if (drawn <= seg1Len) {
      final t = drawn / seg1Len;
      checkPath.lineTo(cx + p1.dx + (p2.dx - p1.dx) * t,
                       cy + p1.dy + (p2.dy - p1.dy) * t);
    } else {
      checkPath.lineTo(cx + p2.dx, cy + p2.dy);
      final t2 = (drawn - seg1Len) / (p3 - p2).distance;
      checkPath.lineTo(cx + p2.dx + (p3.dx - p2.dx) * t2,
                       cy + p2.dy + (p3.dy - p2.dy) * t2);
    }
    canvas.drawPath(checkPath, checkPaint);
  }

  void _drawCornerAccents(Canvas canvas, Size size) {
    final w = size.width;
    final accentPaint = Paint()
      ..color = const Color(0xFF2D5AF0).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const l = 12.0;
    const m = 6.0;

    // Top-left
    canvas.drawLine(Offset(m, m + l), Offset(m, m), accentPaint);
    canvas.drawLine(Offset(m, m), Offset(m + l, m), accentPaint);
    // Top-right
    canvas.drawLine(Offset(w - m - l, m), Offset(w - m, m), accentPaint);
    canvas.drawLine(Offset(w - m, m), Offset(w - m, m + l), accentPaint);
  }

  @override
  bool shouldRepaint(_ShieldPainter old) =>
      old.scanProgress != scanProgress ||
      old.scanLineY != scanLineY ||
      old.checkProgress != checkProgress ||
      old.checkOpacity != checkOpacity ||
      old.scanOpacity != scanOpacity;
}
