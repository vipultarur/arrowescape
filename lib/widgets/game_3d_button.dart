import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Standalone 3D Action Button with physical press animation.
/// On tap-down the green/orange inner face compresses into the yellow bevel
/// frame (bottom lip shrinks to 0, top margin grows), then springs back on
/// release before firing the onTap callback.
class Game3DButton extends StatefulWidget {
  final String title;
  final String subtext;
  final String? tagText;
  final bool isGreen;
  final VoidCallback onTap;
  final double width;

  const Game3DButton({
    super.key,
    required this.title,
    required this.subtext,
    this.tagText,
    this.isGreen = true,
    required this.onTap,
    this.width = 310,
  });

  @override
  State<Game3DButton> createState() => _Game3DButtonState();
}

class _Game3DButtonState extends State<Game3DButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pressAnim;

  // 3D depth values (unpressed → pressed)
  static const double _outerLipMax = 6.0; // yellow bottom lip height at rest
  static const double _innerLipMax = 5.0; // green bottom lip height at rest

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _pressAnim = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeInQuad,
      reverseCurve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _ctrl.forward();

  void _onTapUp(TapUpDetails _) {
    _ctrl.reverse();
    widget.onTap();
  }

  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    final Color outerYellowBorder = const Color(0xFFFFD600);
    final Color outerYellowShadow = const Color(0xFFC48A00);

    final Color faceColor =
        widget.isGreen ? const Color(0xFF38D659) : const Color(0xFFFF9824);
    final Color faceShadowColor =
        widget.isGreen ? const Color(0xFF1E8E3E) : const Color(0xFFC66900);

    final Color titleOutlineColor =
        widget.isGreen ? const Color(0xFF124C1F) : const Color(0xFF8A3C00);
    final Color subtextColor =
        widget.isGreen ? const Color(0xFF125222) : const Color(0xFF853D00);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _pressAnim,
        builder: (context, child) {
          final double t = _pressAnim.value; // 0 = rest, 1 = fully pressed

          // Clamp derived values — elasticOut can overshoot past 0..1
          final double outerLip = (_outerLipMax * (1 - t)).clamp(0.0, _outerLipMax);
          final double innerLip = (_innerLipMax * (1 - t)).clamp(0.0, _innerLipMax);
          final double topPush = ((_outerLipMax + _innerLipMax) * t).clamp(0.0, _outerLipMax + _innerLipMax);
          final double shadowBlur = (12.0 * (1 - t)).clamp(0.0, 12.0);
          final double shadowY = (8.0 * (1 - t)).clamp(0.0, 8.0);
          final double scale = (1.0 - (0.02 * t)).clamp(0.96, 1.0);

          return Transform.scale(
            scale: scale,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // ── 1. Outer Yellow Bevel Frame ──────────────────────
                Container(
                  width: widget.width,
                  decoration: BoxDecoration(
                    color: outerYellowShadow,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: shadowBlur,
                        offset: Offset(0, shadowY),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: EdgeInsets.only(bottom: outerLip),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: outerYellowBorder,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Container(
                      // ── 2. Inner Face (Green / Orange) ─────────────
                      decoration: BoxDecoration(
                        color: faceShadowColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Container(
                        margin: EdgeInsets.only(
                          bottom: innerLip,
                          top: topPush,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: faceColor,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.tagText != null)
                              const SizedBox(height: 8),

                            // ── 3. Title Text with Stroke Outline ────
                            Stack(
                              children: [
                                Text(
                                  widget.title,
                                  style: GoogleFonts.nunito(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = 5
                                      ..strokeJoin = StrokeJoin.round
                                      ..color = titleOutlineColor,
                                  ),
                                ),
                                Text(
                                  widget.title,
                                  style: GoogleFonts.nunito(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),

                            // ── 4. Sub-caption ──────────────────────
                            Text(
                              widget.subtext,
                              style: GoogleFonts.nunito(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: subtextColor,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── 5. Top Magenta Tag Badge ────────────────────────
                if (widget.tagText != null)
                  Positioned(
                    top: -12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7E0A79),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 2.5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD914D1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Text(
                              widget.tagText!,
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.9,
                                foreground: Paint()
                                  ..style = PaintingStyle.stroke
                                  ..strokeWidth = 3
                                  ..strokeJoin = StrokeJoin.round
                                  ..color = const Color(0xFF5E055A),
                              ),
                            ),
                            Text(
                              widget.tagText!,
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.9,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
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
