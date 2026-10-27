import 'dart:math';
import 'package:flutter/material.dart';

/// Standalone 3D Star Widget matching reference screenshot.
/// Micro-element breakdown:
/// - Rounded 5-pointed chubby star shape with smooth curved tips & valleys
/// - Bright yellow outer outline / bevel border for earned stars, warm brown for unearned
/// - Thick 3D depth extrusion side wall on bottom
/// - Inner face: Luminous yellow-orange gradient when filled (earned),
///   or warm chocolate/amber-brown when unfilled (unearned).
class Game3DStar extends StatelessWidget {
  final double size;
  final bool isFilled;

  const Game3DStar({
    super.key,
    this.size = 24,
    this.isFilled = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _Game3DStarPainter(isFilled: isFilled),
    );
  }
}

class _Game3DStarPainter extends CustomPainter {
  final bool isFilled;

  _Game3DStarPainter({required this.isFilled});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final outerRadius = w * 0.44;
    final innerRadius = w * 0.22;
    final cornerRadiusOuter = w * 0.08;
    final cornerRadiusInner = w * 0.045;

    // Generate 10 star vertices (5 outer tips, 5 inner valleys)
    final double angleStep = pi / 5;
    final List<Offset> points = [];

    for (int i = 0; i < 10; i++) {
      final r = (i % 2 == 0) ? outerRadius : innerRadius;
      final angle = i * angleStep - pi / 2;
      points.add(Offset(center.dx + r * cos(angle), center.dy + r * sin(angle)));
    }

    // Build smooth rounded star path
    final Path starPath = Path();
    for (int i = 0; i < 10; i++) {
      final pPrev = points[(i + 9) % 10];
      final pCurr = points[i];
      final pNext = points[(i + 1) % 10];

      final vPrev = pPrev - pCurr;
      final dPrev = vPrev / vPrev.distance;

      final vNext = pNext - pCurr;
      final dNext = vNext / vNext.distance;

      final cr = (i % 2 == 0) ? cornerRadiusOuter : cornerRadiusInner;

      final pStart = pCurr + dPrev * cr;
      final pEnd = pCurr + dNext * cr;

      if (i == 0) {
        starPath.moveTo(pStart.dx, pStart.dy);
      } else {
        starPath.lineTo(pStart.dx, pStart.dy);
      }
      starPath.quadraticBezierTo(pCurr.dx, pCurr.dy, pEnd.dx, pEnd.dy);
    }
    starPath.close();

    // ── 1. Draw Solid 3D Extrusion Side Wall & Depth Shadow ──────────────
    final double depth = h * 0.12;
    final shadowPaint = Paint()
      ..color = isFilled ? const Color(0xFFB86600) : const Color(0xFF50300A)
      ..style = PaintingStyle.fill;

    // Draw stacked path layers to create a solid 3D extrusion block
    for (double d = depth; d >= 1.0; d -= 1.0) {
      canvas.drawPath(starPath.shift(Offset(0, d)), shadowPaint);
    }

    // ── 2. Draw Outer Bevel Border / Rim ─────────────────────────────
    final borderPaint = Paint()
      ..color = isFilled ? const Color(0xFFFFEA00) : const Color(0xFFC78326)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.12
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(starPath, borderPaint);

    // ── 3. Draw Main Inner Face (Filled vs Unfilled) ─────────────────
    final facePaint = Paint()..style = PaintingStyle.fill;

    if (isFilled) {
      // Luminous Bright Yellow-Orange gradient matching reference image
      facePaint.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFF966), // Bright top yellow highlight
          Color(0xFFFFC200), // Rich golden yellow center
          Color(0xFFFF8C00), // Deep warm orange bottom
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    } else {
      // Warm chocolate / caramel amber-brown matching reference image
      facePaint.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF9E621C), // Warm light amber-brown top
          Color(0xFF6B3F0A), // Dark brown bottom
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    }

    canvas.drawPath(starPath, facePaint);

    // ── 4. Inner Top Highlight Specular Curve ─────────────────────────
    if (isFilled) {
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..strokeCap = StrokeCap.round;

      final highlightPath = Path()
        ..moveTo(center.dx - outerRadius * 0.25, center.dy - outerRadius * 0.35)
        ..quadraticBezierTo(
          center.dx,
          center.dy - outerRadius * 0.65,
          center.dx + outerRadius * 0.25,
          center.dy - outerRadius * 0.35,
        );
      canvas.drawPath(highlightPath, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _Game3DStarPainter oldDelegate) {
    return oldDelegate.isFilled != isFilled;
  }
}

/// 3 Stars Row widget placed on an arch curve over level buttons & dialogs.
class Game3DStarRow extends StatelessWidget {
  final int stars;
  final double starSize;

  const Game3DStarRow({
    super.key,
    required this.stars,
    this.starSize = 26,
  });

  @override
  Widget build(BuildContext context) {
    final double rowWidth = starSize * 3.4;
    final double rowHeight = starSize * 1.6;
    final double centerLeft = (rowWidth - starSize) / 2;

    // 3 curved stars configuration matching reference image:
    // Star 0 (Left):   dx = -21.5, dy = 6.0, rot = -0.40 (-23°), scale = 0.94
    // Star 2 (Right):  dx = 21.5,  dy = 6.0, rot = 0.40 (+23°),  scale = 0.94
    // Star 1 (Middle): dx = 0.0,   dy = -4.0, rot = 0.0 (0°),    scale = 1.16
    final starConfigs = [
      (index: 0, dx: -21.5, dy: 6.0, rot: -0.40, scale: 0.94),
      (index: 2, dx: 21.5, dy: 6.0, rot: 0.40, scale: 0.94),
      (index: 1, dx: 0.0, dy: -4.0, rot: 0.0, scale: 1.16),
    ];

    return SizedBox(
      width: rowWidth,
      height: rowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: starConfigs.map((cfg) {
          final i = cfg.index;
          final isFilled = i < stars;

          return Positioned(
            left: centerLeft + cfg.dx,
            top: (rowHeight * 0.25) + cfg.dy,
            child: Transform.rotate(
              angle: cfg.rot,
              child: Transform.scale(
                scale: cfg.scale,
                child: Game3DStar(
                  size: starSize,
                  isFilled: isFilled,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
