import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models/arrow.dart';

class ArrowLine extends StatelessWidget {
  final ArrowDirection direction;
  final Color color;
  final double size;
  final double strokeWidth;

  const ArrowLine({
    super.key,
    required this.direction,
    required this.color,
    this.size = 52.0,
    this.strokeWidth = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: ArrowLinePainter(
          direction: direction,
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class ArrowLinePainter extends CustomPainter {
  final ArrowDirection direction;
  final Color color;
  final double strokeWidth;

  ArrowLinePainter({
    required this.direction,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double w = size.width;
    final double h = size.height;

    final Offset start;
    final Offset end;
    final Offset arrowhead1;
    final Offset arrowhead2;

    final double padding = strokeWidth * 1.5;
    final double headSize = size.width * 0.32;

    switch (direction) {
      case ArrowDirection.left:
        start = Offset(w - padding, h / 2);
        end = Offset(padding, h / 2);
        arrowhead1 = Offset(end.dx + headSize, end.dy - headSize * 0.7);
        arrowhead2 = Offset(end.dx + headSize, end.dy + headSize * 0.7);
        break;
      case ArrowDirection.right:
        start = Offset(padding, h / 2);
        end = Offset(w - padding, h / 2);
        arrowhead1 = Offset(end.dx - headSize, end.dy - headSize * 0.7);
        arrowhead2 = Offset(end.dx - headSize, end.dy + headSize * 0.7);
        break;
      case ArrowDirection.up:
        start = Offset(w / 2, h - padding);
        end = Offset(w / 2, padding);
        arrowhead1 = Offset(end.dx - headSize * 0.7, end.dy + headSize);
        arrowhead2 = Offset(end.dx + headSize * 0.7, end.dy + headSize);
        break;
      case ArrowDirection.down:
        start = Offset(w / 2, padding);
        end = Offset(w / 2, h - padding);
        arrowhead1 = Offset(end.dx - headSize * 0.7, end.dy - headSize);
        arrowhead2 = Offset(end.dx + headSize * 0.7, end.dy - headSize);
        break;
    }

    // Draw main arrow body line
    canvas.drawLine(start, end, paint);

    // Draw caret arrowhead with rounded corners
    final cornerR = strokeWidth * 0.5;
    final path = _buildRoundedTrianglePath(arrowhead1, end, arrowhead2, cornerR);
    canvas.drawPath(path, paint);
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
  bool shouldRepaint(covariant ArrowLinePainter oldDelegate) {
    return oldDelegate.direction != direction ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
