import 'dart:math' as math;
import 'package:flutter/material.dart';

class MedAppLogo extends StatefulWidget {
  const MedAppLogo({super.key});

  @override
  _MedAppLogoState createState() => _MedAppLogoState();
}

class _MedAppLogoState extends State<MedAppLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200, // Adjusted size for your header
      height: 250,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(painter: PillExplosionPainter(_controller.value));
        },
      ),
    );
  }
}

class PillExplosionPainter extends CustomPainter {
  final double progress;
  PillExplosionPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.7);
    final random = math.Random(42);

    // 1. Draw "Two-Toned" Pills
    for (int i = 0; i < 12; i++) {
      final angle =
          (random.nextDouble() * 1.2 * math.pi) -
          (1.1 * math.pi); // Upward spray
      final speed = random.nextDouble() * 120 + 60;
      final pillProgress = (progress + (i / 12)) % 1.0;

      final distance = pillProgress * speed + 10;
      final x = center.dx + math.cos(angle) * distance;
      final y =
          (center.dy - 40) + math.sin(angle) * distance - (pillProgress * 40);

      final opacity = 1.0 - (pillProgress > 0.8 ? (pillProgress - 0.8) * 5 : 0);
      final List<Color> pillColors = [
        [Colors.blue, Colors.white],
        [Colors.purple, Colors.yellow],
        [Colors.cyan, Colors.blueGrey],
        [Colors.orange, Colors.white],
      ][i % 4];

      _drawCapsule(
        canvas,
        Offset(x, y),
        angle + (pillProgress * 5),
        pillColors,
        opacity,
      );
    }

    // 2. Draw Bottle Body (Blue Gradient)
    final bottleRect = Rect.fromCenter(center: center, width: 70, height: 90);
    final bottleRRect = RRect.fromRectAndRadius(
      bottleRect,
      const Radius.circular(12),
    );

    final bottlePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.blue[700]!, Colors.blue[400]!, Colors.blue[900]!],
      ).createShader(bottleRect);

    canvas.drawRRect(bottleRRect, bottlePaint);

    // 3. Draw Bottle Rim
    final rimRect = Rect.fromLTWH(center.dx - 30, center.dy - 55, 60, 15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rimRect, const Radius.circular(4)),
      bottlePaint,
    );

    // 4. Draw Tilted Cap
    canvas.save();
    canvas.translate(center.dx + 40, center.dy - 60);
    canvas.rotate(0.5); // Tilted angle
    final capRect = Rect.fromCenter(center: Offset.zero, width: 55, height: 25);
    final capPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.grey[400]!, Colors.grey[600]!],
      ).createShader(capRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(4)),
      capPaint,
    );
    // Detail lines on cap
    final linePaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;
    for (var i = -20; i <= 20; i += 5) {
      canvas.drawLine(
        Offset(i.toDouble(), -10),
        Offset(i.toDouble(), 10),
        linePaint,
      );
    }
    canvas.restore();
  }

  void _drawCapsule(
    Canvas canvas,
    Offset position,
    double rotation,
    List<Color> colors,
    double opacity,
  ) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);

    final rectLeft = Rect.fromLTWH(-10, -4, 10, 8);
    final rectRight = Rect.fromLTWH(0, -4, 10, 8);

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rectLeft,
        topLeft: const Radius.circular(5),
        bottomLeft: const Radius.circular(5),
      ),
      Paint()..color = colors[0].withOpacity(opacity),
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rectRight,
        topRight: const Radius.circular(5),
        bottomRight: const Radius.circular(5),
      ),
      Paint()..color = colors[1].withOpacity(opacity),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(PillExplosionPainter oldDelegate) => true;
}
