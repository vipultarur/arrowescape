import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart';
import '../../../core/audio_manager.dart';
import '../../../core/localization.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../widgets/app_bar_buttons.dart';
import '../../../widgets/game_3d_toggle.dart';

class GameSettingsDialog extends StatelessWidget {
  final VoidCallback onRestart;

  const GameSettingsDialog({
    super.key,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();
    final isDark = AppColors.isDark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        LucideIcons.settings,
                        color: Color(0xFF3B82F6),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.tr('settings'),
                      style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const AppCloseButton(size: 34),
              ],
            ),

            const SizedBox(height: 20),

            _DialogSettingsTile(
              icon: LucideIcons.volume2,
              iconBgColor: const Color(0xFF3B82F6),
              label: context.tr('sound_effects'),
              value: progress.soundEnabled,
              onChanged: (val) => progress.setSoundEnabled(val),
            ),

            const SizedBox(height: 10),

            _DialogSettingsTile(
              icon: LucideIcons.music,
              iconBgColor: const Color(0xFFF59E0B),
              label: context.tr('bg_music_label'),
              value: progress.musicEnabled,
              onChanged: (val) => progress.setMusicEnabled(val),
            ),

            const SizedBox(height: 10),

            _DialogSettingsTile(
              icon: LucideIcons.vibrate,
              iconBgColor: const Color(0xFF10B981),
              label: context.tr('vibration_feedback'),
              value: progress.vibrationEnabled,
              onChanged: (val) => progress.setVibrationEnabled(val),
            ),

            const SizedBox(height: 22),

            _DialogActionButton(
              label: context.tr('restart_level'),
              icon: LucideIcons.rotateCcw,
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              ),
              onTap: () {
                Navigator.pop(context);
                onRestart();
              },
            ),

            const SizedBox(height: 10),

            _DialogActionButton(
              label: context.tr('resume_game'),
              icon: LucideIcons.play,
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF334155), const Color(0xFF1E293B)]
                    : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
              ),
              textColor: AppColors.textPrimary,
              iconColor: AppColors.textPrimary,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogSettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DialogSettingsTile({
    required this.icon,
    required this.iconBgColor,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.surfaceLight.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconBgColor, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Game3DToggleSwitch(
            value: value,
            onChanged: (val) {
              AudioManager.instance.playClick();
              onChanged(val);
            },
          ),
        ],
      ),
    );
  }
}

class _DialogActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  final Color textColor;
  final Color iconColor;

  const _DialogActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.textColor = Colors.white,
    this.iconColor = Colors.white,
  });

  @override
  State<_DialogActionButton> createState() => _DialogActionButtonState();
}

class _DialogActionButtonState extends State<_DialogActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        AudioManager.instance.playClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 3.5),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.2,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: widget.iconColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: widget.textColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
