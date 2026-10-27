import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../ads/ad_manager.dart';
import '../core/app_colors.dart';
import '../core/audio_manager.dart';
import '../core/constants.dart';
import '../core/localization.dart';
import '../data/repositories/progress_repository.dart';

/// Shows an "Out of Lives" dialog or bottom sheet allowing players to refill hearts.
Future<bool> showOutOfLivesDialog(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _OutOfLivesBottomSheet(),
  );
  return result ?? false;
}

class _OutOfLivesBottomSheet extends StatefulWidget {
  const _OutOfLivesBottomSheet();

  @override
  State<_OutOfLivesBottomSheet> createState() => _OutOfLivesBottomSheetState();
}

class _OutOfLivesBottomSheetState extends State<_OutOfLivesBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();
    final adManager = context.read<AdManager>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timerText = progress.formattedTimeUntilNextLife;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 20),

            // Heart Icon
            SizedBox(
              width: 80,
              height: 80,
              child: Image.asset(
                'assets/images/shop/hart.webp',
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 16),

            // Title
            Text(
              context.tr('out_of_lives_exclamation'),
              style: GoogleFonts.nunito(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFF2D55),
                letterSpacing: 1.0,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              timerText.isNotEmpty
                  ? '${context.tr('next_free_heart')} $timerText'
                  : context.tr('zero_hearts_left'),
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 22),

            // ── Option 1: Buy 1 Heart for 15 Coins ─────────────────────────────
            _3DDialogOption(
              icon: LucideIcons.heart,
              title: '${context.tr('buy_1_heart')} (${AppConstants.heartCoinCost} COINS)',
              subtitle: '${context.tr('current_coins')}: ${progress.coins}',
              btnColor: const Color(0xFFFF2D55),
              borderColor: const Color(0xFFFF8099),
              shadowColor: const Color(0xFF990022),
              onTap: () async {
                if (progress.coins >= AppConstants.heartCoinCost) {
                  final success = await progress.buyHeart();
                  if (success && context.mounted) {
                    Navigator.pop(context, true);
                  }
                } else {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.tr('need_coins_msg'),
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
            ),

            const SizedBox(height: 12),

            // ── Option 2: Watch Ad for 1 Heart ────────────────────────────────
            _3DDialogOption(
              icon: LucideIcons.clapperboard,
              title: context.tr('get_1_free_heart'),
              subtitle: context.tr('watch_ad_refill'),
              btnColor: const Color(0xFF34C759),
              borderColor: const Color(0xFF86EFAC),
              shadowColor: const Color(0xFF14532D),
              onTap: () {
                bool rewarded = false;
                adManager.showRewardedWithLoader(
                  context,
                  onRewarded: () {
                    rewarded = true;
                    if (!context.mounted) return;
                    progress.restoreLives(amount: 1);
                    Navigator.pop(context, true);
                  },
                  onDismissed: () {
                    if (!rewarded && context.mounted) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.tr('ad_not_completed'),
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
            ),

            const SizedBox(height: 12),

            // ── Option 3: Go to Shop ──────────────────────────────────────────
            _3DDialogOption(
              icon: LucideIcons.shoppingBag,
              title: context.tr('go_to_shop'),
              subtitle: context.tr('get_more_coins_offers'),
              btnColor: const Color(0xFF3B82F6),
              borderColor: const Color(0xFF93C5FD),
              shadowColor: const Color(0xFF1E3A8A),
              onTap: () {
                Navigator.pop(context, false);
                Navigator.pushNamed(context, '/shop');
              },
            ),

            const SizedBox(height: 16),

            // Cancel Button
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                context.tr('quit'),
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _3DDialogOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color btnColor;
  final Color borderColor;
  final Color shadowColor;
  final VoidCallback onTap;

  const _3DDialogOption({
    required this.icon,
    required this.title,
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: btnColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.8),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
