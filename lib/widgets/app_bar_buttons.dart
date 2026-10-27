import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/audio_manager.dart';

enum App3DButtonStyle {
  white, // Image 1: White 3D squircle container with blue gear/chevron icon
  red,   // Image 2: Red 3D squircle container with white border ring and white icon
}

/// Standalone 3D Squircle Action Button matching user reference design (Image 1 & Image 2).
class App3DIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final App3DButtonStyle style;
  final double size;
  final double iconSize;
  final Color? iconColor;

  const App3DIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.style = App3DButtonStyle.white,
    this.size = 42,
    this.iconSize = 24,
    this.iconColor,
  });

  @override
  State<App3DIconButton> createState() => _App3DIconButtonState();
}

class _App3DIconButtonState extends State<App3DIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final isRed = widget.style == App3DButtonStyle.red;

    // Outer 3D lip colors & background matching reference images
    final faceBgColor = isRed
        ? const Color(0xFFEF4444)
        : appColors.surface;

    final bevelLipColor = isRed
        ? const Color(0xFF990022)
        : (appColors.isDark ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1));

    final borderColor = isRed
        ? Colors.white
        : appColors.cardBorder;

    final iconColor = widget.iconColor ??
        (isRed
            ? Colors.white
            : appColors.navTabActiveStart);

    const double depth = 3.5; // 3D bottom bevel height

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        AudioManager.instance.playClick();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: widget.size,
        height: widget.size + depth,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // ── 1. 3D Bottom Bevel Lip / Base Shadow Container ───────────────
            Positioned(
              top: _isPressed ? depth : 0,
              left: 0,
              right: 0,
              height: widget.size,
              child: Container(
                decoration: BoxDecoration(
                  color: bevelLipColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    if (!_isPressed)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: appColors.isDark ? 0.35 : 0.08),
                        blurRadius: 5,
                        offset: const Offset(0, 3.5),
                      ),
                  ],
                ),
              ),
            ),

            // ── 2. Top Interactive Surface Face Container ──────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 60),
              top: _isPressed ? depth : 0,
              left: 0,
              right: 0,
              height: widget.size - (_isPressed ? 0 : 1.5),
              child: Container(
                decoration: BoxDecoration(
                  color: faceBgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: borderColor,
                    width: isRed ? 2.2 : 1.4,
                  ),
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    size: widget.iconSize,
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Common 3D Back Button matching reference image container with blue chevron icon.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Color? color;
  final double size;
  final bool isRed;

  const AppBackButton({
    super.key,
    this.onTap,
    this.color,
    this.size = 40,
    this.isRed = false,
  });

  @override
  Widget build(BuildContext context) {
    return App3DIconButton(
      icon: Icons.chevron_left_rounded,
      size: size,
      iconSize: size * 0.65,
      iconColor: color,
      style: isRed ? App3DButtonStyle.red : App3DButtonStyle.white,
      onTap: () {
        if (onTap != null) {
          onTap!();
        } else {
          Navigator.maybePop(context);
        }
      },
    );
  }
}

/// Common 3D Settings Button matching reference Image 1 (White 3D container with blue gear icon).
class AppSettingsButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Color? color;
  final double size;

  const AppSettingsButton({
    super.key,
    this.onTap,
    this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return App3DIconButton(
      icon: Icons.settings_rounded,
      size: size,
      iconSize: size * 0.58,
      iconColor: color ?? const Color(0xFF3B82F6),
      style: App3DButtonStyle.white,
      onTap: () {
        if (onTap != null) {
          onTap!();
        } else {
          Navigator.pushNamed(context, '/settings');
        }
      },
    );
  }
}

/// Common 3D Close Button matching reference Image 2 (Red squircle container with white ring & X).
class AppCloseButton extends StatelessWidget {
  final VoidCallback? onTap;
  final double size;

  const AppCloseButton({
    super.key,
    this.onTap,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return App3DIconButton(
      icon: Icons.close_rounded,
      size: size,
      iconSize: size * 0.58,
      iconColor: Colors.white,
      style: App3DButtonStyle.red,
      onTap: () {
        if (onTap != null) {
          onTap!();
        } else {
          Navigator.maybePop(context);
        }
      },
    );
  }
}
