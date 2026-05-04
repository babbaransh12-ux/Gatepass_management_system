import 'dart:async';
import 'dart:math' as math;

import 'package:e_gatepass/core/navigation/role_router.dart';
import 'package:e_gatepass/core/services/auth_service.dart';
import 'package:flutter/material.dart';

import 'loginscreen.dart';

// ── Brand Palette (matches app ThemeData in main.dart) ───────────────────────
class _C {
  static const deepNavy   = Color(0xFFF8F9FE); // background  — app scaffoldBackgroundColor
  static const navyMid    = Color(0xFFE8EEFF); // logo fill   — soft blue tint
  static const teal       = Color(0xFF2D5AF0); // primary accent — app primary blue
  static const tealDim    = Color(0xFF1A3FD4); // darker blue
  static const steelBlue  = Color(0xFF6C757D); // tagline colour — app secondary
  static const white      = Color(0xFFFFFFFF);
}

// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ── Controllers ─────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;   // teal ring pulse
  late AnimationController _logoCtrl;    // logo scale-in + fade
  late AnimationController _textCtrl;    // text slide-up
  late AnimationController _barCtrl;     // progress bar fill
  late AnimationController _dotCtrl;     // blinking dots
  late AnimationController _fadeCtrl;    // overall fade-in

  // ── Animations ───────────────────────────────────────────────────────────
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textSlide;
  late Animation<double> _textOpacity;
  late Animation<double> _bar;
  late Animation<double> _fadeIn;

  String? _role;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _startSequence();
    _fetchRole();
  }

  void _initControllers() {
    // Fade-in wrapper
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn));

    // Teal pulse ring
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
    _pulseScale   = Tween<double>(begin: 1.0, end: 1.35).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(begin: 0.55, end: 0.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));

    // Logo entrance
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _logoScale   = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.4, curve: Curves.easeIn)));

    // Text slide-up
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _textSlide   = Tween<double>(begin: 30, end: 0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn));

    // Progress bar
    _barCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
    _bar = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _barCtrl, curve: Curves.easeInOut));

    // Blinking dots (fast repeating)
    _dotCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat();
  }

  void _startSequence() async {
    _fadeCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));

    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 600));

    _textCtrl.forward();
    _barCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 3000));

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
          pageBuilder: (ctx, anim, sec) => LoginScreen(),
          transitionsBuilder: (ctx, anim, sec, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _barCtrl.dispose();
    _dotCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _C.deepNavy,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _pulseCtrl, _logoCtrl, _textCtrl, _barCtrl, _dotCtrl, _fadeCtrl,
        ]),
        builder: (ctx, _) => FadeTransition(
          opacity: _fadeIn,
          child: Stack(
            children: [
              // 1. Background
              const SizedBox.expand(),

              // 2. Decorative circles (top-left & bottom-right)
              _DecorativeCircles(size: size),

              // 3. Grid overlay
              CustomPaint(
                painter: _GridPainter(),
                child: const SizedBox.expand(),
              ),

              // 4. "HOSTEL" pill badge — top right
              Positioned(
                top: 48,
                right: 20,
                child: _HostelPill(),
              ),

              // 5. Logo section (center-ish, shifted up)
              _buildLogoSection(size),

              // 6. Text block
              _buildTextBlock(size),

              // 7. Building silhouette
              Positioned(
                bottom: size.height * 0.13,
                left: 0,
                right: 0,
                child: CustomPaint(
                  painter: _BuildingSilhouette(),
                  child: SizedBox(height: size.height * 0.10),
                ),
              ),

              // 8. Progress bar + dots
              _buildProgressSection(size),
            ],
          ),
        ),
      ),
    );
  }

  // ── Logo section ──────────────────────────────────────────────────────────
  Widget _buildLogoSection(Size size) {
    return Positioned(
      top: size.height * 0.22,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: _logoOpacity.value,
        child: Transform.scale(
          scale: _logoScale.value,
          child: Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse ring
                  Transform.scale(
                    scale: _pulseScale.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _C.teal.withValues(alpha: _pulseOpacity.value),
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  // Static ring border
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _C.navyMid,
                      border: Border.all(color: _C.teal, width: 1.5),
                    ),
                    child: Center(
                      child: CustomPaint(
                        painter: _GateIconPainter(),
                        size: const Size(56, 56),
                      ),
                    ),
                  ),

                  // Teal checkmark badge — bottom right
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _C.teal,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Color(0xFFFFFFFF),
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Text block ────────────────────────────────────────────────────────────
  Widget _buildTextBlock(Size size) {
    return Positioned(
      top: size.height * 0.52,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: _textOpacity.value,
        child: Transform.translate(
          offset: Offset(0, _textSlide.value),
          child: Column(
            children: [
              // App name: "e" white + "Gate" teal + "Pass" white
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    height: 1,
                  ),
                  children: [
                    TextSpan(text: 'e', style: TextStyle(color: Color(0xFF1A1C1E))),
                    TextSpan(text: 'Gate', style: TextStyle(color: _C.teal)),
                    TextSpan(text: 'Pass', style: TextStyle(color: Color(0xFF1A1C1E))),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Tagline: SMART EXIT · SAFE RETURN
              const Text(
                'SMART EXIT  ·  SAFE RETURN',
                style: TextStyle(
                  color: _C.steelBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.5,
                ),
              ),

              const SizedBox(height: 12),

              // Thin teal divider
              Container(
                width: 80,
                height: 1,
                color: _C.teal,
              ),

              const SizedBox(height: 10),

              // Subtitle
              const Text(
                'Hostel Student Management System',
                style: TextStyle(
                  color: _C.steelBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Progress section ──────────────────────────────────────────────────────
  Widget _buildProgressSection(Size size) {
    // Blinking dots phase: 0→1 repeating, each dot shifts 1/3 phase
    final phase = _dotCtrl.value;

    return Positioned(
      bottom: size.height * 0.06,
      left: size.width * 0.30,
      right: size.width * 0.30,
      child: Column(
        children: [
          // Teal progress bar
          Container(
            height: 2,
            decoration: BoxDecoration(
              color: _C.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _bar.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _C.teal,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Three blinking dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final dotPhase = (phase + i / 3) % 1.0;
              final opacity = dotPhase < 0.5
                  ? dotPhase * 2
                  : (1.0 - dotPhase) * 2;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _C.teal.withValues(alpha: opacity.clamp(0.15, 1.0)),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOSTEL pill badge
// ─────────────────────────────────────────────────────────────────────────────
class _HostelPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.teal, width: 1),
        color: _C.teal.withValues(alpha: 0.12),
      ),
      child: const Text(
        'HOSTEL',
        style: TextStyle(
          color: _C.teal,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Decorative circles
// ─────────────────────────────────────────────────────────────────────────────
class _DecorativeCircles extends StatelessWidget {
  final Size size;
  const _DecorativeCircles({required this.size});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // Top-left
      Positioned(
        top: -80,
        left: -80,
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2D5AF0).withValues(alpha: 0.07),
          ),
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: -90,
        right: -90,
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2D5AF0).withValues(alpha: 0.07),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid painter — teal lines at low opacity
// ─────────────────────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _C.teal.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Gate / Arch icon painter (minimalist)
// ─────────────────────────────────────────────────────────────────────────────
class _GateIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final paint = Paint()
      ..color = _C.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final postWidth = w * 0.14;
    final archTop   = h * 0.12;
    final floorY    = h * 0.85;

    // Left pillar
    canvas.drawLine(
      Offset(cx - postWidth * 2.2, floorY),
      Offset(cx - postWidth * 2.2, archTop + postWidth * 2.2),
      paint,
    );
    // Right pillar
    canvas.drawLine(
      Offset(cx + postWidth * 2.2, floorY),
      Offset(cx + postWidth * 2.2, archTop + postWidth * 2.2),
      paint,
    );
    // Floor / base line
    canvas.drawLine(
      Offset(cx - postWidth * 2.2, floorY),
      Offset(cx + postWidth * 2.2, floorY),
      paint,
    );
    // Arch
    final archRect = Rect.fromCenter(
      center: Offset(cx, archTop + postWidth * 2.2),
      width:  postWidth * 4.4,
      height: postWidth * 4.4,
    );
    canvas.drawArc(archRect, math.pi, math.pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Building silhouette painter
// ─────────────────────────────────────────────────────────────────────────────
class _BuildingSilhouette extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _C.teal.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Simple hostel/city silhouette using rectangles of varying heights
    final buildings = [
      // [left%, width%, height%]
      [0.03, 0.08, 0.55],
      [0.12, 0.10, 0.80],
      [0.23, 0.07, 0.65],
      [0.31, 0.12, 0.95],
      [0.44, 0.09, 0.70],
      [0.54, 0.13, 1.00], // tallest — main hostel block
      [0.68, 0.08, 0.75],
      [0.77, 0.11, 0.60],
      [0.89, 0.08, 0.50],
    ];

    for (final b in buildings) {
      final left   = w * b[0];
      final width  = w * b[1];
      final bldgH  = h * b[2];
      canvas.drawRect(
        Rect.fromLTWH(left, h - bldgH, width, bldgH),
        paint,
      );
    }

    // Windows — tiny bright squares
    final winPaint = Paint()
      ..color = _C.teal.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    for (final b in buildings) {
      final left  = w * b[0];
      final bw    = w * b[1];
      final bh    = h * b[2];
      final top   = h - bh;

      final cols = (bw / 8).floor().clamp(1, 3);
      final rows = (bh / 12).floor().clamp(1, 5);

      for (int r = 1; r <= rows; r++) {
        for (int c = 0; c < cols; c++) {
          canvas.drawRect(
            Rect.fromLTWH(
              left + (bw / (cols + 1)) * (c + 1) - 1.5,
              top + (bh / (rows + 1)) * r - 1.5,
              3,
              3,
            ),
            winPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
