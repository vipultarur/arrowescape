import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/audio_manager.dart';
import '../core/localization.dart';
import '../data/repositories/progress_repository.dart';
import '../data/repositories/level_repository.dart';
import '../data/level_generator/level_schedule.dart';
import 'game_3d_star.dart';

class LevelPathWidget extends StatefulWidget {
  final int selectedLevel;
  final ValueChanged<int> onSelectLevel;

  const LevelPathWidget({
    super.key,
    required this.selectedLevel,
    required this.onSelectLevel,
  });

  @override
  State<LevelPathWidget> createState() => _LevelPathWidgetState();
}

class _LevelPathWidgetState extends State<LevelPathWidget> {
  late final ScrollController _scrollController;
  bool _showIndicator = false;
  bool _currentIsAbove = false;

  static const double _nodeHeight = 110.0;
  static int get _totalLevels => LevelRepository.totalLevels;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToLevel(widget.selectedLevel, animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant LevelPathWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLevel != widget.selectedLevel) {
      _scrollToLevel(widget.selectedLevel, animate: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final currentLevel = context.read<ProgressRepository>().currentLevel;

    // Index 0 = Level 2000 (top), Index (_totalLevels - 1) = Level 1 (bottom)
    final levelIndex = _totalLevels - currentLevel;
    final targetOffset = levelIndex * _nodeHeight;
    final scrollOffset = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;

    final isVisible = targetOffset >= scrollOffset - 60 &&
        targetOffset <= scrollOffset + viewportHeight - 120;

    if (mounted) {
      setState(() {
        _showIndicator = !isVisible;
        // If targetOffset < scrollOffset, target level is higher up (above current view)
        _currentIsAbove = targetOffset < scrollOffset;
      });
    }
  }

  void _scrollToLevel(int level, {bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final viewportHeight = _scrollController.position.viewportDimension;
    final levelIndex = _totalLevels - level;
    final targetOffset = (levelIndex * _nodeHeight) - (viewportHeight / 2) + 55;

    final clamped = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    if (animate) {
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();

    return Stack(
      children: [
        // ── Scrollable Vertical Path (Level 200 at Top -> Level 1 at Bottom)
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 90, bottom: 150),
          physics: const BouncingScrollPhysics(),
          itemCount: _totalLevels,
          cacheExtent: 600,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            // Level 2000 at top (index 0), Level 1 at bottom (index 1999)
            final levelNum = _totalLevels - index;
            final isUnlocked = progress.isLevelUnlocked(levelNum);
            final isCompleted = progress.isLevelCompleted(levelNum);
            final isCurrent = levelNum == progress.currentLevel;
            final isSelected = levelNum == widget.selectedLevel;
            final stars = progress.getStarsForLevel(levelNum);

            return _buildLevelNode(
              levelNum: levelNum,
              currentLevel: progress.currentLevel,
              isUnlocked: isUnlocked,
              isCompleted: isCompleted,
              isCurrent: isCurrent,
              isSelected: isSelected,
              stars: stars,
              onTap: () {
                if (isUnlocked) {
                  AudioManager.instance.playClick();
                  if (progress.vibrationEnabled) {
                    HapticFeedback.selectionClick();
                  }
                  widget.onSelectLevel(levelNum);
                }
              },
            );
          },
        ),

        // ── Floating Current Level Pill Indicator ───────────────────────
        if (_showIndicator)
          Positioned(
            top: 72,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  AudioManager.instance.playClick();
                  widget.onSelectLevel(progress.currentLevel);
                  _scrollToLevel(progress.currentLevel, animate: true);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFC0D1E5), // 3D depth lip under ice-blue pill
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 3.5),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF9FCFF), Color(0xFFEBF3FE)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomPaint(
                          size: const Size(14, 12),
                          painter: _SolidTrianglePainter(
                            color: const Color(0xFF2563EB),
                            isPointingUp: _currentIsAbove,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          context.tr('current_level'),
                          style: GoogleFonts.nunito(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF2563EB),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLevelNode({
    required int levelNum,
    required int currentLevel,
    required bool isUnlocked,
    required bool isCompleted,
    required bool isCurrent,
    required bool isSelected,
    required int stars,
    required VoidCallback onTap,
  }) {
    // Shape Puzzle levels get the light red theme ONLY when unlocked!
    final bool isShapeLevel = LevelSchedule.isShapePuzzle(levelNum);
    final bool isShapeLevelUnlocked = isShapeLevel && isUnlocked;

    final Color lipColor = isShapeLevelUnlocked
        ? const Color(0xFFC62828)
        : (isCompleted
            ? const Color(0xFFC66400)
            : isUnlocked
                ? const Color(0xFF1E8E3E)
                : AppColors.nodeLockedShadow);

    final List<Color> nodeGradientColors = isShapeLevelUnlocked
        ? (isCurrent
            ? [const Color(0xFFFF6B6B), const Color(0xFFFF3333)]
            : isCompleted
                ? [const Color(0xFFFF5252), const Color(0xFFE53935)]
                : [const Color(0xFFFF6B6B), const Color(0xFFE53935)])
        : (isCompleted
            ? [const Color(0xFFFFAE19), const Color(0xFFFF7E00)]
            : isUnlocked
                ? [const Color(0xFF38D659), const Color(0xFF22C55E)]
                : [AppColors.nodeLockedSilver, AppColors.nodeLockedShadow]);

    final Color bevelColor = isSelected
        ? const Color(0xFFB38600)
        : (isShapeLevelUnlocked ? const Color(0xFFD32F2F) : AppColors.nodeLockedBevel);

    return SizedBox(
      height: _nodeHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── 1. Vertical Level Track Line (Behind Button) ──────────────
          Positioned(
            top: levelNum == _totalLevels ? _nodeHeight / 2 : 0,
            bottom: levelNum == 1 ? _nodeHeight / 2 : 0,
            child: _LevelTrackLine(
              isFilled: isCompleted || (levelNum < currentLevel),
            ),
          ),

          // ── 2. Circular 3D Node Button ────────────────────────────────
          GestureDetector(
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Main 3D Circle Button Container
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bevelColor,
                    boxShadow: [
                      if (isSelected || isShapeLevelUnlocked) ...[
                        BoxShadow(
                          color: isSelected
                              ? const Color(0xFFFFD700).withValues(alpha: 0.75)
                              : const Color(0xFFEF4444).withValues(alpha: 0.5),
                          blurRadius: 18,
                          spreadRadius: 3,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 5),
                        ),
                      ] else ...[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 3.5),
                    padding: EdgeInsets.all(isSelected ? 5.5 : 4.0),
                    decoration: isSelected
                        ? const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFFFF9C4), // Bright golden light top
                                Color(0xFFFFD700), // Rich vibrant gold center
                                Color(0xFFFFA000), // Deep warm gold bottom
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          )
                        : BoxDecoration(
                            shape: BoxShape.circle,
                            color: isShapeLevelUnlocked ? const Color(0xFFFFECEC) : Colors.white,
                          ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: lipColor,
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 3.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: nodeGradientColors,
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$levelNum',
                            style: GoogleFonts.nunito(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: (isUnlocked || isShapeLevelUnlocked) ? Colors.white : const Color(0xFF2C384E),
                              shadows: (isUnlocked || isShapeLevelUnlocked)
                                  ? [
                                      Shadow(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        offset: const Offset(0, 2),
                                        blurRadius: 3,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),


                // 3 Stars on top curve for Completed levels
                if (isCompleted || stars > 0)
                  Positioned(
                    top: -18,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Game3DStarRow(
                        stars: stars,
                        starSize: 26,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }


}

class _SolidTrianglePainter extends CustomPainter {
  final Color color;
  final bool isPointingUp;

  _SolidTrianglePainter({
    required this.color,
    this.isPointingUp = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    if (isPointingUp) {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SolidTrianglePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isPointingUp != isPointingUp;
  }
}

class _LevelTrackLine extends StatelessWidget {
  final bool isFilled;

  const _LevelTrackLine({required this.isFilled});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return CustomPaint(
      size: const Size(22.0, 110.0),
      painter: _TrackLinePainter(
        isFilled: isFilled,
        themeOption: appColors.themeOption,
        channelColor: appColors.pathLineChannel,
        railColor: appColors.pathLineRail,
        fillColor: appColors.pathLineFill,
      ),
    );
  }
}

class _TrackLinePainter extends CustomPainter {
  final bool isFilled;
  final AppThemeOption themeOption;
  final Color channelColor;
  final Color railColor;
  final Color fillColor;

  _TrackLinePainter({
    required this.isFilled,
    required this.themeOption,
    required this.channelColor,
    required this.railColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Draw outer track background channel
    final bgPaint = Paint()
      ..color = channelColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // 2. Draw centered cyan blue fill line if completed
    if (isFilled) {
      const double cyanWidth = 10.0;
      final double inset = (w - cyanWidth) / 2;

      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(inset, 0, cyanWidth, h), fillPaint);
    }

    // 3. Draw outer left & right side rail stroke lines
    final railPaint = Paint()
      ..color = railColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Left vertical rail line
    canvas.drawLine(const Offset(0, 0), Offset(0, h), railPaint);
    // Right vertical rail line
    canvas.drawLine(Offset(w, 0), Offset(w, h), railPaint);
  }

  @override
  bool shouldRepaint(covariant _TrackLinePainter oldDelegate) {
    return oldDelegate.isFilled != isFilled || oldDelegate.themeOption != themeOption;
  }
}
