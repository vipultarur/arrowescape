import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/audio_manager.dart';
import '../../core/localization.dart';
import '../../data/repositories/progress_repository.dart';
import '../../services/daily_challenge_service.dart';
import '../../widgets/app_bar_buttons.dart';
import '../../widgets/game_3d_button.dart';

class DailyChallengesScreen extends StatefulWidget {
  const DailyChallengesScreen({super.key});

  @override
  State<DailyChallengesScreen> createState() => _DailyChallengesScreenState();
}

class _DailyChallengesScreenState extends State<DailyChallengesScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    DailyChallengeService.instance.addListener(_onServiceUpdate);
    DailyChallengeService.instance.checkNotificationsForToday();
  }

  @override
  void dispose() {
    DailyChallengeService.instance.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _onPlayPressed(bool isFutureDate) async {
    if (_isNavigating) return;

    if (isFutureDate) {
      if (mounted) {
        if (context.read<ProgressRepository>().vibrationEnabled) {
          HapticFeedback.selectionClick();
        }
      }
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.lock, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Future challenge! Unlocks on ${DateFormat('MMMM d').format(_selectedDate)}.',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFC0392B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    AudioManager.instance.playClick();
    if (mounted) setState(() => _isNavigating = true);

    try {
      await Navigator.pushNamed(
        context,
        '/game',
        arguments: {'dailyDate': _selectedDate},
      );
    } catch (e) {
      debugPrint('Daily game push error: $e');
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ProgressRepository>();

    final now = DateTime.now();
    final todayZero = DateTime(now.year, now.month, now.day);
    final selectedZero =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final isFutureDate = selectedZero.isAfter(todayZero);
    final isSelectedCompleted =
        DailyChallengeService.instance.isDateCompleted(_selectedDate);

    final monthName = DateFormat('MMMM yyyy').format(_selectedDate);
    final daysInMonth =
        DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    final completedCount = DailyChallengeService.instance
        .getCompletedCountForMonth(_selectedDate.year, _selectedDate.month);

    final firstDayOfWeek =
        DateTime(_selectedDate.year, _selectedDate.month, 1).weekday % 7;

    final isDark = AppColors.isDark;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 4),

              // ── 1. Top Header Bar ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const AppBackButton(),
                    const SizedBox(width: 10),

                    Text(
                      context.tr('daily_challenges'),
                      style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const Spacer(),

                    // Month Star Progress Pill
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.headerPillBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.headerPillBorder,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.3 : 0.1),
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
                            '$completedCount/$daysInMonth',
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

              // ── 2. 3D Hero Trophy Banner Card ──────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                height: 175,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
                          : const Color(0xFF93C5FD),
                      width: 1.8,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background Image
                        Positioned.fill(
                          child: Image.asset(
                            'assets/trophy/trophy background.png',
                            fit: BoxFit.cover,
                          ),
                        ),

                        // Soft dark gradient overlay for deep contrast
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withValues(alpha: 0.35),
                                  Colors.black.withValues(alpha: 0.05),
                                  Colors.black.withValues(alpha: 0.35),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),

                        // Month Trophy Image with Smooth Animations
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: animation,
                              child: FadeTransition(opacity: animation, child: child),
                            );
                          },
                          child: Padding(
                            key: ValueKey<int>(_selectedDate.month),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Image.asset(
                              'assets/trophy/${_selectedDate.month}.png',
                              height: 135,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.emoji_events_rounded,
                                  size: 76,
                                  color: Color(0xFFF59E0B),
                                );
                              },
                            ),
                          )
                              .animate(
                                  onPlay: (controller) =>
                                      controller.repeat(reverse: true))
                              .moveY(
                                begin: 0,
                                end: -5,
                                duration: 1400.ms,
                                curve: Curves.easeInOut,
                              ),
                        ),

                        // Left Month Navigation 3D Button
                        Positioned(
                          left: 12,
                          child: _MonthNavButton(
                            icon: Icons.chevron_left_rounded,
                            onTap: () {
                              AudioManager.instance.playClick();
                              setState(() {
                                _selectedDate = DateTime(
                                  _selectedDate.year,
                                  _selectedDate.month - 1,
                                  1,
                                );
                              });
                            },
                          ),
                        ),

                        // Right Month Navigation 3D Button
                        Positioned(
                          right: 12,
                          child: _MonthNavButton(
                            icon: Icons.chevron_right_rounded,
                            onTap: () {
                              AudioManager.instance.playClick();
                              setState(() {
                                _selectedDate = DateTime(
                                  _selectedDate.year,
                                  _selectedDate.month + 1,
                                  1,
                                );
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── 3. Month Title Row & Quick Nav ─────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          monthName,
                          style: GoogleFonts.nunito(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '$completedCount / $daysInMonth ${context.tr('days_completed')}',
                          style: GoogleFonts.nunito(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    // TODAY Quick Jump Button
                    if (_selectedDate.year != now.year ||
                        _selectedDate.month != now.month ||
                        _selectedDate.day != now.day)
                      GestureDetector(
                        onTap: () {
                          AudioManager.instance.playClick();
                          setState(() => _selectedDate = DateTime.now());
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                            ),
                            borderRadius: BorderRadius.circular(16),
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
                            context.tr('today'),
                            style: GoogleFonts.nunito(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── 4. 3D Calendar Grid Card ────────────────────────────────────
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.surfaceLight.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Days of Week Header Row (S M T W T F S)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                            .map(
                              (day) => Expanded(
                                child: Center(
                                  child: Text(
                                    day,
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),

                      const SizedBox(height: 8),
                      Divider(
                        height: 1,
                        color: AppColors.surfaceLight.withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: 10),

                      // Days Grid
                      Expanded(
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.95,
                          ),
                          itemCount: firstDayOfWeek + daysInMonth,
                          itemBuilder: (context, index) {
                            if (index < firstDayOfWeek) {
                              return const SizedBox.shrink();
                            }

                            final dayNum = index - firstDayOfWeek + 1;
                            final date = DateTime(
                              _selectedDate.year,
                              _selectedDate.month,
                              dayNum,
                            );

                            final isToday = date.year == now.year &&
                                date.month == now.month &&
                                date.day == now.day;
                            final isSelected = date.year == _selectedDate.year &&
                                date.month == _selectedDate.month &&
                                date.day == _selectedDate.day;
                            final isCompleted = DailyChallengeService.instance
                                .isDateCompleted(date);
                            final isFuture =
                                DateTime(date.year, date.month, date.day)
                                    .isAfter(todayZero);
                            final dateProgress = DailyChallengeService.instance
                                .getDateProgress(date);

                            return _CalendarDayCell(
                              dayNum: dayNum,
                              isToday: isToday,
                              isSelected: isSelected,
                              isCompleted: isCompleted,
                              isFuture: isFuture,
                              progress: dateProgress,
                              onTap: () {
                                setState(() {
                                  _selectedDate = date;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── 5. 3D Play / Action Button at Bottom ───────────────────────
              Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
                child: Game3DButton(
                  title: isFutureDate
                      ? context.tr('locked')
                      : (isSelectedCompleted ? context.tr('replay') : context.tr('play')),
                  subtext: DateFormat('MMMM d, yyyy')
                      .format(_selectedDate)
                      .toUpperCase(),
                  tagText: isFutureDate
                      ? context.tr('future_challenge_locked')
                      : (isSelectedCompleted
                          ? '${context.tr('claimed')} ⭐'
                          : context.tr('daily_challenges')),
                  isGreen: !isSelectedCompleted && !isFutureDate,
                  onTap: () => _onPlayPressed(isFutureDate),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthNavButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthNavButton({required this.icon, required this.onTap});

  @override
  State<_MonthNavButton> createState() => _MonthNavButtonState();
}

class _MonthNavButtonState extends State<_MonthNavButton> {
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
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatefulWidget {
  final int dayNum;
  final bool isToday;
  final bool isSelected;
  final bool isCompleted;
  final bool isFuture;
  final double progress;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.dayNum,
    required this.isToday,
    required this.isSelected,
    required this.isCompleted,
    required this.isFuture,
    required this.progress,
    required this.onTap,
  });

  @override
  State<_CalendarDayCell> createState() => _CalendarDayCellState();
}

class _CalendarDayCellState extends State<_CalendarDayCell> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool hasInProgress = widget.progress > 0.0 && !widget.isCompleted;
    final isDark = AppColors.isDark;

    Color faceColor;
    Color lipColor;
    Color textColor;

    if (widget.isCompleted) {
      faceColor = const Color(0xFF22C55E);
      lipColor = const Color(0xFF15803D);
      textColor = Colors.white;
    } else if (widget.isSelected || widget.isToday) {
      faceColor = const Color(0xFF3B82F6);
      lipColor = const Color(0xFF1D4ED8);
      textColor = Colors.white;
    } else if (widget.isFuture) {
      faceColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
      lipColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1);
      textColor = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);
    } else {
      faceColor = isDark ? const Color(0xFF273552) : const Color(0xFFF1F5F9);
      lipColor = isDark ? const Color(0xFF1B263B) : const Color(0xFFE2E8F0);
      textColor = AppColors.textPrimary;
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        AudioManager.instance.playClick();
        if (context.read<ProgressRepository>().vibrationEnabled) {
          HapticFeedback.selectionClick();
        }
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Outer 3D lip container
            Container(
              decoration: BoxDecoration(
                color: lipColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  if (widget.isCompleted || widget.isSelected)
                    BoxShadow(
                      color: faceColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 2.5),
                decoration: BoxDecoration(
                  color: faceColor,
                  borderRadius: BorderRadius.circular(13),
                  border: widget.isSelected
                      ? Border.all(
                          color: const Color(0xFFFFD600),
                          width: 2.0,
                        )
                      : (widget.isToday
                          ? Border.all(color: Colors.white, width: 1.5)
                          : null),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${widget.dayNum}',
                        style: GoogleFonts.nunito(
                          fontSize: 13.5,
                          fontWeight: (widget.isCompleted ||
                                  widget.isSelected ||
                                  widget.isToday)
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      if (widget.isCompleted)
                        const Icon(
                          LucideIcons.check,
                          size: 11,
                          color: Colors.white,
                        )
                      else if (widget.isFuture)
                        Icon(
                          LucideIcons.lock,
                          size: 10,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // In-Progress Circular Ring Overlay
            if (hasInProgress)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: CircularProgressIndicator(
                    value: widget.progress,
                    strokeWidth: 3.0,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.isSelected ? Colors.white : const Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
