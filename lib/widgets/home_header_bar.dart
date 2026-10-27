import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../data/repositories/progress_repository.dart';
/// Top Header Appbar with Coin, Heart/Lives, and Stars Pills.
/// Matches reference image with 3D assets (coin.png, hart.webp, star.webp).
class HomeHeaderBar extends StatelessWidget {
  const HomeHeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();

    // Compute total stars collected across all unlocked levels
    int totalStars = 0;
    for (int i = 1; i <= progress.highestUnlockedLevel; i++) {
      totalStars += progress.getStarsForLevel(i);
    }

    final coinsCount = progress.coins;
    final livesCount = progress.lives;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // ── 1. Coin Pill (Left) ──────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/shop'),
              child: _buildHeaderPill(
                assetPath: 'assets/images/shop/coin.png',
                text: '$coinsCount',
                showPlusBadge: true,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ── 2. Lives / Heart Pill (Middle) ───────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/shop'),
              child: _buildHeaderPill(
                assetPath: 'assets/images/shop/hart.webp',
                text: '$livesCount',
                overlayText: '$livesCount',
                showPlusBadge: progress.lives < progress.maxLives,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ── 3. Stars Pill (Right) ─────────────────────────────────────────
          Expanded(
            child: _buildHeaderPill(
              assetPath: 'assets/images/shop/star.webp',
              text: '$totalStars',
              showPlusBadge: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPill({
    required String assetPath,
    required String text,
    bool showPlusBadge = false,
    String? overlayText,
  }) {
    return Stack(
      alignment: Alignment.centerLeft,
      clipBehavior: Clip.none,
      children: [
        // ── Translucent Pill Background Container ──────────────────────────
        Container(
          height: 38,
          margin: const EdgeInsets.only(left: 14),
          padding: const EdgeInsets.only(left: 28, right: 12),
          decoration: BoxDecoration(
            color: AppColors.headerPillBg,
            borderRadius: BorderRadius.circular(20),
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
          child: Center(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        // ── Overhanging 3D Asset Image Resting on Left Edge ────────────────
        Positioned(
          left: 0,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Image.asset(
                assetPath,
                width: 38,
                height: 38,
                fit: BoxFit.contain,
              ),

              // White bold text overlay on icon (for heart number)
              if (overlayText != null)
                Text(
                  overlayText,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        offset: const Offset(0, 1.5),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),

              // Green + Badge at Bottom-Right of Icon
              if (showPlusBadge)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF22C55E),
                      border: Border.all(color: Colors.white, width: 1.2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 9,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
