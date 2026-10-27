import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/audio_manager.dart';
import '../../core/constants.dart';
import '../../core/localization.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/level_repository.dart';
import '../../data/level_generator/level_schedule.dart';
import '../../widgets/app_bar_buttons.dart';
import '../../widgets/unified_banner_ad.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();
    final totalVisible = LevelRepository.totalLevels;

    int totalStars = 0;
    for (int i = 1; i <= progress.highestUnlockedLevel; i++) {
      totalStars += progress.getStarsForLevel(i);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 6),

              // ── 3D Header Bar ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(
                  children: [
                    const AppBackButton(),
                    const SizedBox(width: 14),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('select_level'),
                          style: GoogleFonts.nunito(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${context.tr('unlocked')} ${progress.highestUnlockedLevel}/$totalVisible',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Total Stars Header Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.headerPillBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.headerPillBorder,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: AppColors.isDark ? 0.3 : 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFCA28),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$totalStars',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // ── 3D Level Selection Grid ──────────────────────────────────
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: totalVisible,
                  itemBuilder: (context, index) {
                    final levelNum = index + 1;
                    final isUnlocked = progress.isLevelUnlocked(levelNum);
                    final isCurrent = levelNum == progress.currentLevel;
                    final isCompleted = progress.isLevelCompleted(levelNum);
                    final stars = progress.getStarsForLevel(levelNum);
                    final levelType = AppConstants.levelTypeFor(levelNum);

                    return _LevelCell(
                      levelNumber: levelNum,
                      isUnlocked: isUnlocked,
                      isCurrent: isCurrent,
                      isCompleted: isCompleted,
                      stars: stars,
                      levelType: levelType,
                      onTap: isUnlocked
                          ? () async {
                              AudioManager.instance.playClick();
                              if (progress.vibrationEnabled) {
                                HapticFeedback.selectionClick();
                              }
                              if (!progress.hasLives) {
                                await progress.restoreLives();
                              }
                              progress.setCurrentLevel(levelNum);
                              if (context.mounted) {
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/game',
                                  arguments: {'level': levelNum},
                                );
                              }
                            }
                          : () {
                              if (progress.vibrationEnabled) {
                                HapticFeedback.selectionClick();
                              }
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.lock,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Level $levelNum is locked!',
                                        style: GoogleFonts.nunito(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFFC0392B),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                    )
                        .animate(delay: Duration(milliseconds: (index % 24) * 15))
                        .fadeIn(duration: 250.ms)
                        .scale(
                          begin: const Offset(0.85, 0.85),
                          end: const Offset(1.0, 1.0),
                          curve: Curves.easeOutCubic,
                        );
                  },
                ),
              ),

              // ── Bottom Banner Ad ──────────────────────────────────────────
              const SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 6),
                  child: Center(
                    child: UnifiedBannerAd(
                      admobUnitId: AppConstants.admobBannerUnitId,
                      unityPlacementId: AppConstants.unityBannerAdId,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCell extends StatelessWidget {
  final int levelNumber;
  final bool isUnlocked;
  final bool isCurrent;
  final bool isCompleted;
  final int stars;
  final LevelType levelType;
  final VoidCallback onTap;

  const _LevelCell({
    required this.levelNumber,
    required this.isUnlocked,
    required this.isCurrent,
    required this.isCompleted,
    required this.stars,
    required this.levelType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isShapeLevel = LevelSchedule.isShapePuzzle(levelNumber);

    // 3D Color definitions matching new theme
    final Color topColor = isShapeLevel
        ? (isCurrent
            ? const Color(0xFFFF6B6B)
            : isCompleted
                ? const Color(0xFFFF5252)
                : const Color(0xFFE53935))
        : (isCurrent
            ? const Color(0xFF34C759)
            : isCompleted
                ? const Color(0xFFFFB700)
                : isUnlocked
                    ? AppColors.surface
                    : AppColors.surfaceLight);

    final Color shadowColor = isShapeLevel
        ? const Color(0xFFC62828)
        : (isCurrent
            ? const Color(0xFF1E8E3E)
            : isCompleted
                ? const Color(0xFFC66900)
                : isUnlocked
                    ? (AppColors.isDark ? const Color(0xFF111728) : const Color(0xFFCBD5E1))
                    : (AppColors.isDark ? const Color(0xFF0F1522) : const Color(0xFF94A3B8)));

    final Color borderColor = isShapeLevel
        ? const Color(0xFFFFCDD2)
        : (isCurrent
            ? const Color(0xFFFFD600)
            : isCompleted
                ? Colors.white
                : isUnlocked
                    ? AppColors.accent
                    : AppColors.surfaceLight);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: topColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isCurrent ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              offset: const Offset(0, 5),
            ),
            if (isCurrent)
              BoxShadow(
                color: const Color(0xFFFFD600).withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isUnlocked && levelType == LevelType.boss)
              const Positioned(
                top: 5,
                right: 5,
                child: Icon(
                  LucideIcons.crown,
                  color: Color(0xFFFFD600),
                  size: 13,
                ),
              )
            else if (isUnlocked && levelType == LevelType.god)
              const Positioned(
                top: 5,
                right: 5,
                child: Icon(
                  LucideIcons.zap,
                  color: Color(0xFFFF3D00),
                  size: 13,
                ),
              ),

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$levelNumber',
                      style: GoogleFonts.nunito(
                        fontSize: levelNumber >= 100 ? 16 : 19,
                        fontWeight: FontWeight.w900,
                        color: (isCurrent || isCompleted)
                            ? Colors.white
                            : (isUnlocked ? AppColors.textPrimary : const Color(0xFF2C384E)),
                        shadows: (isCurrent || isCompleted || (isUnlocked && AppColors.isDark))
                            ? [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
                if (stars > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (i) => Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: i < stars ? const Color(0xFFFFD600) : Colors.white30,
                      ),
                    ),
                  ),
                ] else if (isCurrent) ...[
                  const SizedBox(height: 2),
                  Text(
                    'PLAY',
                    style: GoogleFonts.nunito(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
