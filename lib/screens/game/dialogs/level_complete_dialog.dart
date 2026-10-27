import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/app_colors.dart';
import '../../../core/audio_manager.dart';
import '../../../core/localization.dart';
import '../../../data/models/level.dart';
import '../../../widgets/game_3d_star.dart';
import '../widgets/dialog_3d_button.dart';

class LevelCompleteDialog extends StatelessWidget {
  final LevelModel level;
  final int stars;
  final int score;
  final int coinsEarned;
  final bool isDailyMode;
  final VoidCallback onNextLevel;
  final VoidCallback onMenu;

  const LevelCompleteDialog({
    super.key,
    required this.level,
    required this.stars,
    required this.score,
    required this.coinsEarned,
    this.isDailyMode = false,
    required this.onNextLevel,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 50),
            padding: const EdgeInsets.fromLTRB(22, 60, 22, 24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface : Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('level'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF52C41A),
                    height: 1.0,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  context.tr('completed'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E702D),
                    height: 1.05,
                    letterSpacing: 1.0,
                  ),
                ),

                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceLight
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? AppColors.surfaceLight
                          : const Color(0xFFFEF3C7),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/shop/coin.png',
                        width: 26,
                        height: 26,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '+${NumberFormat('#,###').format(coinsEarned)}',
                        style: GoogleFonts.nunito(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? AppColors.textPrimary
                              : const Color(0xFF1F2937),
                        ),
                      ),

                      const SizedBox(width: 12),
                      Container(
                        width: 1.5,
                        height: 22,
                        color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                      ),
                      const SizedBox(width: 12),

                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Game3DStar(
                              size: 20,
                              isFilled: i < stars,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ).animate(delay: 250.ms).fadeIn().scale(curve: Curves.elasticOut),

                const SizedBox(height: 24),

                if (isDailyMode) ...[
                  Dialog3DButton(
                    label: context.tr('next_level'),
                    topColor: const Color(0xFF52C41A),
                    bottomColor: const Color(0xFF389E0D),
                    textColor: Colors.white,
                    onTap: () {
                      AudioManager.instance.playClick();
                      onNextLevel();
                    },
                  ),
                  const SizedBox(height: 12),
                ] else if (level.levelNumber == 500) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.accentGold.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          LucideIcons.trophy,
                          color: AppColors.accentGold,
                          size: 36,
                        ).animate(onPlay: (c) => c.repeat()).scale(
                              begin: const Offset(0.9, 0.9),
                              end: const Offset(1.1, 1.1),
                              duration: 1.seconds,
                              curve: Curves.easeInOut,
                            ),
                        const SizedBox(height: 10),
                        Text(
                          context.tr('game_finished_title'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accentGold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr('game_finished_desc'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 13.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Dialog3DButton(
                    label: context.tr('next_level'),
                    topColor: const Color(0xFF52C41A),
                    bottomColor: const Color(0xFF389E0D),
                    textColor: Colors.white,
                    onTap: () {
                      AudioManager.instance.playClick();
                      onNextLevel();
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                Dialog3DButton(
                  label: context.tr('home'),
                  topColor: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                  bottomColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                  textColor: isDark ? Colors.white : const Color(0xFF4B5563),
                  onTap: () {
                    AudioManager.instance.playClick();
                    onMenu();
                  },
                ),
              ],
            ),
          ),

          Positioned(
            top: 0,
            child: _AnimatedTopStars(stars: stars),
          ),
        ],
      ),
    );
  }
}

class _AnimatedTopStars extends StatefulWidget {
  final int stars;

  const _AnimatedTopStars({required this.stars});

  @override
  State<_AnimatedTopStars> createState() => _AnimatedTopStarsState();
}

class _AnimatedTopStarsState extends State<_AnimatedTopStars>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _scaleAnimations;
  late final List<bool> _isFilledList;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 320),
      );
    });

    _scaleAnimations = _controllers.map((ctrl) {
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.45), weight: 50),
        TweenSequenceItem(tween: Tween<double>(begin: 1.45, end: 1.0), weight: 50),
      ]).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeInOut));
    }).toList();

    _isFilledList = List.generate(3, (i) => false);

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 150));
    final starCount = widget.stars.clamp(0, 3);
    final indices = [0, 2, 1]; // animate Left, Right, then Center

    for (int step = 0; step < 3; step++) {
      final starIndex = indices[step];
      final bool shouldFill = step < starCount;

      if (shouldFill) {
        if (mounted) {
          setState(() {
            _isFilledList[starIndex] = true;
          });
        }
        _controllers[starIndex].forward(from: 0.0);
        await Future.delayed(const Duration(milliseconds: 220));
      }
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 12,
            top: 22,
            child: Transform.rotate(
              angle: -0.28,
              child: AnimatedBuilder(
                animation: _scaleAnimations[0],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _controllers[0].isAnimating
                        ? _scaleAnimations[0].value
                        : 1.0,
                    child: Game3DStar(
                      size: 54,
                      isFilled: _isFilledList[0],
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 22,
            child: Transform.rotate(
              angle: 0.28,
              child: AnimatedBuilder(
                animation: _scaleAnimations[2],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _controllers[2].isAnimating
                        ? _scaleAnimations[2].value
                        : 1.0,
                    child: Game3DStar(
                      size: 54,
                      isFilled: _isFilledList[2],
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: AnimatedBuilder(
              animation: _scaleAnimations[1],
              builder: (context, child) {
                return Transform.scale(
                  scale: _controllers[1].isAnimating
                      ? _scaleAnimations[1].value
                      : 1.0,
                  child: Game3DStar(
                    size: 80,
                    isFilled: _isFilledList[1],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
