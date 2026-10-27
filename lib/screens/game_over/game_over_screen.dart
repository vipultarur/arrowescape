import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../ads/ad_manager.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../core/audio_manager.dart';
import '../../data/repositories/progress_repository.dart';

class GameOverScreen extends StatelessWidget {
  const GameOverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final levelNumber = args?['level'] as int? ?? 1;
    final adManager = context.read<AdManager>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Image.asset(
                    'assets/images/heartbreak.webp',
                    fit: BoxFit.contain,
                  ),
                )
                    .animate()
                    .shake(duration: 600.ms)
                    .then()
                    .fadeIn(),

                const SizedBox(height: 24),

                Text(
                  'Out of Lives!',
                  style: GoogleFonts.nunito(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.3),

                const SizedBox(height: 6),

                Text(
                  'LEVEL $levelNumber',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ).animate(delay: 300.ms).fadeIn(),

                const SizedBox(height: 36),

                // Lives display (3 empty heart slots)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (_) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.surfaceLight,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.favorite,
                        color: AppColors.heartEmpty,
                        size: 24,
                      ),
                    ),
                  ),
                ).animate(delay: 400.ms).fadeIn(),

                const SizedBox(height: 32),

                // Buy 1 Heart 3D Button (15 Coins)
                _3DActionButton(
                  icon: LucideIcons.heart,
                  label: 'Buy 1 Heart (15 Coins)',
                  subtitle: 'Spend 15 coins to get 1 life and continue',
                  btnColor: const Color(0xFFFF2D55),
                  borderColor: const Color(0xFFFF8099),
                  shadowColor: const Color(0xFF990022),
                  onTap: () async {
                    final progress = context.read<ProgressRepository>();
                    if (progress.coins >= AppConstants.heartCoinCost) {
                      final success = await progress.buyHeart();
                      if (success && context.mounted) {
                        Navigator.pushReplacementNamed(
                          context,
                          '/game',
                          arguments: {'level': levelNumber, 'revived': true},
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Need ${AppConstants.heartCoinCost} coins to buy a heart!',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: const Color(0xFFC0392B),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ).animate(delay: 450.ms).fadeIn().slideY(begin: 0.3),

                const SizedBox(height: 12),

                // Get 1 More Life 3D Button
                _3DActionButton(
                  icon: LucideIcons.clapperboard,
                  label: 'Get 1 Life & Continue',
                  subtitle: 'Watch a short video to revive',
                  btnColor: const Color(0xFF34C759),
                  borderColor: const Color(0xFFFFD600),
                  shadowColor: const Color(0xFF1E8E3E),
                  onTap: () {
                    bool rewarded = false;
                    adManager.showRewardedWithLoader(
                      context,
                      onRewarded: () {
                        rewarded = true;
                        if (!context.mounted) return;
                        Navigator.pushReplacementNamed(
                          context,
                          '/game',
                          arguments: {'level': levelNumber, 'revived': true},
                        );
                      },
                      onDismissed: () {
                        if (!rewarded && context.mounted) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Ad not completed. Try watching again or restart level.',
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: const Color(0xFFC0392B),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    );
                  },
                ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.3),

                const SizedBox(height: 16),

                // Restart Level 3D Button
                _3DActionButton(
                  icon: LucideIcons.rotateCcw,
                  label: 'Restart Level',
                  subtitle: 'Start over with full lives',
                  btnColor: AppColors.surface,
                  borderColor: AppColors.accent,
                  shadowColor: AppColors.surfaceLight,
                  onTap: () async {
                    final progress = context.read<ProgressRepository>();
                    if (!progress.hasLives) {
                      await progress.restoreLives();
                    }
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(
                        context,
                        '/game',
                        arguments: {'level': levelNumber},
                      );
                    }
                  },
                ).animate(delay: 600.ms).fadeIn().slideY(begin: 0.3),

                const SizedBox(height: 20),

                // Back to Menu Button
                TextButton(
                  onPressed: () {
                    AudioManager.instance.playClick();
                    Navigator.pushReplacementNamed(context, '/menu');
                  },
                  child: Text(
                    'MAIN MENU',
                    style: GoogleFonts.nunito(
                      color: const Color(0xFF94A3B8),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ).animate(delay: 700.ms).fadeIn(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _3DActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color btnColor;
  final Color borderColor;
  final Color shadowColor;
  final VoidCallback onTap;

  const _3DActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.btnColor,
    required this.borderColor,
    required this.shadowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioManager.instance.playClick();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: btnColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: borderColor,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Colors.white),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
