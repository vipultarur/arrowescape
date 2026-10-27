import 'package:flutter/material.dart';

/// Custom 3D Toggle Switch matching exact reference design with vector Checkmark/Cross
class Game3DToggleSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const Game3DToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<Game3DToggleSwitch> createState() => _Game3DToggleSwitchState();
}

class _Game3DToggleSwitchState extends State<Game3DToggleSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: widget.value ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant Game3DToggleSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _animCtrl.forward();
      } else {
        _animCtrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isON = widget.value;

    return GestureDetector(
      onTap: () => widget.onChanged(!isON),
      child: AnimatedBuilder(
        animation: _animCtrl,
        builder: (context, child) {
          final double t = _animCtrl.value; // 0 = OFF, 1 = ON

          // Track color interpolation: Cool slate cyan (#709AA9) to bright electric lime green (#76D200)
          final Color trackColor = Color.lerp(
            const Color(0xFF709AA9),
            const Color(0xFF76D200),
            t,
          )!;

          return Container(
            width: 66,
            height: 34,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Vector Checkmark Icon (ON)
                Positioned(
                  left: 10,
                  child: Opacity(
                    opacity: t,
                    child: CustomPaint(
                      size: const Size(16, 14),
                      painter: _CheckmarkPainter(
                        color: const Color(0xFF104E00),
                      ),
                    ),
                  ),
                ),

                // Vector Cross Icon (OFF)
                Positioned(
                  right: 10,
                  child: Opacity(
                    opacity: 1.0 - t,
                    child: CustomPaint(
                      size: const Size(15, 15),
                      painter: _CrossPainter(
                        color: const Color(0xFF254552),
                      ),
                    ),
                  ),
                ),

                // Pure White 3D Squircle Thumb Knob
                Align(
                  alignment: Alignment(-1.0 + (2.0 * t), 0.0),
                  child: Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final Color color;

  _CheckmarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(size.width * 0.10, size.height * 0.50);
    path.lineTo(size.width * 0.38, size.height * 0.82);
    path.lineTo(size.width * 0.90, size.height * 0.18);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CrossPainter extends CustomPainter {
  final Color color;

  _CrossPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    final inset = size.width * 0.18;
    canvas.drawLine(
      Offset(inset, inset),
      Offset(size.width - inset, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrossPainter oldDelegate) =>
      oldDelegate.color != color;
}
