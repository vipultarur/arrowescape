import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/app_colors.dart';
import '../../../core/constants.dart';

class GameTimerDisplay extends StatelessWidget {
  final int timeRemaining;
  final int totalTime;
  final LevelType levelType;

  const GameTimerDisplay({
    super.key,
    required this.timeRemaining,
    required this.totalTime,
    required this.levelType,
  });

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isLowTime = timeRemaining <= 15 || timeRemaining <= totalTime * 0.15;
    final progress = (timeRemaining / totalTime).clamp(0.0, 1.0);

    final color = isLowTime
        ? const Color(0xFFCC2200)
        : (levelType == LevelType.god
            ? AppColors.accent
            : AppColors.accentOrange);

    Widget content = Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLowTime ? const Color(0xFFCC2200) : AppColors.surfaceLight,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isLowTime ? 0.3 : 0.1),
            blurRadius: isLowTime ? 8 : 4,
            spreadRadius: isLowTime ? 1 : 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.hourglass,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _formatTime(timeRemaining),
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.surfaceLight.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );

    if (isLowTime) {
      content = content
          .animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          )
          .scaleXY(
              begin: 0.96,
              end: 1.04,
              duration: 400.ms,
              curve: Curves.easeInOut);
    }

    return content;
  }
}
