import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/arrow.dart';
import '../data/models/level.dart';
import '../core/constants.dart';
import '../core/audio_manager.dart';

/// Manages the current game state: lives, moves, arrows remaining.
class GameState extends ChangeNotifier {
  // ── Level ─────────────────────────────────────────────────────────────────────
  late LevelModel _currentLevel;
  late List<ArrowModel> _arrows;
  int _lives = AppConstants.maxLives;
  int _movesUsed = 0;
  int _livesLost = 0;
  bool _isComplete = false;
  bool _isGameOver = false;
  bool _isDeadlocked = false;

  // Scale (Projection Lines) feature toggle
  bool isScaleActive = false;

  // Hint feature state
  String? hintArrowId;
  Timer? _hintTimer;

  // Live orphan dot map (dots are removed when consumed by an exiting arrow)
  late Map<String, OrphanDotType> _orphanDots;

  // Track which colorGroups have had their key cleared
  final Set<int> _clearedColorGroups = {};

  // Track trapped arrows (remain red until tapped again and successfully exit)
  final Set<String> _trappedArrowIds = {};

  // Track consumed orphan dots per arrow ID during exit animation
  final Map<String, List<OrphanDot>> _consumedDotsByArrow = {};

  // ── Callbacks ─────────────────────────────────────────────────────────────────
  final void Function() onLevelComplete;
  final void Function() onGameOver;
  final void Function() onLifeLost;
  final void Function() onDeadlock;

  // Track occupied grid cells for O(1) exit check lookups
  Set<String> _occupiedCells = {};

  GameState({
    required LevelModel level,
    int initialLives = AppConstants.maxLives,
    required this.onLevelComplete,
    required this.onGameOver,
    required this.onLifeLost,
    required this.onDeadlock,
  }) {
    _currentLevel = level;
    _lives = initialLives;
    _arrows = level.arrows.map((a) => a.copyWith()).toList();
    _orphanDots = {for (final od in level.orphanDots) od.key: od.type};
    _occupiedCells = _buildOccupiedCells();
  }

  Set<String> _buildOccupiedCells() {
    final cells = <String>{};
    for (final arrow in _arrows) {
      if (arrow.state == ArrowState.sliding) continue;
      for (final pt in arrow.path) {
        cells.add('${pt[0]},${pt[1]}');
      }
    }
    return cells;
  }

  /// Restores in-progress state from saved data: cleared arrow IDs, moves used, lives remaining.
  void restoreSavedProgress({
    required List<String> clearedArrowIds,
    required int movesUsed,
    required int lives,
  }) {
    if (clearedArrowIds.isNotEmpty) {
      final setCleared = clearedArrowIds.toSet();
      _arrows.removeWhere((a) => setCleared.contains(a.id));
    }
    _movesUsed = movesUsed;
    _lives = lives;
    _occupiedCells = _buildOccupiedCells();
    notifyListeners();
  }

  /// List of cleared arrow IDs (total level arrows minus current remaining arrows)
  List<String> get clearedArrowIds {
    final remainingIds = _arrows.map((a) => a.id).toSet();
    return _currentLevel.arrows
        .where((a) => !remainingIds.contains(a.id))
        .map((a) => a.id)
        .toList();
  }

  void toggleScale() {
    isScaleActive = !isScaleActive;
    notifyListeners();
  }

  void showScale() {
    isScaleActive = true;
    notifyListeners();
  }

  void hideScale() {
    if (isScaleActive) {
      isScaleActive = false;
      notifyListeners();
    }
  }

  /// Finds the first unblocked arrow that can escape cleanly right now
  /// and highlights it as [hintArrowId] for 4 seconds.
  String? triggerHint() {
    _hintTimer?.cancel();
    if (_arrows.isEmpty || _isComplete || _isGameOver) return null;

    for (final arrow in _arrows) {
      if (!isArrowBlocked(arrow.id)) {
        hintArrowId = arrow.id;
        notifyListeners();

        _hintTimer = Timer(const Duration(seconds: 4), () {
          if (hintArrowId == arrow.id) {
            hintArrowId = null;
            notifyListeners();
          }
        });
        return arrow.id;
      }
    }
    return null;
  }

  void clearHint() {
    if (hintArrowId != null) {
      _hintTimer?.cancel();
      hintArrowId = null;
      notifyListeners();
    }
  }

  // ── Getters ───────────────────────────────────────────────────────────────────
  List<ArrowModel> get arrows => _arrows;
  int get lives => _lives;
  int get movesUsed => _movesUsed;
  int get livesLost => _livesLost;
  bool get isComplete => _isComplete;
  bool get isGameOver => _isGameOver;
  bool get isDeadlocked => _isDeadlocked;
  int get arrowsRemaining => _arrows.length;
  LevelModel get level => _currentLevel;
  /// Live orphan dots remaining (consumed dots are absent from this map).
  Map<String, OrphanDotType> get orphanDots => _orphanDots;

  /// Returns true if the arrow has been tapped while trapped and is currently in trapped state.
  bool isArrowTrapped(String arrowId) => _trappedArrowIds.contains(arrowId);

  /// Called by the ArrowComponent when its exit animation completes.
  void handleArrowExitCompleted(String arrowId) {
    _arrows.removeWhere((a) => a.id == arrowId);
    _consumedDotsByArrow.remove(arrowId);
    _trappedArrowIds.remove(arrowId);

    if (_arrows.isEmpty) {
      _isComplete = true;
      onLevelComplete();
    } else {
      if (checkDeadlock()) {
        _isDeadlocked = true;
        onDeadlock();
      }
    }
    notifyListeners();
  }

  /// Returns true if all remaining arrows are blocked (deadlocked).
  bool checkDeadlock() {
    if (_arrows.isEmpty) return false;

    // Never trigger deadlock while any arrow is actively sliding/exiting
    if (_arrows.any((a) => a.state == ArrowState.sliding)) {
      return false;
    }

    for (final arrow in _arrows) {
      final exit = _computeExitInfo(arrow);
      if (!exit.blocked) {
        return false; // Found a standard arrow that can exit
      }
    }
    return true; // All remaining arrows are blocked!
  }

  /// Returns true if the given arrow is currently blocked.
  bool isArrowBlocked(String arrowId) {
    final index = _arrows.indexWhere((a) => a.id == arrowId);
    if (index == -1) return true;
    final arrow = _arrows[index];
    return _computeExitInfo(arrow).blocked;
  }

  List<OrphanDot> getConsumedDotsForArrow(String arrowId) {
    return _consumedDotsByArrow[arrowId] ?? [];
  }

  void _recordConsumedDots(String arrowId, List<String> consumedKeys) {
    final dots = <OrphanDot>[];
    for (final key in consumedKeys) {
      final match = _currentLevel.orphanDots.firstWhere(
        (od) => od.key == key,
        orElse: () {
          final parts = key.split(',');
          return OrphanDot(
            row: int.parse(parts[0]),
            col: int.parse(parts[1]),
            type: OrphanDotType.neutral,
          );
        },
      );
      dots.add(match);
    }
    _consumedDotsByArrow[arrowId] = dots;
  }

  // ── Tap Handler ───────────────────────────────────────────────────────────────

  /// Returns the outcome of tapping an arrow (snake).
  TapResult tapArrow(String arrowId) {
    if (_isComplete || _isGameOver) return TapResult.ignored;

    clearHint();
    hideScale();

    final index = _arrows.indexWhere((a) => a.id == arrowId);
    if (index == -1) return TapResult.ignored;

    final arrow = _arrows[index];
    if (arrow.state != ArrowState.idle) {
      return TapResult.ignored;
    }

    _movesUsed++;

    // ── Move check ─────────────────────────────────────────
    final exitInfo = _computeExitInfo(arrow);
    if (exitInfo.blocked) {
      return _handleBlocked(index, arrow, arrowId);
    }

    // ── Clear: arrow exits ──────────────────────────────────────────
    _trappedArrowIds.remove(arrowId);
    _arrows[index] = arrow.copyWith(state: ArrowState.sliding);
    for (final pt in arrow.path) {
      _occupiedCells.remove('${pt[0]},${pt[1]}');
    }
    _recordConsumedDots(arrowId, exitInfo.consumed);
    notifyListeners();

    // Play exit sound
    AudioManager.instance.playArrowExit();

    return TapResult.exited;
  }

  TapResult _handleBlocked(int index, ArrowModel arrow, String arrowId) {
    _trappedArrowIds.add(arrowId);
    _arrows[index] = arrow.copyWith(state: ArrowState.blocked);
    _lives--;
    _livesLost++;
    onLifeLost();

    // Reset arrow state after animation
    Future.delayed(AppConstants.arrowShakeDuration, () {
      final idx = _arrows.indexWhere((a) => a.id == arrowId);
      if (idx != -1) {
        _arrows[idx] = _arrows[idx].copyWith(state: ArrowState.idle);
        notifyListeners();
      }
    });

    if (_lives <= 0) {
      _isGameOver = true;
      onGameOver();
      notifyListeners();
      return TapResult.blocked;
    }

    notifyListeners();
    return TapResult.blocked;
  }

  /// Checks whether the arrow's exit path is clear along its direction.
  _ExitInfo _computeExitInfo(ArrowModel arrow) {
    final currentDir = arrow.direction;
    final head = arrow.path[0];
    final gridSize = _currentLevel.gridSize;
    final d = currentDir.delta;
    int nr = head[0] + d[0];
    int nc = head[1] + d[1];
    final consumed = <String>[];

    final ownCells = <String>{};
    for (final pt in arrow.path) {
      ownCells.add('${pt[0]},${pt[1]}');
    }

    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      final key = '$nr,$nc';
      if (!ownCells.contains(key) && _occupiedCells.contains(key)) {
        return const _ExitInfo(true, []);
      }
      nr += d[0];
      nc += d[1];
    }
    return _ExitInfo(false, consumed);
  }

  // ── Reset ─────────────────────────────────────────────────────────────────────

  void resetLevel({int? initialLives}) {
    _arrows = _currentLevel.arrows.map((a) => a.copyWith(state: ArrowState.idle)).toList();
    _orphanDots = {for (final od in _currentLevel.orphanDots) od.key: od.type};
    _consumedDotsByArrow.clear();
    _trappedArrowIds.clear();
    _lives = initialLives ?? AppConstants.maxLives;
    _movesUsed = 0;
    _livesLost = 0;
    _isComplete = false;
    _isGameOver = false;
    _isDeadlocked = false;
    _clearedColorGroups.clear();
    _occupiedCells = _buildOccupiedCells();
    notifyListeners();
  }

  void restoreLife() {
    if (_lives < AppConstants.maxLives) {
      _lives++;
      if (_isGameOver && _lives > 0) {
        _isGameOver = false;
      }
      notifyListeners();
    }
  }

  void forceGameOver() {
    _isGameOver = true;
    onGameOver();
    notifyListeners();
  }

  void resumeFromTimeout() {
    _isGameOver = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _hintTimer = null;
    super.dispose();
  }
}

enum TapResult { exited, blocked, locked, ignored }

/// Exit path analysis result for one arrow.
class _ExitInfo {
  final bool blocked;
  final List<String> consumed; // orphan dot keys consumed along this path
  const _ExitInfo(this.blocked, [this.consumed = const []]);
}
