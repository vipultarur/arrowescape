import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Dialog3DButton extends StatefulWidget {
  final String label;
  final Color topColor;
  final Color bottomColor;
  final Color textColor;
  final double? fontSize;
  final VoidCallback onTap;

  const Dialog3DButton({
    super.key,
    required this.label,
    required this.topColor,
    required this.bottomColor,
    required this.textColor,
    this.fontSize,
    required this.onTap,
  });

  @override
  State<Dialog3DButton> createState() => _Dialog3DButtonState();
}

class _Dialog3DButtonState extends State<Dialog3DButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 140),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double calculatedFontSize = widget.fontSize ??
        (widget.label.length > 22
            ? 13.5
            : (widget.label.length > 14 ? 15.0 : 17.0));

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final double t = _ctrl.value;
          final double depth = 5.0 * (1 - t);
          final double topPush = 5.0 * t;

          return Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: widget.bottomColor,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: widget.bottomColor.withValues(alpha: 0.35),
                  blurRadius: 6 * (1 - t),
                  offset: Offset(0, 3 * (1 - t)),
                ),
              ],
            ),
            child: Container(
              margin: EdgeInsets.only(bottom: depth, top: topPush),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: widget.topColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: calculatedFontSize,
                  fontWeight: FontWeight.w900,
                  color: widget.textColor,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
