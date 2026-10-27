import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../data/models/level.dart';
import 'components/grid_component.dart';
import 'game_state.dart';

class ArrowPuzzleGame extends FlameGame {
  // ── State ─────────────────────────────────────────────────────────────────────
  final LevelModel level;
  final GameState gameState;
  GridComponent? gridComponent;

  // ── Callbacks to Flutter ──────────────────────────────────────────────────────
  final void Function() onLevelComplete;
  final void Function() onGameOver;
  final void Function() onLifeLost;

  ArrowPuzzleGame({
    required this.level,
    required this.gameState,
    required this.onLevelComplete,
    required this.onGameOver,
    required this.onLifeLost,
  });

  @override
  Color backgroundColor() => Colors.transparent;

  double _pendingEntranceProgress = 1.0;

  void setEntranceProgress(double progress) {
    _pendingEntranceProgress = progress;
    gridComponent?.setEntranceProgress(progress);
  }

  @override
  Future<void> onLoad() async {
    final (gridSize, gridX, gridY) = _calcLayout(size);

    gridComponent = GridComponent(
      gameState: gameState,
      gridPixelSize: gridSize,
      position: Vector2(gridX, gridY),
      entranceProgress: _pendingEntranceProgress,
    );

    add(gridComponent!);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    final (gridSize, gridX, gridY) = _calcLayout(size);

    if (gridComponent != null) {
      gridComponent!.position = Vector2(gridX, gridY);
      gridComponent!.resize(gridSize);
    }
  }

  (double gridSize, double gridX, double gridY) _calcLayout(Vector2 screenSize) {
    if (screenSize.x <= 0 || screenSize.y <= 0) {
      return (100.0, 0.0, 0.0);
    }
    final levelType = AppConstants.levelTypeFor(level.levelNumber);
    // Clamp scale to 1.0: values > 1.0 make gridPixelWidth > screenSize,
    // giving a negative gridX so edge cells fall outside the Flutter SizedBox
    // and their touch events get clipped.
    final scale = AppConstants.canvasScaleForType(levelType).clamp(0.1, 1.0);

    double activeCols = level.gridSize.toDouble();
    double activeRows = level.gridSize.toDouble();
    double minRDouble = 0.0;
    double maxRDouble = (level.gridSize - 1).toDouble();
    double minCDouble = 0.0;
    double maxCDouble = (level.gridSize - 1).toDouble();

    if (level.mask.isNotEmpty) {
      int minR = 999, maxR = -1, minC = 999, maxC = -1;
      for (final cell in level.mask) {
        final comma = cell.indexOf(',');
        if (comma != -1) {
          final r = int.tryParse(cell.substring(0, comma));
          final c = int.tryParse(cell.substring(comma + 1));
          if (r != null && c != null) {
            if (r < minR) minR = r;
            if (r > maxR) maxR = r;
            if (c < minC) minC = c;
            if (c > maxC) maxC = c;
          }
        }
      }
      if (minR <= maxR && minC <= maxC) {
        activeRows = (maxR - minR + 1).toDouble();
        activeCols = (maxC - minC + 1).toDouble();
        minRDouble = minR.toDouble();
        maxRDouble = maxR.toDouble();
        minCDouble = minC.toDouble();
        maxCDouble = maxC.toDouble();
      }
    }

    final maxW = screenSize.x * scale;
    final maxH = screenSize.y * scale;

    final cellW = maxW / activeCols;
    final cellH = maxH / activeRows;
    final cellSize = cellW < cellH ? cellW : cellH;

    final gridPixelWidth  = level.gridSize * cellSize;

    // Center the active mask's bounding box directly in the middle of the screen
    final centerMaskC = (minCDouble + maxCDouble + 1.0) / 2.0;
    final centerMaskR = (minRDouble + maxRDouble + 1.0) / 2.0;

    final gridX = (screenSize.x / 2.0) - (centerMaskC * cellSize);
    final gridY = (screenSize.y / 2.0) - (centerMaskR * cellSize);

    return (gridPixelWidth, gridX, gridY);
  }

  /// Reset board to initial state (restart level)
  void resetLevel() {
    gameState.resetLevel();
    gridComponent?.rebuild();
  }
}
