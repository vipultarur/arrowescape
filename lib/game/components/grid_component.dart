import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/app_colors.dart';
import '../../data/models/level.dart';
import '../../data/models/arrow.dart';
import '../game_state.dart';
import 'arrow_component.dart';

/// Renders the puzzle grid, mask boundary dots, and all arrow components.
///
/// IMPORTANT: the mask used for RENDERING must match the mask used when the
/// level was generated.  We regenerate it from the stored [MaskShape] so we
/// never drift between generator and renderer.
class GridComponent extends PositionComponent {
  final GameState gameState;
  double gridPixelSize;

  final Map<String, ArrowComponent> _arrowComponents = {};
  late Set<String> _mask;
  late LevelType _levelType;

  ui.Picture? _cachedDotGridPicture;

  void _invalidateDotGrid() {
    _cachedDotGridPicture?.dispose();
    _cachedDotGridPicture = null;
  }

  @override
  void onRemove() {
    _invalidateDotGrid();
    super.onRemove();
  }

  double entranceProgress;

  GridComponent({
    required this.gameState,
    required this.gridPixelSize,
    required Vector2 position,
    this.entranceProgress = 1.0,
  }) : super(position: position);

  void setEntranceProgress(double progress) {
    entranceProgress = progress;
    for (final child in children) {
      if (child is ArrowComponent) {
        child.entranceProgress = progress;
      }
    }
  }

  double get cellSize => gridPixelSize / gameState.level.gridSize;

  @override
  Future<void> onLoad() async {
    size = Vector2.all(gridPixelSize);
    _levelType = AppConstants.levelTypeFor(gameState.level.levelNumber);
    _refreshMask();
    _buildArrows();
  }

  // ── Mask ──────────────────────────────────────────────────────────────────

  Set<int>? _cachedMaskPacked;

  /// Rebuilds the mask from the stored MaskShape on the level model.
  /// Uses a deterministic seed derived from level + shape so the shape
  /// is always the same instance for this level (blob needs a seed).
  void _refreshMask() {
    _mask = gameState.level.mask;
    _cachedMaskPacked = <int>{};
    for (final cellKey in _mask) {
      final comma = cellKey.indexOf(',');
      if (comma != -1) {
        final r = int.tryParse(cellKey.substring(0, comma));
        final c = int.tryParse(cellKey.substring(comma + 1));
        if (r != null && c != null) {
          _cachedMaskPacked!.add(r * 1000 + c);
        }
      }
    }
  }

  // ── Arrow components ──────────────────────────────────────────────────────

  void _buildArrows() {
    removeAll(children.whereType<ArrowComponent>());
    _arrowComponents.clear();

    for (final arrow in gameState.arrows) {
      final comp = ArrowComponent(
        arrowModel: arrow,
        cellSize: cellSize,
        gameState: gameState,
        levelType: _levelType,
        entranceProgress: entranceProgress,
      )..position = Vector2(0, 0);
      _arrowComponents[arrow.id] = comp;
      add(comp);
    }
  }

  void rebuild() {
    _refreshMask();
    _buildArrows();
    _invalidateDotGrid();
  }

  void resize(double newGridPixelSize) {
    gridPixelSize = newGridPixelSize;
    size = Vector2.all(gridPixelSize);
    for (final child in children) {
      if (child is ArrowComponent) child.updateCellSize(cellSize);
    }
    _invalidateDotGrid();
  }

  void _recacheDotGrid() {
    _cachedDotGridPicture?.dispose();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final gridSize = gameState.level.gridSize;
    final cs = cellSize;
    final baseDot = (cs * 0.045).clamp(0.6, 1.6);
    final inR = baseDot;

    final inPaint = Paint()
      ..color = AppColors.gridDot
      ..style = PaintingStyle.fill;

    final maskPacked = _cachedMaskPacked ?? <int>{};

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (!maskPacked.contains(r * 1000 + c)) continue;

        canvas.drawCircle(
          Offset((c + 0.5) * cs, (r + 0.5) * cs),
          inR,
          inPaint,
        );
      }
    }

    _cachedDotGridPicture = recorder.endRecording();
  }

  List<_ParsedOrphanDot>? _cachedParsedDots;
  int _lastOrphanDotsLength = -1;

  List<_ParsedOrphanDot> _getParsedOrphanDots() {
    final dots = gameState.orphanDots;
    if (_cachedParsedDots == null || _lastOrphanDotsLength != dots.length) {
      _lastOrphanDotsLength = dots.length;
      _cachedParsedDots = dots.entries
          .where((e) => e.value != OrphanDotType.neutral)
          .map((e) {
            final comma = e.key.indexOf(',');
            if (comma == -1) return null;
            final r = int.tryParse(e.key.substring(0, comma));
            final c = int.tryParse(e.key.substring(comma + 1));
            if (r == null || c == null) return null;
            return _ParsedOrphanDot(r, c, e.value);
          })
          .whereType<_ParsedOrphanDot>()
          .toList();
    }
    return _cachedParsedDots!;
  }

  @override
  void renderTree(Canvas canvas) {
    if (entranceProgress < 1.0) {
      final t = entranceProgress.clamp(0.0, 1.0);
      final scale = Curves.easeOutBack.transform(t);
      final center = gridPixelSize / 2;

      canvas.save();
      canvas.translate(center, center);
      canvas.scale(scale);
      canvas.translate(-center, -center);

      super.renderTree(canvas);

      canvas.restore();
    } else {
      super.renderTree(canvas);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  RENDER
  // ═══════════════════════════════════════════════════════════════════════════

  AppThemeOption _themeOptionCached = AppColors.currentOption;

  @override
  void render(Canvas canvas) {
    final cs = cellSize;

    if (_cachedDotGridPicture == null || _themeOptionCached != AppColors.currentOption) {
      _themeOptionCached = AppColors.currentOption;
      _recacheDotGrid();
    }
    canvas.drawPicture(_cachedDotGridPicture!);

    // ── Scale / Projection Guidelines Overlay ──────
    if (gameState.isScaleActive) {
      _drawScaleGuidelines(canvas, cs);
    }

    // ── Orphan deflector dots (drawn on top of background dots) ────────────
    final parsedDots = _getParsedOrphanDots();
    for (int i = 0; i < parsedDots.length; i++) {
      final dot = parsedDots[i];
      _drawOrphanDot(canvas, Offset((dot.c + 0.5) * cs, (dot.r + 0.5) * cs),
          dot.type, cs);
    }

    super.render(canvas);
  }

  static final Paint _guidePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  void _drawScaleGuidelines(Canvas canvas, double cs) {
    final upRays = <int, int>{};    // col -> maxRow
    final downRays = <int, int>{};  // col -> minRow
    final leftRays = <int, int>{};  // row -> maxCol
    final rightRays = <int, int>{}; // row -> minCol

    final arrows = gameState.arrows;
    for (int i = 0; i < arrows.length; i++) {
      final arrow = arrows[i];
      if (arrow.state == ArrowState.exited) continue;

      final r = arrow.row;
      final c = arrow.col;

      switch (arrow.direction) {
        case ArrowDirection.up:
          upRays[c] = upRays.containsKey(c) ? max(upRays[c]!, r) : r;
          break;
        case ArrowDirection.down:
          downRays[c] = downRays.containsKey(c) ? min(downRays[c]!, r) : r;
          break;
        case ArrowDirection.left:
          leftRays[r] = leftRays.containsKey(r) ? max(leftRays[r]!, c) : c;
          break;
        case ArrowDirection.right:
          rightRays[r] = rightRays.containsKey(r) ? min(rightRays[r]!, c) : c;
          break;
      }
    }

    final guideColor = AppColors.isDark
        ? const Color(0xFF93C5FD).withValues(alpha: 0.35)
        : const Color(0xFF60A5FA).withValues(alpha: 0.35);

    _guidePaint
      ..color = guideColor
      ..strokeWidth = (cs * 0.15).clamp(2.5, 4.0);

    const margin = 1000.0;

    // Up rays: from head extending UP to top edge
    upRays.forEach((c, maxRow) {
      canvas.drawLine(
        Offset((c + 0.5) * cs, (maxRow + 0.5) * cs),
        Offset((c + 0.5) * cs, -margin),
        _guidePaint,
      );
    });

    // Down rays: from head extending DOWN to bottom edge
    downRays.forEach((c, minRow) {
      canvas.drawLine(
        Offset((c + 0.5) * cs, (minRow + 0.5) * cs),
        Offset((c + 0.5) * cs, gridPixelSize + margin),
        _guidePaint,
      );
    });

    // Left rays: from head extending LEFT to left edge
    leftRays.forEach((r, maxCol) {
      canvas.drawLine(
        Offset((maxCol + 0.5) * cs, (r + 0.5) * cs),
        Offset(-margin, (r + 0.5) * cs),
        _guidePaint,
      );
    });

    // Right rays: from head extending RIGHT to right edge
    rightRays.forEach((r, minCol) {
      canvas.drawLine(
        Offset((minCol + 0.5) * cs, (r + 0.5) * cs),
        Offset(gridPixelSize + margin, (r + 0.5) * cs),
        _guidePaint,
      );
    });
  }

  static final Paint _platePaint = Paint()
    ..color = const Color(0xFFFFAA00)
    ..style = PaintingStyle.fill;

  static final Paint _plateStrokePaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.18)
    ..style = PaintingStyle.stroke;

  static final Paint _orphanLinePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static final Paint _orphanArrowheadPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  static final Paint _neutralDotPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.85)
    ..style = PaintingStyle.fill;

  static void _drawOrphanDot(
      Canvas canvas, Offset center, OrphanDotType type, double cs) {
    if (type == OrphanDotType.neutral) return; // Neutral empty dots can be left empty

    // Solid dot body (plate) - enlarged to be highly visible
    canvas.drawCircle(
      center,
      cs * 0.36,
      _platePaint,
    );

    // Darker outline for contrast
    _plateStrokePaint.strokeWidth = cs * 0.045;
    canvas.drawCircle(
      center,
      cs * 0.36,
      _plateStrokePaint,
    );

    // Drawing the arrow in the middle of the gold plate
    if (type != OrphanDotType.neutral) {
      final ArrowDirection dir;
      switch (type) {
        case OrphanDotType.up:
          dir = ArrowDirection.up;
          break;
        case OrphanDotType.down:
          dir = ArrowDirection.down;
          break;
        case OrphanDotType.left:
          dir = ArrowDirection.left;
          break;
        case OrphanDotType.right:
          dir = ArrowDirection.right;
          break;
        default:
          return;
      }

      final double angle = dir.rotationRadians;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      _orphanLinePaint.strokeWidth = cs * 0.075;

      // Draw the arrow shaft in the middle
      canvas.drawLine(Offset(-cs * 0.22, 0), Offset(cs * 0.06, 0), _orphanLinePaint);

      // Draw a large centered arrowhead pointing right
      final arrowheadPath = Path()
        ..moveTo(cs * 0.28, 0)
        ..lineTo(cs * 0.04, -cs * 0.18)
        ..lineTo(cs * 0.10, 0)
        ..lineTo(cs * 0.04, cs * 0.18)
        ..close();

      canvas.drawPath(
        arrowheadPath,
        _orphanArrowheadPaint,
      );

      canvas.restore();
    } else {
      canvas.drawCircle(
        center,
        cs * 0.075,
        _neutralDotPaint,
      );
    }
  }



  // ── Update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    if (_arrowComponents.length != gameState.arrows.length) {
      final current = gameState.arrows.map((a) => a.id).toSet();
      final gone =
          _arrowComponents.keys.where((id) => !current.contains(id)).toList();
      for (final id in gone) {
        _arrowComponents[id]?.removeFromParent();
        _arrowComponents.remove(id);
      }
    }
  }
}

class _ParsedOrphanDot {
  final int r;
  final int c;
  final OrphanDotType type;
  _ParsedOrphanDot(this.r, this.c, this.type);
}

