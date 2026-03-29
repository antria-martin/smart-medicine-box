import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Change to 3 seconds for a snappier feel
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        // Option A: If Named Routes are working:
        Navigator.pushReplacementNamed(context, '/login');

        // Option B: If Named Routes still fail, use this direct way:
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(builder: (context) => const LoginScreen())
        // );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Matching a deep medical theme or your mint color
      backgroundColor: const Color(0xFFF0FDFA),
      body: Stack(
        children: [
          // Background Glow
          // Background Glow - Fixed Version
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Use 'gradient:' not 'radialGradient:'
                gradient: RadialGradient(
                  colors: [
                    const Color(
                      0xFF0288D1,
                    ).withOpacity(0.15), // Soft Medical Blue
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Center(
                child: SizedBox(
                  width: 300,
                  height: 400,
                  child: CustomPaint(
                    painter: SplashMedicinePainter(progress: _controller.value),
                  ),
                ),
              );
            },
          ),
          const Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Text(
              "MEDBOX",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: Color(0xFF0288D1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SplashMedicinePainter extends CustomPainter {
  final double progress;
  SplashMedicinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.6);
    final random = math.Random(42);

    // Stage 1: Shake (0.0 - 0.2)
    // Stage 2: Lid Pop (0.2 - 0.4)
    // Stage 3: Fountain (0.4 - 1.0)
    double shake = 0.0;
    if (progress < 0.2) {
      shake = math.sin(progress * 100) * 2;
    }

    double lidAnim = ((progress - 0.2) / 0.2).clamp(0.0, 1.0);
    double pillsAnim = progress;

    final glassColor = const Color(0xFFB3E5FC).withOpacity(0.3);
    final bottleOutline = const Color(0xFF0288D1).withOpacity(0.5);

    // 1. Exploding Pills
    for (int i = 0; i < 15; i++) {
      double pStart = i / 15;
      double pProgress = (pillsAnim + pStart) % 1.0;

      if (progress > 0.2) {
        final angle = -math.pi / 2 + (random.nextDouble() * 2 - 1);
        final speed = 100.0 + (random.nextDouble() * 120);
        final distance = pProgress * speed;

        final pX = center.dx + math.cos(angle) * distance;
        final pY =
            (center.dy - 60) +
            math.sin(angle) * distance -
            (math.sin(pProgress * math.pi) * 30);

        final scale = (1.0 - pProgress).clamp(0.5, 1.2);
        final opacity = (1.0 - pProgress).clamp(0.0, 1.0);

        _drawCapsule(
          canvas,
          Offset(pX, pY),
          pProgress * 8,
          _getPillColors(i),
          opacity,
          scale,
        );
      }
    }

    // 2. Bottle (With Shake)
    canvas.save();
    canvas.translate(shake, 0);

    final bottleRect = Rect.fromCenter(center: center, width: 80, height: 110);
    final bottlePaint = Paint()..color = glassColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bottleRect, const Radius.circular(15)),
      bottlePaint,
    );

    // Bottle Outline
    canvas.drawRRect(
      RRect.fromRectAndRadius(bottleRect, const Radius.circular(15)),
      Paint()
        ..color = bottleOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Inner static pills
    for (int i = 0; i < 12; i++) {
      final x = center.dx + (random.nextDouble() * 50 - 25);
      final y = center.dy + 20 + (random.nextDouble() * 20 - 10);
      _drawCapsule(
        canvas,
        Offset(x, y),
        random.nextDouble(),
        _getPillColors(i),
        0.4,
        0.9,
      );
    }

    // Neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 30, center.dy - 68, 60, 15),
        const Radius.circular(4),
      ),
      bottlePaint,
    );
    canvas.restore();

    // 3. Animated Cap
    canvas.save();
    double capY = (center.dy - 78) - (lidAnim * 80);
    double capX = center.dx + (lidAnim * 50);
    double capRot = lidAnim * 1.2;

    canvas.translate(capX + shake, capY);
    canvas.rotate(capRot);

    final capRect = Rect.fromCenter(center: Offset.zero, width: 78, height: 32);
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(6)),
      Paint()..color = const Color(0xFF2D1B18),
    );

    // Cap Detail
    final ribPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1.5;
    for (var i = -30; i <= 30; i += 6) {
      canvas.drawLine(
        Offset(i.toDouble(), -12),
        Offset(i.toDouble(), 12),
        ribPaint,
      );
    }
    canvas.restore();
  }

  List<Color> _getPillColors(int i) {
    return [
      [const Color(0xFFA855F7), const Color(0xFF6B21A8)],
      [const Color(0xFF00B0FF), const Color(0xFF01579B)],
      [const Color(0xFF4ADE80), const Color(0xFF166534)],
      [const Color(0xFFF43F5E), const Color(0xFF881337)],
    ][i % 4];
  }

  void _drawCapsule(
    Canvas canvas,
    Offset pos,
    double rot,
    List<Color> colors,
    double opacity,
    double scale,
  ) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(scale);
    canvas.rotate(rot);
    const w = 16.0;
    const h = 8.0;

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(-w / 2, -h / 2, w / 2, h),
        topLeft: Radius.circular(5),
        bottomLeft: Radius.circular(5),
      ),
      Paint()..color = colors[0].withOpacity(opacity),
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(0, -h / 2, w / 2, h),
        topRight: Radius.circular(5),
        bottomRight: Radius.circular(5),
      ),
      Paint()..color = colors[1].withOpacity(opacity),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(SplashMedicinePainter oldDelegate) => true;
}
