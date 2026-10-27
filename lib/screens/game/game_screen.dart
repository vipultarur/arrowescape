import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart' hide Matrix4;
import 'package:provider/provider.dart';
import '../../widgets/unified_banner_ad.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../data/models/arrow.dart';
import '../../data/models/level.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/level_repository.dart';
import '../../services/daily_challenge_service.dart';
import '../../ads/ad_manager.dart';
import '../../game/arrow_puzzle_game.dart';
import '../../game/game_state.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/audio_manager.dart';
import 'widgets/game_top_bar.dart';
import 'widgets/game_timer_display.dart';
import 'dialogs/level_complete_dialog.dart';
import 'dialogs/game_over_dialog.dart';
import 'dialogs/deadlock_dialog.dart';
import 'dialogs/game_settings_dialog.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late LevelModel _level;
  late ArrowPuzzleGame _game;
  GameState? _gameState;
  late AnimationController _entranceController;
  bool _showingGameOver = false;
  bool _showingComplete = false;
  bool _showingDeadlock = false;
  bool _inspectingDeadlock = false;
  int _lives = AppConstants.maxLives;
  int? _loadedLevelNum;
  DateTime? _dailyDate;
  bool _isLoadingLevel = false; // true while level is being generated async

  // Timer fields
  Timer? _levelTimer;
  int _timeRemaining = 0;
  int _totalTime = 0;
  bool _isTimeoutState = false;
  bool _isGamePaused = false;
  bool _isAppBackgrounded = false;

  late final TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transformationController = TransformationController();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _entranceController.addListener(() {
      if (!mounted) return;
      _game.setEntranceProgress(_entranceController.value);
    });
    AudioManager.instance.playBgMusic();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final dailyDate = args?['dailyDate'] as DateTime?;
    final levelNum = args?['level'] as int? ?? 1;

    if (dailyDate != null) {
      if (_dailyDate != dailyDate) {
        _dailyDate = dailyDate;
        _loadedLevelNum = null;
        _loadDailyLevel(dailyDate);
      }
    } else {
      if (_loadedLevelNum != levelNum || _dailyDate != null) {
        _dailyDate = null;
        _loadedLevelNum = levelNum;
        _loadLevel(levelNum);
      }
    }
  }

  void _loadDailyLevel(DateTime date) {
    final levelRepo = context.read<LevelRepository>();
    _level = DailyChallengeService.instance.getLevelForDate(date, levelRepo);
    _isLoadingLevel = false;
    _initGame();
    if (mounted) setState(() {});
  }

  void _loadLevel(int levelNum) async {
    final levelRepo = context.read<LevelRepository>();
    if (levelRepo.isCached(levelNum)) {
      _level = levelRepo.getLevel(levelNum);
      _isLoadingLevel = false;
      _initGame();
      if (mounted) setState(() {});
      levelRepo.preGenerateRangeAsync(levelNum + 1, 5);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showTutorialDialogIfNeeded(levelNum);
      });
    } else {
      if (mounted) {
        setState(() {
          _isLoadingLevel = true;
        });
      }
      final level = await levelRepo.getLevelAsync(levelNum);
      if (!mounted) return;
      setState(() {
        _level = level;
        _isLoadingLevel = false;
      });
      _initGame();
      levelRepo.preGenerateRangeAsync(levelNum + 1, 5);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showTutorialDialogIfNeeded(levelNum);
      });
    }
  }

  void _initGame() {
    final progress = context.read<ProgressRepository>();
    _lives = progress.hasLives ? progress.lives : AppConstants.maxLives;
    _showingGameOver = false;
    _showingDeadlock = false;
    _inspectingDeadlock = false;
    _transformationController.value = Matrix4.identity();
    _gameState?.removeListener(_onGameStateChanged);
    _gameState = GameState(
      level: _level,
      initialLives: _lives,
      onLevelComplete: _onLevelComplete,
      onGameOver: _onGameOver,
      onLifeLost: _onLifeLost,
      onDeadlock: _onDeadlock,
    );
    _gameState!.addListener(_onGameStateChanged);

    _game = ArrowPuzzleGame(
      level: _level,
      gameState: _gameState!,
      onLevelComplete: _onLevelComplete,
      onGameOver: _onGameOver,
      onLifeLost: _onLifeLost,
    );

    _resetTimerForLevel();

    if (_dailyDate != null) {
      final savedState = DailyChallengeService.instance.getDailyState(_dailyDate!);
      if (savedState != null) {
        final clearedArrowIds =
            (savedState['clearedArrowIds'] as List<dynamic>?)?.cast<String>() ?? [];
        final movesUsed = (savedState['movesUsed'] as int?) ?? 0;
        final savedLives = (savedState['lives'] as int?) ?? AppConstants.maxLives;
        final savedTime = savedState['timeRemaining'] as int?;

        _gameState!.restoreSavedProgress(
          clearedArrowIds: clearedArrowIds,
          movesUsed: movesUsed,
          lives: savedLives,
        );
        _lives = savedLives;
        if (savedTime != null && savedTime > 0) {
          _timeRemaining = savedTime;
        }
      }
    }

    _entranceController.forward(from: 0.0);
  }

  void _onGameStateChanged() {
    if (!mounted) return;
    if (_lives != _gameState!.lives) {
      setState(() {
        _lives = _gameState!.lives;
      });
    }

    if (_dailyDate != null && _gameState != null && !_showingComplete && !_showingGameOver) {
      DailyChallengeService.instance.saveDailyState(_dailyDate!, {
        'clearedArrowIds': _gameState!.clearedArrowIds,
        'totalArrows': _level.arrows.length,
        'movesUsed': _gameState!.movesUsed,
        'lives': _gameState!.lives,
        'timeRemaining': _timeRemaining,
      });
    }
  }

  void _onLifeLost() {
    if (!mounted) return;
    setState(() => _lives = _gameState!.lives);
    final progress = context.read<ProgressRepository>();
    progress.deductLife(amount: 1);
    if (progress.vibrationEnabled) {
      HapticFeedback.heavyImpact();
    }
  }

  void _onLevelComplete() {
    if (!mounted || _showingComplete) return;
    _levelTimer?.cancel();
    setState(() => _showingComplete = true);
    AudioManager.instance.playLevelComplete();
    if (context.read<ProgressRepository>().vibrationEnabled) {
      HapticFeedback.lightImpact();
    }

    final progress = context.read<ProgressRepository>();
    final adManager = context.read<AdManager>();
    final stars = ProgressRepository.calculateStars(
        _gameState!.livesLost, _level.totalArrows, _gameState!.movesUsed);
    final score =
        AppConstants.baseScore + (_lives * AppConstants.bonusPerRemainingLife);
    final coinsEarned = AppConstants.coinsForLevel(_level.levelNumber);

    if (_dailyDate != null) {
      DailyChallengeService.instance.markDateCompleted(_dailyDate!);
    } else {
      progress.recordLevelComplete(
        LevelResult(
          levelNumber: _level.levelNumber,
          stars: stars,
          score: score,
          movesUsed: _gameState!.movesUsed,
          livesLost: _gameState!.livesLost,
          completed: true,
          completedAt: DateTime.now(),
        ),
        coinsEarned: coinsEarned,
      );

      final levelType = AppConstants.levelTypeFor(_level.levelNumber);
      adManager.onLevelComplete(_level.levelNumber, levelType.isSpecial);
    }

    progress.resetLivesToFull();
    setState(() {
      _lives = AppConstants.maxLives;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        if (context.read<ProgressRepository>().vibrationEnabled) {
          Future.forEach(List.generate(6, (i) => i * 150), (delay) async {
            await Future.delayed(Duration(milliseconds: delay == 0 ? 0 : 150));
            if (mounted && _showingComplete) {
              HapticFeedback.lightImpact();
            }
          });
        }
        _showLevelCompleteDialog(stars, score, coinsEarned);
      }
    });
  }

  void _onGameOver() {
    if (!mounted || _showingGameOver) return;
    setState(() => _showingGameOver = true);
    if (context.read<ProgressRepository>().vibrationEnabled) {
      HapticFeedback.vibrate();
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showGameOverDialog();
    });
  }

  void _onDeadlock() {
    if (!mounted || _showingDeadlock || _showingGameOver || _showingComplete)
      return;
    _levelTimer?.cancel();
    setState(() {
      _showingDeadlock = true;
      _inspectingDeadlock = false;
    });
    if (context.read<ProgressRepository>().vibrationEnabled) {
      HapticFeedback.vibrate();
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showDeadlockDialog();
    });
  }

  Future<void> _showDeadlockDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeadlockDialog(
        level: _level,
        onRestart: () {
          Navigator.pop(context);
          _handleRestart();
        },
        onMenu: () {
          Navigator.pop(context);
          _handleMenu();
        },
        onInspect: () {
          Navigator.pop(context);
          setState(() {
            _inspectingDeadlock = true;
          });
        },
      ),
    );
  }

  Future<void> _handleRestart() async {
    final totalArrows = _level.arrows.length;
    final activeArrows =
        _gameState?.arrows.where((a) => a.state != ArrowState.sliding).length ??
            totalArrows;
    final clearedArrows = totalArrows - activeArrows;
    final progressVal =
        totalArrows > 0 ? (clearedArrows / totalArrows).clamp(0.0, 1.0) : 0.0;

    if (progressVal >= 0.8) {
      final adManager = context.read<AdManager>();
      await adManager.showInterstitial();
    }

    if (_dailyDate != null) {
      DailyChallengeService.instance.clearDailyState(_dailyDate!);
    }

    if (mounted) {
      final progress = context.read<ProgressRepository>();
      if (!progress.hasLives) {
        await progress.restoreLives();
      }
      _lives = progress.lives;
      _game.resetLevel();
      _gameState?.resetLevel(initialLives: _lives);

      setState(() {
        _showingGameOver = false;
        _showingComplete = false;
        _showingDeadlock = false;
        _inspectingDeadlock = false;
        _game.setEntranceProgress(0.0);
        _resetTimerForLevel();
        _entranceController.forward(from: 0.0);
      });
    }
  }

  Future<void> _showSettingsDialog() async {
    setState(() => _isGamePaused = true);
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => GameSettingsDialog(
        onRestart: () {
          Navigator.pop(context);
          _handleRestart();
        },
      ),
    );
    if (mounted) {
      setState(() => _isGamePaused = false);
    }
  }

  void _handleNextLevel() {
    Navigator.pop(context);
    if (_dailyDate != null) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, '/daily');
      }
    } else {
      Navigator.pushReplacementNamed(
        context,
        '/game',
        arguments: {'level': _level.levelNumber + 1},
      );
    }
  }

  void _handleMenu() {
    Navigator.pop(context);
    if (_dailyDate != null) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, '/daily');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/menu');
    }
  }

  Future<void> _showLevelCompleteDialog(int stars, int score, int coinsEarned) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Stack(
        children: [
          LevelCompleteDialog(
            level: _level,
            stars: stars,
            score: score,
            coinsEarned: coinsEarned,
            isDailyMode: _dailyDate != null,
            onNextLevel: _handleNextLevel,
            onMenu: _handleMenu,
          ),
        ],
      ),
    );
  }

  Future<void> _showGameOverDialog() async {
    const continueTime = 0;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => GameOverDialog(
        level: _level,
        isTimeout: _isTimeoutState,
        continueTime: continueTime,
        onBuyHeart: () async {
          final progress = context.read<ProgressRepository>();
          if (progress.coins >= AppConstants.heartCoinCost) {
            final success = await progress.buyHeart();
            if (success && mounted) {
              Navigator.pop(context);
              setState(() {
                _showingGameOver = false;
                if (_isTimeoutState) {
                  _timeRemaining = continueTime;
                  _isTimeoutState = false;
                  _gameState!.resumeFromTimeout();
                  _startLevelTimer();
                } else {
                  _gameState!.restoreLife();
                  _lives = _gameState!.lives;
                }
              });
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Purchased 1 Heart for ${AppConstants.heartCoinCost} coins!',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: const Color(0xFF27AE60),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else if (mounted) {
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
                  borderRadius: BorderRadius.circular(12),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        onContinue: () {
          // Watch rewarded ad to restore 1 life or add extra time
          final adManager = context.read<AdManager>();
          Navigator.pop(context);
          bool rewarded = false;
          adManager.showRewardedWithLoader(
            context,
            onRewarded: () {
              rewarded = true;
              if (!mounted) return;
              final progress = context.read<ProgressRepository>();
              progress.restoreLives(amount: 1);
              setState(() {
                _showingGameOver = false;
                if (_isTimeoutState) {
                  _timeRemaining = continueTime; // Add dynamic extra time
                  _isTimeoutState = false;
                  _gameState!.resumeFromTimeout();
                  _startLevelTimer();
                } else {
                  _gameState!.restoreLife();
                  _lives = _gameState!.lives;
                }
              });
            },
            onDismissed: () {
              if (!rewarded && mounted) {
                _showingGameOver = false;
                _showGameOverDialog(); // Re-open game over dialog so player can try again or restart
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Ad not completed. Try watching again or restart.',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: const Color(0xFFC0392B),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          );
        },
        onRestart: () {
          Navigator.pop(context);
          _handleRestart();
        },
        onMenu: () {
          Navigator.pop(context);
          Navigator.pushReplacementNamed(context, '/menu');
        },
      ),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _transformationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _levelTimer?.cancel();
    _gameState?.removeListener(_onGameStateChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _isAppBackgrounded = true;
      AudioManager.instance.pauseMusic();
    } else if (state == AppLifecycleState.resumed) {
      _isAppBackgrounded = false;
      AudioManager.instance.resumeMusic();
    }
  }

  void _resetTimerForLevel() {
    _levelTimer?.cancel();
    _isTimeoutState = false;
    _totalTime = 0;
    _timeRemaining = 0;
  }

  void _startLevelTimer() {
    _levelTimer?.cancel();
    _levelTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Pause if game state is not active, completed, gameover, paused or backgrounded
      if (_showingComplete ||
          _showingGameOver ||
          _isLoadingLevel ||
          !_isLevelReady ||
          _isGamePaused ||
          _isAppBackgrounded) {
        return;
      }

      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;
          if (_timeRemaining == 0) {
            timer.cancel();
            _onTimeOut();
          }
        }
      });
    });
  }

  void _onTimeOut() {
    if (!mounted || _showingGameOver) return;
    setState(() {
      _isTimeoutState = true;
    });
    _gameState?.forceGameOver();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ProgressRepository>();

    if (!_isLevelReady || _isLoadingLevel) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: AppColors.bgGradient),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3.5,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Preparing Level ${_loadedLevelNum ?? 1}...',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final levelType = AppConstants.levelTypeFor(_level.levelNumber);

    // Calculate level progress
    final totalArrows = _level.arrows.length;
    final activeArrows =
        _gameState?.arrows.where((a) => a.state != ArrowState.sliding).length ??
            totalArrows;
    final clearedArrows = totalArrows - activeArrows;
    final progressVal =
        totalArrows > 0 ? (clearedArrows / totalArrows).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top Bar & Timer ───────────────────────────────────────────
              AnimatedBuilder(
                animation: _entranceController,
                builder: (context, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GameTopBar(
                        level: _level,
                        levelType: levelType,
                        lives: _lives,
                        progress: progressVal,
                        entranceController: _entranceController,
                        dailyDate: _dailyDate,
                        onBack: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacementNamed(
                                context, _dailyDate != null ? '/daily' : '/menu');
                          }
                        },
                        onSettings: _showSettingsDialog,
                      ),
                      if (_totalTime > 0)
                        Transform.scale(
                          scale: 0.85 +
                              0.15 *
                                  const Interval(0.70, 0.93, curve: Curves.easeOutBack)
                                      .transform(_entranceController.value),
                          child: Opacity(
                            opacity: const Interval(0.70, 0.93, curve: Curves.easeOutBack)
                                .transform(_entranceController.value)
                                .clamp(0.0, 1.0),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GameTimerDisplay(
                                timeRemaining: _timeRemaining,
                                totalTime: _totalTime,
                                levelType: levelType,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),

              // ── Game Canvas ──────────────────────────────────────────────
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boardW = constraints.maxWidth;
                    final boardH = constraints.maxHeight;
                    final fadeH = boardH * 0.10;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Canvas — fills the Expanded bounds, clipped hard
                        Positioned.fill(
                          child: ClipRect(
                            child: InteractiveViewer(
                              transformationController:
                                  _transformationController,
                              minScale: 0.1,
                              maxScale: 5.0,
                              boundaryMargin: const EdgeInsets.all(1200),
                              clipBehavior: Clip.none,
                              child: Center(
                                child: SizedBox(
                                  width: boardW,
                                  height: boardH,
                                  child: RepaintBoundary(
                                    child: GameWidget(
                                      key: ValueKey(_game),
                                      game: _game,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Top fade — fixed overlay, non-interactive
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Container(
                              height: fadeH,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.background,
                                    AppColors.background.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Bottom fade — fixed overlay, non-interactive
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Container(
                              height: fadeH,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    AppColors.background,
                                    AppColors.background.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // ── Floating Action Buttons (SCALE, RESET, HINT) ─────
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: AnimatedBuilder(
                            animation: _entranceController,
                            builder: (context, _) {
                              return _buildInGameControls(
                                  context.watch<ProgressRepository>());
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // ── Banner Ad (centered at absolute bottom) ──
              Container(
                alignment: Alignment.center,
                width: double.infinity,
                height: 50,
                color: AppColors.background,
                child: const UnifiedBannerAd(
                  admobUnitId: AppConstants.admobBannerUnitId,
                  unityPlacementId: AppConstants.unityBannerAdId,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _inspectingDeadlock
          ? FloatingActionButton.extended(
              onPressed: () {
                AudioManager.instance.playClick();
                setState(() {
                  _inspectingDeadlock = false;
                });
                _showDeadlockDialog();
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(LucideIcons.menu, color: Colors.white),
              label: Text(
                'Deadlock Options',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildInGameControls(ProgressRepository progress) {
    if (_gameState == null) return const SizedBox.shrink();

    final scaleCount = progress.scaleUses;
    final hintCount = progress.hints;
    final isDark = AppColors.isDark;

    final double rawVal = _entranceController.value;
    final double hudProgress = const Interval(0.70, 0.93, curve: Curves.easeOutBack)
        .transform(rawVal);
    final double opacity = hudProgress.clamp(0.0, 1.0);
    final double scale = 0.85 + 0.15 * hudProgress;

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // ── SCALE Circular Theme Button with Badge ─────────────────────────
              GestureDetector(
                onTap: () {
                  AudioManager.instance.playClick();
                  if (scaleCount > 0) {
                    progress.useScale();
                    if (progress.vibrationEnabled) {
                      HapticFeedback.selectionClick();
                    }
                    setState(() {
                      _gameState!.showScale();
                    });
                  } else {
                    _showWatchAdForScaleDialog();
                  }
                },
            child: Tooltip(
              message: scaleCount > 0 ? 'Scale Guidelines' : 'Watch Ad for Scale',
              child: SizedBox(
                width: 62,
                height: 62,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Main circular button
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF1C2541) : Colors.white,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2E3B59)
                              : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.35)
                                : const Color(0xFF1E293B).withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/images/scale.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(
                            LucideIcons.ruler,
                            color: const Color(0xFF38BDF8),
                            size: 26,
                          ),
                        ),
                      ),
                    ),

                    // Top-Right Badge: Number (if > 0) or "Ad" (if == 0)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: scaleCount > 0 ? 7 : 6,
                          vertical: scaleCount > 0 ? 3 : 3,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        decoration: BoxDecoration(
                          shape: scaleCount > 0 ? BoxShape.circle : BoxShape.rectangle,
                          borderRadius: scaleCount > 0
                              ? null
                              : BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white, width: 2.0),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7)
                                  .withValues(alpha: 0.45),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            scaleCount > 0 ? '$scaleCount' : 'Ad',
                            style: GoogleFonts.nunito(
                              fontSize: scaleCount > 0 ? 12 : 10.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── RESET Circular Theme Button ────────────────────────────────────
          GestureDetector(
            onTap: () {
              AudioManager.instance.playClick();
              _handleRestart();
            },
            child: Tooltip(
              message: 'Reset Level',
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1C2541) : Colors.white,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2E3B59)
                        : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.35)
                          : const Color(0xFF1E293B).withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/resete.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      LucideIcons.rotateCcw,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── HINT Circular Theme Button with Badge ─────────────────────────
          GestureDetector(
            onTap: () {
              AudioManager.instance.playClick();
              if (hintCount > 0) {
                final hintId = _gameState!.triggerHint();
                if (hintId != null) {
                  progress.useHint();
                  if (progress.vibrationEnabled) {
                    HapticFeedback.mediumImpact();
                  }
                } else {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'No unblocked move available right now!',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: const Color(0xFFC0392B),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } else {
                _showWatchAdForHintsDialog();
              }
            },
            child: Tooltip(
              message: hintCount > 0 ? 'Use Hint' : 'Watch Ad for Hints',
              child: SizedBox(
                width: 62,
                height: 62,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Main circular button
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF1C2541) : Colors.white,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2E3B59)
                              : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.35)
                                : const Color(0xFF1E293B).withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/images/hint.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            LucideIcons.lightbulb,
                            color: Color(0xFFF39C12),
                            size: 26,
                          ),
                        ),
                      ),
                    ),

                    // Top-Right Badge: Number (if > 0) or "Ad" (if == 0)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: hintCount > 0 ? 7 : 6,
                          vertical: hintCount > 0 ? 3 : 3,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        decoration: BoxDecoration(
                          shape: hintCount > 0 ? BoxShape.circle : BoxShape.rectangle,
                          borderRadius: hintCount > 0
                              ? null
                              : BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4A90E2), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white, width: 2.0),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB)
                                  .withValues(alpha: 0.45),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            hintCount > 0 ? '$hintCount' : 'Ad',
                            style: GoogleFonts.nunito(
                              fontSize: hintCount > 0 ? 12 : 10.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
  }

  void _showWatchAdForHintsDialog() {
    final adManager = context.read<AdManager>();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.surfaceLight, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF39C12).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.lightbulb,
                    color: Color(0xFFF39C12),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Out of Hints!',
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Watch a short video ad to unlock 2 Free Hints and reveal the next move!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: () {
                    final progress = context.read<ProgressRepository>();
                    Navigator.pop(context);
                    bool rewarded = false;
                    adManager.showRewardedWithLoader(
                      context,
                      onRewarded: () {
                        rewarded = true;
                        progress.addHints(2);
                        if (mounted) {
                          setState(() {
                            _gameState?.triggerHint();
                          });
                        }
                      },
                      onDismissed: () {
                        if (!rewarded && mounted) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Ad not completed. Hints not added.',
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: const Color(0xFFC0392B),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF27AE60).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.playCircle,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'WATCH AD (+2 HINTS)',
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWatchAdForScaleDialog() {
    final adManager = context.read<AdManager>();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.surfaceLight, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.ruler,
                    color: Color(0xFF38BDF8),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Out of Scale Points!',
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Watch a short video ad to unlock 2 Free Scale Uses and reveal exit paths!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: () {
                    final progress = context.read<ProgressRepository>();
                    Navigator.pop(context);
                    bool rewarded = false;
                    adManager.showRewardedWithLoader(
                      context,
                      onRewarded: () {
                        rewarded = true;
                        progress.addScaleUses(2);
                        if (mounted) {
                          setState(() {
                            _gameState?.showScale();
                          });
                        }
                      },
                      onDismissed: () {
                        if (!rewarded && mounted) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Ad not completed. Scale points not added.',
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: const Color(0xFFC0392B),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.playCircle,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'WATCH AD (+2 SCALE USES)',
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _isLevelReady => _gameState != null;

  void _showTutorialDialogIfNeeded(int levelNum) {
    // Tutorial pop-up dialog boxes and grid warning alerts removed! Gameplay starts instantly.
    // If the arrows are very small, show a snackbar warning to zoom in/out (one-time only)
    final progressRepo = context.read<ProgressRepository>();
    if (_level.gridSize >= 25 && !progressRepo.hasSeenZoomHint) {
      progressRepo.setHasSeenZoomHint(true);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pinch to zoom in or out to see small arrows easily!',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      });
    }
  }
}






