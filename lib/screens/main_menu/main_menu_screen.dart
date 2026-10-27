import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/audio_manager.dart';
import '../../core/constants.dart';
import '../../core/localization.dart';
import '../../data/repositories/level_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../widgets/home_header_bar.dart';
import '../../widgets/level_path_widget.dart';
import '../../widgets/game_3d_button.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  bool _isNavigating = false;
  int _selectedLevel = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final progress = context.read<ProgressRepository>();
      progress.recordDailyPlay();
      setState(() {
        _selectedLevel = progress.currentLevel;
      });
      _preWarmLevels();
      _checkPlayStoreUpdate();
    });
  }

  void _preWarmLevels() {
    final progress = context.read<ProgressRepository>();
    final levelRepo = context.read<LevelRepository>();
    final currentLevel = progress.currentLevel;
    levelRepo.preGenerateRangeAsync(currentLevel, 8);
    levelRepo.trimCache(currentLevel);
  }

  Future<void> _checkPlayStoreUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      debugPrint('Play Store update check failed: $e');
    }
  }

  void _onPlayPressed() async {
    if (_isNavigating) return;
    AudioManager.instance.playClick();
    if (mounted) setState(() => _isNavigating = true);

    try {
      final progress = context.read<ProgressRepository>();
      if (!progress.hasLives) {
        await progress.restoreLives();
      }
      await progress.setCurrentLevel(_selectedLevel);
      if (mounted) {
        await Navigator.pushNamed(
          context,
          '/game',
          arguments: {'level': _selectedLevel},
        );
      }
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  void _onDailyPressed() {
    AudioManager.instance.playClick();
    final progress = context.read<ProgressRepository>();
    if (progress.vibrationEnabled) {
      HapticFeedback.selectionClick();
    }
    Navigator.pushNamed(context, '/daily_challenges');
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();
    final isCompleted = progress.isLevelCompleted(_selectedLevel);
    final levelType = AppConstants.levelTypeFor(_selectedLevel);
    final isHard = levelType != LevelType.normal;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Stack(
            children: [
              // ── 1. Scrollable Level Path Map (Bottom to Top) ──────────
              Positioned.fill(
                child: LevelPathWidget(
                  selectedLevel: _selectedLevel,
                  onSelectLevel: (lvl) {
                    setState(() => _selectedLevel = lvl);
                  },
                ),
              ),

              // ── 2. Fixed Top Header Stats Bar ──────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: AppColors.background.withValues(alpha: 0.95),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: const HomeHeaderBar(),
                ),
              ),

              // ── 3. Floating Animated Daily Challenge Button (Left Side) ─
              Positioned(
                left: 14,
                top: 72,
                child: _AnimatedDailyButton(
                  onTap: _onDailyPressed,
                ),
              ),

              // ── 4. Floating Bottom Action Card (PLAY / REPLAY Button) ──
              Positioned(
                left: 24,
                right: 24,
                bottom: 16,
                child: Center(
                  child: Game3DButton(
                    title: isCompleted ? context.tr('replay') : context.tr('play'),
                    subtext: '${context.tr('level')} $_selectedLevel',
                    tagText: isHard ? context.tr('hard_level') : null,
                    isGreen: !isCompleted,
                    onTap: _onPlayPressed,
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

class _AnimatedDailyButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AnimatedDailyButton({required this.onTap});

  @override
  State<_AnimatedDailyButton> createState() => _AnimatedDailyButtonState();
}

class _AnimatedDailyButtonState extends State<_AnimatedDailyButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF3B82F6),
                  width: 2.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: AppColors.isDark ? 0.45 : 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: Image.asset(
                  'assets/images/nav/daily.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    LucideIcons.calendar,
                    color: Color(0xFF3B82F6),
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                context.tr('daily'),
                style: GoogleFonts.nunito(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1.05, 1.05),
              duration: 1200.ms,
              curve: Curves.easeInOut,
            )
            .moveY(
              begin: 0,
              end: -4,
              duration: 1200.ms,
              curve: Curves.easeInOut,
            ),
      ),
    );
  }
}

