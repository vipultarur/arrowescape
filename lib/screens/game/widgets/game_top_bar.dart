import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/app_colors.dart';
import '../../../core/constants.dart';
import '../../../core/localization.dart';
import '../../../data/models/level.dart';
import '../../../widgets/app_bar_buttons.dart';

class GameTopBar extends StatelessWidget {
  final LevelModel level;
  final LevelType levelType;
  final int lives;
  final double progress;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final AnimationController? entranceController;
  final DateTime? dailyDate;

  const GameTopBar({
    super.key,
    required this.level,
    required this.levelType,
    required this.lives,
    required this.progress,
    required this.onBack,
    required this.onSettings,
    this.entranceController,
    this.dailyDate,
  });

  String _getDifficultyText(BuildContext context, LevelType type, int levelNum) {
    if (type == LevelType.god) return context.tr('super_hard');
    if (type == LevelType.boss) return context.tr('hard');
    final difficulty = Difficulty.forLevel(levelNum);
    if (difficulty == Difficulty.tutorial || difficulty == Difficulty.easy) {
      return context.tr('easy');
    }
    if (difficulty == Difficulty.medium) return context.tr('normal');
    if (difficulty == Difficulty.hard) return context.tr('hard');
    return difficulty.label;
  }

  @override
  Widget build(BuildContext context) {
    final double rawVal = entranceController?.value ?? 1.0;
    final double hudProgress = entranceController != null
        ? (const Interval(0.70, 0.93, curve: Curves.easeOutBack)
            .transform(rawVal))
        : 1.0;
    final double opacity = hudProgress.clamp(0.0, 1.0);
    final double scale = 0.85 + 0.15 * hudProgress;

    final effectiveType = dailyDate != null
        ? (dailyDate!.day % 3 == 0
            ? LevelType.god
            : (dailyDate!.day % 2 == 0 ? LevelType.boss : LevelType.normal))
        : levelType;

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top Row: Back Button, Title (Date/Level), Settings Button ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppBackButton(onTap: onBack),
                  Text(
                    dailyDate != null
                        ? DateFormat('MMMM d').format(dailyDate!)
                        : '${context.tr('level')} ${level.levelNumber}',
                    style: GoogleFonts.nunito(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  AppSettingsButton(onTap: onSettings),
                ],
              ),
              const SizedBox(height: 10),
              // ── Bottom Row: Level Pill, Lives Bar (Hearts), Difficulty Pill ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.rotate(
                          angle: 0.785,
                          child: Icon(
                            LucideIcons.navigation,
                            color: AppColors.textSecondary,
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${level.levelNumber}',
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(AppConstants.maxLives, (index) {
                      final isFilled = index < lives;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: isFilled
                              ? const Color(0xFFEF4444)
                              : AppColors.surfaceLight,
                          size: 28,
                        ),
                      );
                    }),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _getDifficultyText(context, effectiveType, level.levelNumber),
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
