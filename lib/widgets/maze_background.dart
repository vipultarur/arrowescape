import 'dart:math';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class BlendedMazeBackground extends StatelessWidget {
  final double height;
  final double progress;

  const BlendedMazeBackground({
    super.key,
    this.height = 360,
    this.progress = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Opacity(
        opacity: 0.55, // Lower the opacity of the whole mesh slightly
        child: ShaderMask(
          shaderCallback: (rect) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.45, 1.0],
            ).createShader(rect);
          },
          blendMode: BlendMode.dstIn,
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: CustomPaint(
              painter: MazeBackgroundPainter(
                baseColor: AppColors.textSecondary,
                progress: progress,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MazeBackgroundPainter extends CustomPainter {
  final Color baseColor;
  final double progress;

  static Size? _cachedSize;
  static List<_GeneratedPath>? _cachedPaths;
  static List<Offset>? _cachedDots;

  MazeBackgroundPainter({
    required this.baseColor,
    this.progress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double spacing = 38.0;
    final int rows = (size.height / spacing).ceil();
    final int cols = (size.width / spacing).ceil();

    if (_cachedSize != size || _cachedPaths == null || _cachedDots == null) {
      _cachedSize = size;
      final rng = Random(1337);
      final Set<int> occupiedBits = {};

      final int numArrows = 15;
      final colors = [
        AppColors.accentGold,
        AppColors.accentOrange,
        AppColors.accentGreen,
        AppColors.textSecondary,
      ];

      final List<_GeneratedPath> generatedPaths = [];

      for (int i = 0; i < numArrows; i++) {
        final color = colors[rng.nextInt(colors.length)];
        final strokeWidth = 3.5 + rng.nextDouble() * 2.0;

        int startRow = 0;
        int startCol = 0;
        bool foundStart = false;

        for (int attempt = 0; attempt < 30; attempt++) {
          final double colTarget =
              (i + 0.1 + rng.nextDouble() * 0.8) * (cols / numArrows);
          final int c = colTarget.floor().clamp(0, cols - 1);
          final int r = rng.nextInt((rows * 0.6).ceil().clamp(2, rows));

          final bit = (r << 16) | c;
          if (!occupiedBits.contains(bit)) {
            startRow = r;
            startCol = c;
            foundStart = true;
            break;
          }
        }

        if (!foundStart) continue;

        final List<Offset> pathPoints = [
          Offset(startCol * spacing + 19, startRow * spacing + 19)
        ];
        occupiedBits.add((startRow << 16) | startCol);

        final int pathLength = 3 + rng.nextInt(3);
        int currentValR = startRow;
        int currentValC = startCol;
        int lastDir = rng.nextInt(4);

        for (int j = 0; j < pathLength; j++) {
          final List<int> validDirs = [];
          for (int d = 0; d < 4; d++) {
            if ((d - lastDir).abs() == 2) continue;

            int nextR = currentValR;
            int nextC = currentValC;
            switch (d) {
              case 0:
                nextC++;
                break;
              case 1:
                nextR++;
                break;
              case 2:
                nextC--;
                break;
              default:
                nextR--;
                break;
            }

            if (nextC >= 0 && nextC < cols && nextR >= 0 && nextR < rows) {
              if (!occupiedBits.contains((nextR << 16) | nextC)) {
                validDirs.add(d);
              }
            }
          }

          if (validDirs.isEmpty) break;

          if (validDirs.contains(1) && rng.nextDouble() < 0.5) {
            lastDir = 1;
          } else {
            lastDir = validDirs[rng.nextInt(validDirs.length)];
          }

          switch (lastDir) {
            case 0:
              currentValC++;
              break;
            case 1:
              currentValR++;
              break;
            case 2:
              currentValC--;
              break;
            default:
              currentValR--;
              break;
          }

          pathPoints.add(
              Offset(currentValC * spacing + 19, currentValR * spacing + 19));
          occupiedBits.add((currentValR << 16) | currentValC);
        }

        if (pathPoints.length >= 2) {
          generatedPaths.add(_GeneratedPath(
            points: pathPoints,
            color: color,
            strokeWidth: strokeWidth,
          ));
        }
      }

      final List<Offset> dots = [];
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          if (!occupiedBits.contains((r << 16) | c)) {
            dots.add(Offset(c * spacing + 19, r * spacing + 19));
          }
        }
      }

      _cachedPaths = generatedPaths;
      _cachedDots = dots;
    }

    final dotPaint = Paint()..color = AppColors.gridDot.withValues(alpha: 0.6);
    for (final dot in _cachedDots!) {
      canvas.drawCircle(dot, 1.5, dotPaint);
    }

    // 2. Draw the generated arrow lines with full opacity (mesh arrows opaque 100%)
    for (final gp in _cachedPaths!) {
      if (gp.points.length < 2) continue;

      final arrowPaint = Paint()
        ..color = gp.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = gp.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final double t = progress.clamp(0.0, 1.0);

      // Slice path from start (tail) to end (head tip) based on target distance
      final List<Offset> drawnPts = _slicePath(gp.points, t);
      if (drawnPts.length >= 2) {
        final path = _buildRoundedPath(drawnPts, spacing * 0.35);
        canvas.drawPath(path, arrowPaint);
      }

      // Arrowheads render once t > 0.8, scaling from 0 to full size over final 20% of progress
      if (t > 0.8) {
        final double headT = ((t - 0.8) / 0.2).clamp(0.0, 1.0);
        final tip = gp.points.last;
        final prev = gp.points[gp.points.length - 2];
        final dv = tip - prev;
        final len = dv.distance;

        final dx = len > 0.01 ? dv.dx / len : 0.0;
        final dy = len > 0.01 ? dv.dy / len : -1.0;

        final double headSize = spacing * 0.32 * headT;
        final base = tip - Offset(dx * headSize, dy * headSize);
        final px = -dy, py = dx; // Perpendicular vector

        final L = Offset(base.dx + px * headSize * 0.75, base.dy + py * headSize * 0.75);
        final T = tip;
        final R = Offset(base.dx - px * headSize * 0.75, base.dy - py * headSize * 0.75);
        final cornerR = (spacing * 0.08 * headT).toDouble();

        final caretPath = _buildRoundedTrianglePath(L, T, R, cornerR);

        canvas.drawPath(
          caretPath,
          Paint()
            ..color = gp.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = gp.strokeWidth
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }
  }

  List<Offset> _slicePath(List<Offset> points, double t) {
    if (points.isEmpty || t <= 0.0) return [];
    if (t >= 1.0 || points.length < 2) return points;

    double totalLength = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalLength += (points[i + 1] - points[i]).distance;
    }
    final targetLength = totalLength * t;

    final result = <Offset>[points.first];
    double accum = 0.0;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final segLen = (p2 - p1).distance;

      if (accum + segLen <= targetLength) {
        result.add(p2);
        accum += segLen;
      } else {
        final rem = targetLength - accum;
        final frac = segLen > 0.001 ? (rem / segLen).clamp(0.0, 1.0) : 1.0;
        result.add(Offset.lerp(p1, p2, frac)!);
        break;
      }
    }
    return result;
  }

  Path _buildRoundedPath(List<Offset> points, double radius) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length == 1) {
      path.moveTo(points.first.dx, points.first.dy);
      return path;
    }
    if (points.length == 2) {
      path.moveTo(points.first.dx, points.first.dy);
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }

    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final next = points[i + 1];

      final vPrev = curr - prev;
      final lenPrev = vPrev.distance;
      final vNext = next - curr;
      final lenNext = vNext.distance;

      if (lenPrev < 0.001 || lenNext < 0.001) {
        path.lineTo(curr.dx, curr.dy);
        continue;
      }

      final uPrev = vPrev / lenPrev;
      final uNext = vNext / lenNext;

      final double r = radius.clamp(0.0, min(lenPrev / 2.0, lenNext / 2.0)).toDouble();

      final arcStart = curr - uPrev * r;
      final arcEnd = curr + uNext * r;

      path.lineTo(arcStart.dx, arcStart.dy);
      path.quadraticBezierTo(curr.dx, curr.dy, arcEnd.dx, arcEnd.dy);
    }

    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  Path _buildRoundedTrianglePath(Offset L, Offset T, Offset R, double r) {
    final vLT = T - L;
    final vTR = R - T;
    final vRL = L - R;

    final lenLT = vLT.distance;
    final lenTR = vTR.distance;
    final lenRL = vRL.distance;

    if (lenLT < 0.001 || lenTR < 0.001 || lenRL < 0.001) {
      return Path()
        ..moveTo(L.dx, L.dy)
        ..lineTo(T.dx, T.dy)
        ..lineTo(R.dx, R.dy)
        ..close();
    }

    final uLT = vLT / lenLT;
    final uTR = vTR / lenTR;
    final uRL = vRL / lenRL;

    final double cornerR = r.clamp(0.0, min(lenLT / 2.0, min(lenTR / 2.0, lenRL / 2.0))).toDouble();

    final A1 = L - uRL * cornerR;
    final A2 = L + uLT * cornerR;

    final B1 = T - uLT * cornerR;
    final B2 = T + uTR * cornerR;

    final C1 = R - uTR * cornerR;
    final C2 = R + uRL * cornerR;

    return Path()
      ..moveTo(A2.dx, A2.dy)
      ..lineTo(B1.dx, B1.dy)
      ..quadraticBezierTo(T.dx, T.dy, B2.dx, B2.dy)
      ..lineTo(C1.dx, C1.dy)
      ..quadraticBezierTo(R.dx, R.dy, C2.dx, C2.dy)
      ..lineTo(A1.dx, A1.dy)
      ..quadraticBezierTo(L.dx, L.dy, A2.dx, A2.dy)
      ..close();
  }

  @override
  bool shouldRepaint(covariant MazeBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.baseColor != baseColor;
  }
}

class _GeneratedPath {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  _GeneratedPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}
