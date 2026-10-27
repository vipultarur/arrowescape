import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_colors.dart';
import '../../../core/audio_manager.dart';
import '../../../core/constants.dart';
import '../../../core/localization.dart';
import '../../../data/models/level.dart';
import '../widgets/dialog_3d_button.dart';

class GameOverDialog extends StatelessWidget {
  final LevelModel level;
  final bool isTimeout;
  final int continueTime;
  final VoidCallback? onBuyHeart;
  final VoidCallback onContinue;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  const GameOverDialog({
    super.key,
    required this.level,
    this.isTimeout = false,
    this.continueTime = 0,
    this.onBuyHeart,
    required this.onContinue,
    required this.onRestart,
    required this.onMenu,
  });

  bool get _showAds =>
      AppConstants.enableAdMob ||
      AppConstants.enableUnityAds ||
      AppConstants.enableAppLovin;

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
            margin: const EdgeInsets.only(top: 48),
            padding: const EdgeInsets.fromLTRB(22, 56, 22, 24),
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
                  isTimeout ? context.tr('out_of_time') : context.tr('out_of_lives_exclamation'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFEF4444),
                    letterSpacing: 1.0,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  isTimeout
                      ? '${context.tr('out_of_time_desc')} ${level.levelNumber}'
                      : context.tr('out_of_lives_desc'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 22),

                if (onBuyHeart != null) ...[
                  Dialog3DButton(
                    label: '${context.tr('buy_1_heart')} (${AppConstants.heartCoinCost} COINS)',
                    topColor: const Color(0xFFFF2D55),
                    bottomColor: const Color(0xFFD61A40),
                    textColor: Colors.white,
                    onTap: () {
                      AudioManager.instance.playClick();
                      onBuyHeart!();
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                if (_showAds) ...[
                  Dialog3DButton(
                    label: isTimeout
                        ? '+${continueTime}s ${context.tr('resume')}'
                        : '1 ${context.tr('get_lives')} & ${context.tr('resume')}',
                    topColor: const Color(0xFF52C41A),
                    bottomColor: const Color(0xFF389E0D),
                    textColor: Colors.white,
                    onTap: () {
                      AudioManager.instance.playClick();
                      onContinue();
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                Dialog3DButton(
                  label: context.tr('restart_level'),
                  topColor: const Color(0xFF3B82F6),
                  bottomColor: const Color(0xFF1D4ED8),
                  textColor: Colors.white,
                  onTap: () {
                    AudioManager.instance.playClick();
                    onRestart();
                  },
                ),

                const SizedBox(height: 12),

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
            child: SizedBox(
              width: 96,
              height: 96,
              child: Image.asset(
                'assets/images/heartbreak.webp',
                fit: BoxFit.contain,
              ),
            ).animate().scale(
                begin: const Offset(0, 0),
                end: const Offset(1, 1),
                duration: 450.ms,
                curve: Curves.elasticOut).shake(duration: 500.ms, delay: 450.ms),
          ),
        ],
      ),
    );
  }
}
