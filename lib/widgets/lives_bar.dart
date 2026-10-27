import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class LivesBar extends StatefulWidget {
  final int lives;
  final int maxLives;
  final AnimationController? entranceController;

  const LivesBar({
    super.key,
    required this.lives,
    required this.maxLives,
    this.entranceController,
  });

  @override
  State<LivesBar> createState() => _LivesBarState();
}

class _LivesBarState extends State<LivesBar> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.maxLives, (i) {
        final isFull = i < widget.lives;

        final heartWidget = Stack(
          alignment: Alignment.center,
          children: [
            // Soft drop shadow for 3D depth
            if (isFull)
              Icon(
                Icons.favorite,
                color: Colors.black.withValues(alpha: 0.15),
                size: 27,
              ),
            // Heart body
            isFull
                ? ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 25,
                    ),
                  )
                : Icon(
                    Icons.favorite_border,
                    color: AppColors.surfaceLight,
                    size: 24,
                  ),
            // Glass/glossy reflection dot on top-left of active heart
            if (isFull)
              Positioned(
                top: 5,
                left: 5,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );

        final Widget baseItem = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: isFull
                ? ScaleTransition(
                    key: ValueKey('heart_${i}_full'),
                    scale: _scaleAnimation,
                    child: heartWidget,
                  )
                : SizedBox(
                    key: ValueKey('heart_${i}_empty'),
                    child: heartWidget,
                  ),
          ),
        );

        if (widget.entranceController == null) {
          return baseItem;
        }

        // Sequential left-to-right stagger across Phase 2 (0.70 to 1.0)
        final double start = (0.70 + i * 0.07).clamp(0.70, 0.90);
        final double end = (start + 0.12).clamp(start + 0.05, 1.0);
        final heartAnim = CurvedAnimation(
          parent: widget.entranceController!,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        );

        return AnimatedBuilder(
          animation: heartAnim,
          builder: (context, child) {
            final val = heartAnim.value;
            final opacity = val.clamp(0.0, 1.0);
            final scale = 0.5 + 0.5 * val;
            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: child,
              ),
            );
          },
          child: baseItem,
        );
      }),
    );
  }
}
