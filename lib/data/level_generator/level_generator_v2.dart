import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import '../models/arrow.dart';
import '../models/level.dart';
import '../../core/constants.dart';
import 'solver.dart';
import 'mask_generator_v2.dart';
import 'level_schedule.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  Arrow Puzzle Level Generator — V2
// ═══════════════════════════════════════════════════════════════════════════════
//
//  KEY IMPROVEMENTS OVER V1:
//  ─────────────────────────────────────────────────────────────────────────────
//  • STRICT MECHANIC GATE: Zero color pairs and zero direction dots for levels
//    4–15 across ALL level types (including Boss at level 7). Teaches pure arrow
//    mechanics first.
//
//  • IMPROVED TANGLE FACTOR: Starts at 0.20 from level 4 (not 0.0). Early
//    levels already look like real puzzles. Ramps to 1.0 at level 300+.
//    Boss gets +0.15 boost, God gets +0.25 boost.
//
//  • 4-TIER LENGTH DISTRIBUTION: Adds an explicit Short tier (10% weight,
//    length=2) alongside VeryLong(35%), Long(30%), Medium(25%). 2-cell arrows
//    are actually the most annoying blockers — they fill corridors without
//    taking much visual space.
//
//  • SMARTER PAIR COUNTS: More color pairs appear earlier after the gate lifts
//    at level 16. Boss always ≥ 1 pair from first Boss after gate. God always
//    ≥ 2 pairs.
//
//  • FASTER DOT RAMP: Direction-changing dots appear sooner and more densely,
//    making mid-levels meaningfully harder than early levels.
//
//  • REDUCED PHASE-2 DOMINANCE: Phase 2 (2-cell fill sweep) is capped at a
//    fill-rate that scales with level number. Early levels don't become 80%
//    trivially-fireable 2-cell arrows.
//
//  • HARDCODED 1000-LEVEL SCHEDULE: Shape and level type for every level is
//    determined by the master schedule in level_schedule.dart, not by modular
//    arithmetic cycling through shape pools.
//
//  • EXPANDED SHAPE LIBRARY: Uses MaskGeneratorV2 with 25+ Boss shapes and
//    24+ God shapes.
//
//  • SELF-AVOIDING PATH ASSERTIONS: Debug builds verify no cell repeats and no
//    180° U-turns in any placed arrow body.
//
//  PRESERVED FROM V1:
//  ─────────────────────────────────────────────────────────────────────────────
//  • Grid sizes:     10 → 40 as implemented in AppConstants.
//  • Tutorial canvas: 10×10.
//  • Backwards construction guarantees solvability by design.
//  • Greedy solver for large grids (>20), DFS for small grids (≤20).
//  • Anti-square / closed-loop prevention in _growPath.
//  • Greedy-adjacent Phase 2b sweep.
//  • Orphan absorption.
//  • ColorLock mutual-exit validation.
//  • Tutorial levels hand-authored with STRAIGHT arrows only.
// ═══════════════════════════════════════════════════════════════════════════════

class LevelGeneratorV2 {
  // ── Entry point ─────────────────────────────────────────────────────────────

  /// Generate a level. Seeded by levelNumber for determinism.
  static LevelModel generateLevel(int levelNumber, [int seedOffset = 0]) {
    // ── Tutorial levels — hand-authored, straight arrows only ─────────────────
    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │  TUTORIAL RULE: All arrow paths in levels 1–3 are STRAIGHT (no bends). │
    // │  No color pairs (except Level 2), no direction dots (except Level 3).  │
    // │  Bent paths via _growPath() are used only from level 4 onward.         │
    // └─────────────────────────────────────────────────────────────────────────┘
    if (levelNumber == 1) return _buildTutorial1();
    if (levelNumber == 2) return _buildTutorial2();
    if (levelNumber == 3) return _buildTutorial3();

    final type    = AppConstants.levelTypeFor(levelNumber);
    int gridSize  = AppConstants.gridSizeForLevel(levelNumber);

    // Specific overrides from V1 retained
    if (levelNumber == 213) gridSize = 32;
    if (levelNumber == 395) gridSize = 35;
    if (levelNumber == 437) gridSize = 36;

    final seed = levelNumber * 103 + 51 + seedOffset * 997;
    final rng  = Random(seed);

    // Shape is now determined entirely by the hardcoded master schedule
    final maskShape = LevelSchedule.maskShapeFor(levelNumber);
    final mask      = MaskGeneratorV2.shapeByName(maskShape.name, gridSize, rng);
    final params    = _paramsFor(levelNumber, type, gridSize, mask);

    LevelModel? level;

    final bool isLargeGrid = gridSize > 20;
    final int maxAttempts  = isLargeGrid ? 25 : 20;

    for (int attempt = 0; attempt < maxAttempts && level == null; attempt++) {
      level = _attempt(
        levelNumber: levelNumber,
        gridSize: gridSize,
        mask: mask,
        params: params,
        type: type,
        rng: rng,
        maskShape: maskShape,
        attempt: attempt,
      );
    }

    // Final strict DFS verification for small grids only.
    if (level != null && !isLargeGrid) {
      final strictSolution = LevelSolver.solve(level, 6000);
      if (strictSolution == null) {
        level = null;
      } else {
        level = level.copyWith(solutionOrder: strictSolution);
      }
    }

    return level ?? _fallback(levelNumber, gridSize, mask, type);
  }

  // ── Tutorial level builders ──────────────────────────────────────────────────

  static LevelModel _buildTutorial1() {
    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │  TUTORIAL LEVEL 1 — Tap to Fire                                        │
    // │  2 solo arrows on 10×10, both immediately fireable from the start.     │
    // │  Teaches: tap → fires, blocked path → costs a life.                   │
    // └─────────────────────────────────────────────────────────────────────────┘
    final arrows = [
      ArrowModel(
        id: 'a_1_0',
        row: 4, col: 5,
        direction: ArrowDirection.right,
        isPartOfPattern: true,
        path: [[4, 5], [4, 4]],
        mechanic: SnakeMechanic.standard,
      ),
      ArrowModel(
        id: 'a_1_1',
        row: 5, col: 5,
        direction: ArrowDirection.up,
        isPartOfPattern: true,
        path: [[5, 5], [6, 5]],
        mechanic: SnakeMechanic.standard,
      ),
      ArrowModel(
        id: 'a_1_2',
        row: 7, col: 5,
        direction: ArrowDirection.up,
        isPartOfPattern: true,
        path: [[7, 5], [8, 5]],
        mechanic: SnakeMechanic.standard,
      ),
    ];
    return LevelModel(
      levelNumber: 1,
      gridSize: 10,
      arrows: arrows,
      patternName: 'Tutorial 1',
      difficulty: Difficulty.tutorial,
      maskShape: MaskShape.square,
      mask: MaskGeneratorV2.squareMask(10),
      orphanDots: [],
      solutionOrder: ['a_1_0', 'a_1_1', 'a_1_2'],
    );
  }

  static LevelModel _buildTutorial2() {
    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │  TUTORIAL LEVEL 2 — Arrow Blocking & Unblocking                       │
    // │  1 blocking arrow + 1 blocked arrow.                                    │
    // │  Teaches: arrow paths cannot cross occupied cells; clear blocker first. │
    // └─────────────────────────────────────────────────────────────────────────┘
    final arrows = [
      ArrowModel(
        id: 'a_2_0',
        row: 4, col: 4,
        direction: ArrowDirection.left,
        isPartOfPattern: true,
        path: [[4, 4], [4, 5]],
        mechanic: SnakeMechanic.standard,
      ),
      ArrowModel(
        id: 'a_2_1',
        row: 5, col: 4,
        direction: ArrowDirection.up,
        isPartOfPattern: true,
        path: [[5, 4], [6, 4]],
        mechanic: SnakeMechanic.standard,
      ),
    ];
    return LevelModel(
      levelNumber: 2,
      gridSize: 10,
      arrows: arrows,
      patternName: 'Tutorial 2',
      difficulty: Difficulty.tutorial,
      maskShape: MaskShape.square,
      mask: MaskGeneratorV2.squareMask(10),
      orphanDots: [],
      solutionOrder: ['a_2_0', 'a_2_1'],
    );
  }

  static LevelModel _buildTutorial3() {
    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │  TUTORIAL LEVEL 3 — Unblocking Chain                                   │
    // │  3 arrows in an unblocking chain.                                      │
    // │  Teaches: multi-step order planning.                                   │
    // └─────────────────────────────────────────────────────────────────────────┘
    final arrows = [
      ArrowModel(
        id: 'a_3_0',
        row: 4, col: 4,
        direction: ArrowDirection.left,
        isPartOfPattern: true,
        path: [[4, 4], [4, 5]],
        mechanic: SnakeMechanic.standard,
      ),
      ArrowModel(
        id: 'a_3_1',
        row: 5, col: 4,
        direction: ArrowDirection.up,
        isPartOfPattern: true,
        path: [[5, 4], [6, 4]],
        mechanic: SnakeMechanic.standard,
      ),
      ArrowModel(
        id: 'a_3_2',
        row: 5, col: 5,
        direction: ArrowDirection.left,
        isPartOfPattern: true,
        path: [[5, 5], [5, 6]],
        mechanic: SnakeMechanic.standard,
      ),
    ];
    return LevelModel(
      levelNumber: 3,
      gridSize: 10,
      arrows: arrows,
      patternName: 'Tutorial 3',
      difficulty: Difficulty.tutorial,
      maskShape: MaskShape.square,
      mask: MaskGeneratorV2.squareMask(10),
      orphanDots: [],
      solutionOrder: ['a_3_0', 'a_3_1', 'a_3_2'],
    );
  }

  // ── Single generation attempt ────────────────────────────────────────────────

  static LevelModel? _attempt({
    required int levelNumber,
    required int gridSize,
    required Set<String> mask,
    required _Params params,
    required LevelType type,
    required Random rng,
    required MaskShape maskShape,
    required int attempt,
  }) {
    final arrows           = <ArrowModel>[];
    final occupied         = <String>{};
    final occupiedPacked   = <int>{};
    int counter            = 0;

    final maskCells = mask.map((k) {
      final p = k.split(',');
      return [int.parse(p[0]), int.parse(p[1])];
    }).toList();

    final maskPacked = <int>{};
    for (final cell in maskCells) {
      maskPacked.add(cell[0] * 1000 + cell[1]);
    }

    // ── Fill strategy ────────────────────────────────────────────────────────
    // Phase 1 tries to fill the entire grid for the first 12 attempts.
    // After that it falls back to a density target that decreases on each retry.
    // V2 CHANGE: Phase 2 fill rate is capped per level to avoid 2-cell dominance.
    bool fillEntireGrid = type != LevelType.tutorial && attempt < 12;
    if (levelNumber == 213 || levelNumber == 395 || levelNumber == 437) {
      fillEntireGrid = false;
    }

    int targetCount = fillEntireGrid ? mask.length : params.arrowCount;
    if (!fillEntireGrid) {
      double fillRate;
      if (levelNumber == 213 || levelNumber == 395 || levelNumber == 437) {
        fillRate = 0.55;
      } else {
        fillRate = (1.0 - (attempt - 12) * 0.02).clamp(0.68, 0.95);
      }
      final targetOccupied = (mask.length * fillRate).round();
      targetCount = (targetOccupied / params.avgLen).round().clamp(4, 300);
    }



    // ═══════════════════════════════════════════════════════════════════════════
    //  PHASE 1 — Place VeryLong / Long / Medium / Short arrows (≥3 cell first)
    //  V2 CHANGE: Short tier added (10% weight, length=2).
    //  V2 CHANGE: Tangle factor starts at 0.20 from level 4 (was 0.0).
    // ═══════════════════════════════════════════════════════════════════════════
    {
      int failures     = 0;
      int veryLongCount = 0;
      int longCount     = 0;
      int medCount      = 0;
      int shortCount    = 0;
      final int maxFailures = type == LevelType.tutorial ? 60 : 80;

      // ── V2 Tangle factor ──────────────────────────────────────────────────
      final double tangleFactor = _tangleFactorFor(levelNumber, type);

      // Grid-size-adaptive tier thresholds (substantially longer paths for levels > 500)
      int veryLongMin = (levelNumber > 500) ? (7 + (gridSize ~/ 5)) : (5 + (gridSize ~/ 6));
      int longMin     = (levelNumber > 500) ? (4 + (gridSize ~/ 8)) : (3 + (gridSize ~/ 10));
      int veryLongMax = max(veryLongMin + 1,
          (veryLongMin + (levelNumber > 500 ? 8 : 4)).clamp(veryLongMin + 1, mask.length));

      if (maskShape != MaskShape.square && maskShape != MaskShape.longRectangle) {
        veryLongMin = max(5, (veryLongMin * 0.85).round());
        longMin     = max(3, (longMin     * 0.85).round());
        veryLongMax = max(veryLongMin + 1, (veryLongMax * 0.85).round());
      }

      final int maxAllowedBlocks =
          (type == LevelType.tutorial || gridSize > 20) ? 0 : 1;

      while (failures < maxFailures &&
          (fillEntireGrid
              ? occupiedPacked.length < mask.length
              : arrows.length < targetCount)) {

        final int relaxation     = failures ~/ 8;
        final int curVeryLongMin = max(5, veryLongMin - relaxation);
        final int curLongMin     = max(3, longMin     - relaxation);
        final int curVeryLongMax =
            max(curVeryLongMin + 1, veryLongMax - relaxation);

        final candidates = _exitCandidates(
            maskCells, occupiedPacked, gridSize, maxAllowedBlocks);
        if (candidates.isEmpty) break;

        // Quick check: can we still fit a ≥3-cell arrow?
        bool anyCanFit3 = false;
        for (final cell in maskCells) {
          final r = cell[0], c = cell[1];
          if (occupiedPacked.contains(r * 1000 + c)) continue;
          int freeNb = 0;
          for (final nb in [[-1,0],[1,0],[0,-1],[0,1]]) {
            final nr = r + nb[0], nc = c + nb[1];
            if (maskPacked.contains(nr * 1000 + nc) &&
                !occupiedPacked.contains(nr * 1000 + nc)) {
              freeNb++;
            }
          }
          if (freeNb >= 2) { anyCanFit3 = true; break; }
        }
        if (!anyCanFit3) break; // hand off to Phase 2

        _shuffleCandidatesFromCenter(candidates, gridSize, rng);

        _Cand? bestCand;
        List<List<int>>? bestPath;
        int minBlocked = 9999;

        // ── V2: 4-tier selection (35% VeryLong, 30% Long, 25% Medium, 10% Short)
        final _LenTier wantTier = _selectTier(
          type: type,
          failures: failures,
          veryLongCount: veryLongCount,
          longCount: longCount,
          medCount: medCount,
          shortCount: shortCount,
          rng: rng,
        );

        for (final cand in candidates.take(15)) {
          final int len = _lengthForTier(
            wantTier, curVeryLongMin, curVeryLongMax, curLongMin, type, rng);

          final path = _growPath(
            startRow: cand.row,
            startCol: cand.col,
            exitDir: cand.dir,
            maskPacked: maskPacked,
            occupiedPacked: occupiedPacked,
            targetLen: len,
            rng: rng,
            gridSize: gridSize,
            tangleFactor: wantTier == _LenTier.veryLong ? tangleFactor : 0.0,
          );

          final int minAcceptableLen = _minAcceptableLen(
              wantTier, curVeryLongMin, curLongMin, type);

          if (path != null && path.length >= minAcceptableLen) {
            final blockedCount = _evalPlacement(
              maskCells: maskCells,
              maskPacked: maskPacked,
              currentOccupiedPacked: occupiedPacked,
              newPath: path,
              gridSize: gridSize,
            );
            if (blockedCount == 0) {
              bestCand  = cand;
              bestPath  = path;
              minBlocked = 0;
              break;
            }
            if (blockedCount < minBlocked) {
              minBlocked = blockedCount;
              bestCand   = cand;
              bestPath   = path;
            }
          }
        }

        // Fallback cascade: try shorter tiers
        if (bestPath == null && type != LevelType.tutorial) {
          bestPath = _fallbackPlacement(
            wantTier: wantTier,
            candidates: candidates,
            curVeryLongMin: curVeryLongMin,
            curVeryLongMax: curVeryLongMax,
            curLongMin: curLongMin,
            maskPacked: maskPacked,
            occupiedPacked: occupiedPacked,
            gridSize: gridSize,
            rng: rng,
            bestCandOut: (c) => bestCand = c,
            minBlockedOut: (b) => minBlocked = b,
          );
        }

        if (bestCand != null && bestPath != null && minBlocked < 1000) {
          _placeArrow(arrows, bestPath, bestCand!.dir,
              levelNumber, counter++, occupied, occupiedPacked);
          if (bestPath.length >= curVeryLongMin)      veryLongCount++;
          else if (bestPath.length >= curLongMin)     longCount++;
          else if (bestPath.length >= 3)              medCount++;
          else                                          shortCount++;
          failures = 0;
        } else {
          failures++;
          if (failures > 50 &&
              bestPath == null &&
              occupiedPacked.length >= maskPacked.length * 0.5) break;
        }
      }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  PHASE 2 — 2-cell pair sweep (fills remaining gaps)
    // ═══════════════════════════════════════════════════════════════════════════
    if (type != LevelType.tutorial) {
      final double phase2MaxFill = _phase2MaxFill(levelNumber, type);
      final int phase2TargetCells = (maskPacked.length * phase2MaxFill).round();
      final int maxAllowedBlocks  = 0;

      // ── Sub-pass 2a: exit-constrained length-2 arrows ────────────────────
      {
        int failures = 0;
        while (failures < 60 && occupiedPacked.length < phase2TargetCells) {
          final candidates = _exitCandidates(
              maskCells, occupiedPacked, gridSize, maxAllowedBlocks);
          if (candidates.isEmpty) break;

          _shuffleCandidatesFromCenter(candidates, gridSize, rng);

          _Cand?        bestCand;
          List<List<int>>? bestPath;
          int minBlocked = 9999;

          for (final cand in candidates.take(20)) {
            final path = _growPath(
              startRow: cand.row,
              startCol: cand.col,
              exitDir: cand.dir,
              maskPacked: maskPacked,
              occupiedPacked: occupiedPacked,
              targetLen: 2,
              rng: rng,
              gridSize: gridSize,
            );
            if (path != null && path.length == 2) {
              final bc = _evalPlacement(
                maskCells: maskCells,
                maskPacked: maskPacked,
                currentOccupiedPacked: occupiedPacked,
                newPath: path,
                gridSize: gridSize,
              );
              if (bc == 0) {
                bestCand = cand; bestPath = path; minBlocked = 0; break;
              }
              if (bc < minBlocked) {
                minBlocked = bc; bestCand = cand; bestPath = path;
              }
            }
          }

          if (bestCand != null && bestPath != null && minBlocked < 1000) {
            _placeArrow(arrows, bestPath, bestCand.dir,
                levelNumber, counter++, occupied, occupiedPacked);
            failures = 0;
          } else {
            failures++;
          }
        }
      }

      // ── Sub-pass 2b: greedy adjacent-pair sweep (clean-exit only) ──────────
      {
        bool madeProgress = true;
        while (madeProgress && occupiedPacked.length < phase2TargetCells) {
          madeProgress = false;
          final emptyCells = maskCells
              .where((c) => !occupiedPacked.contains(c[0] * 1000 + c[1]))
              .toList()
            ..shuffle(rng);

          for (final cell in emptyCells) {
            final r = cell[0], c = cell[1];
            if (occupiedPacked.contains(r * 1000 + c)) continue;

            final nbOffsets = [[-1,0],[1,0],[0,-1],[0,1]]..shuffle(rng);
            for (final nb in nbOffsets) {
              final tr = r + nb[0], tc = c + nb[1];
              if (!maskPacked.contains(tr * 1000 + tc)) continue;
              if (occupiedPacked.contains(tr * 1000 + tc)) continue;

              final ArrowDirection dir1, dir2;
              if      (nb[0] ==  1) { dir1 = ArrowDirection.up;    dir2 = ArrowDirection.down; }
              else if (nb[0] == -1) { dir1 = ArrowDirection.down;  dir2 = ArrowDirection.up;   }
              else if (nb[1] ==  1) { dir1 = ArrowDirection.left;  dir2 = ArrowDirection.right; }
              else                   { dir1 = ArrowDirection.right; dir2 = ArrowDirection.left;  }

              int headRow, headCol, tailRow, tailCol;
              ArrowDirection chosenDir;

              if (_canExitClean(r, c, dir1, occupiedPacked, gridSize)) {
                headRow = r;  headCol = c;  tailRow = tr; tailCol = tc;
                chosenDir = dir1;
              } else if (_canExitClean(tr, tc, dir2, occupiedPacked, gridSize)) {
                headRow = tr; headCol = tc; tailRow = r;  tailCol = c;
                chosenDir = dir2;
              } else {
                continue;
              }

              arrows.add(ArrowModel(
                id: 'a_${levelNumber}_${counter++}',
                row: headRow, col: headCol,
                direction: chosenDir,
                isPartOfPattern: true,
                path: [[headRow, headCol], [tailRow, tailCol]],
                mechanic: SnakeMechanic.standard,
              ));
              occupied.add('$r,$c');
              occupied.add('$tr,$tc');
              occupiedPacked.add(r * 1000 + c);
              occupiedPacked.add(tr * 1000 + tc);
              madeProgress = true;
              break;
            }
          }
        }
      }

      // ── Sub-pass 2c: fallback greedy sweep (no clean-exit requirement) ──────
      {
        bool madeProgress = true;
        while (madeProgress && occupiedPacked.length < phase2TargetCells) {
          madeProgress = false;
          final emptyCells = maskCells
              .where((c) => !occupiedPacked.contains(c[0] * 1000 + c[1]))
              .toList()
            ..shuffle(rng);

          for (final cell in emptyCells) {
            final r = cell[0], c = cell[1];
            if (occupiedPacked.contains(r * 1000 + c)) continue;

            final nbOffsets = [[-1,0],[1,0],[0,-1],[0,1]]..shuffle(rng);
            for (final nb in nbOffsets) {
              final tr = r + nb[0], tc = c + nb[1];
              if (!maskPacked.contains(tr * 1000 + tc)) continue;
              if (occupiedPacked.contains(tr * 1000 + tc)) continue;

              final ArrowDirection dir1, dir2;
              if      (nb[0] ==  1) { dir1 = ArrowDirection.up;    dir2 = ArrowDirection.down; }
              else if (nb[0] == -1) { dir1 = ArrowDirection.down;  dir2 = ArrowDirection.up;   }
              else if (nb[1] ==  1) { dir1 = ArrowDirection.left;  dir2 = ArrowDirection.right; }
              else                   { dir1 = ArrowDirection.right; dir2 = ArrowDirection.left;  }

              final tries = rng.nextBool()
                  ? [[r, c, tr, tc, dir1], [tr, tc, r, c, dir2]]
                  : [[tr, tc, r, c, dir2], [r, c, tr, tc, dir1]];

              for (final t in tries) {
                final hr = t[0] as int, hc = t[1] as int;
                final tailR = t[2] as int, tailC = t[3] as int;
                final dir = t[4] as ArrowDirection;
                if (_canExitClean(hr, hc, dir, occupiedPacked, gridSize)) {
                  arrows.add(ArrowModel(
                    id: 'a_${levelNumber}_${counter++}',
                    row: hr, col: hc,
                    direction: dir,
                    isPartOfPattern: true,
                    path: [[hr, hc], [tailR, tailC]],
                    mechanic: SnakeMechanic.standard,
                  ));
                  occupied.add('$hr,$hc');
                  occupied.add('$tailR,$tailC');
                  occupiedPacked.add(hr * 1000 + hc);
                  occupiedPacked.add(tailR * 1000 + tailC);
                  madeProgress = true;
                  break;
                }
              }
              if (madeProgress) break;
            }
          }
        }
      }


    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  PHASE 3 — Orphan minimisation + direction-dot coloring + color pairs
    // ═══════════════════════════════════════════════════════════════════════════

    // Absorb isolated single empty cells into adjacent arrow tails
    if (type != LevelType.tutorial && occupied.length < mask.length) {
      _absorbOrphans(arrows, occupied, occupiedPacked, mask);
    }

    if (arrows.isEmpty) return null;

    // Minimum arrow density check (30% of mask)
    final minArrowCoverage = (mask.length * 0.30).floor();
    if (occupied.length < minArrowCoverage && type != LevelType.tutorial) {
      _log('Level $levelNumber Attempt $attempt: too sparse\n');
      return null;
    }

    final emptyCount = mask.length - occupied.length;
    const double maxOrphansPct = 0.26;
    final maxOrphans = (mask.length * maxOrphansPct).ceil().clamp(5, 300);

    if (fillEntireGrid && emptyCount > maxOrphans) {
      _log('Level $levelNumber Attempt $attempt: too many orphans $emptyCount/$maxOrphans\n');
      return null;
    }

    // Create orphan dots (neutral background dots only)
    final orphanDots = <OrphanDot>[];
    if (emptyCount > 0) {
      final emptyKeysPacked = maskCells
          .where((c) => !occupiedPacked.contains(c[0] * 1000 + c[1]))
          .map((c) => c[0] * 1000 + c[1])
          .toSet();

      for (final kp in emptyKeysPacked) {
        final r = kp ~/ 1000, c = kp % 1000;
        orphanDots.add(OrphanDot(row: r, col: c, type: OrphanDotType.neutral));
        occupied.add('$r,$c');
      }
    }

    // ── V2: Color pair mechanic mix ───────────────────────────────────────────
    // STRICT GATE: no pairs before level 16 for any level type
    if (levelNumber == 2 ||
        (type != LevelType.tutorial && levelNumber >= 16)) {
      _mechanicMixV2(
          arrows, levelNumber, type, rng, gridSize, orphanDots);
    }

    final level = LevelModel(
      levelNumber: levelNumber,
      gridSize: gridSize,
      arrows: arrows,
      patternName: _nameFor(type, levelNumber),
      difficulty: _difficultyFor(levelNumber, type),
      maskShape: maskShape,
      mask: mask,
      orphanDots: orphanDots,
    );

    // Solvability check
    if (gridSize > 20) {
      final greedyOrder = _greedySolve(level);
      if (greedyOrder == null) {
        _log('Level $levelNumber Attempt $attempt: greedy FAILED\n');
        return null;
      }
      _log('Level $levelNumber Attempt $attempt: SUCCEEDED (greedy)\n');
      return level.copyWith(solutionOrder: greedyOrder);
    }

    final quickSolution = LevelSolver.solve(level, 5000);
    if (quickSolution == null) {
      _log('Level $levelNumber Attempt $attempt: solver failed\n');
      return null;
    }
    _log('Level $levelNumber Attempt $attempt: SUCCEEDED\n');
    return level.copyWith(solutionOrder: quickSolution);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  V2 HELPERS — New/changed from V1
  // ═══════════════════════════════════════════════════════════════════════════

  // ── V2: Tangle factor ──────────────────────────────────────────────────────
  /// Returns a tangle factor in [0.0, 1.0].
  /// V2 starts at 0.20 from level 4 instead of 0.0 — makes early levels
  /// visually interesting even without mechanics.
  static double _tangleFactorFor(int levelNumber, LevelType type) {
    if (type == LevelType.tutorial) return 0.0;
    double base;
    if      (levelNumber <= 6)   base = 0.50; // level 4-6:   immediate strong tangle
    else if (levelNumber <= 12)  base = 0.70; // level 7-12:  very high tangle
    else if (levelNumber <= 20)  base = 0.85; // level 13-20: extreme tangle
    else                         base = 1.0;  // level 21+:   maximum zig-zag

    if      (type == LevelType.boss) base = (base + 0.20).clamp(0.50, 1.0);
    else if (type == LevelType.god)  base = (base + 0.30).clamp(0.65, 1.0);
    return base;
  }

  // ── V2: 4-tier selection ───────────────────────────────────────────────────
  /// V2: 4-tier weighted selection: 50% VeryLong, 30% Long, 10% Medium, 10% Short.
  static _LenTier _selectTier({
    required LevelType type,
    required int failures,
    required int veryLongCount,
    required int longCount,
    required int medCount,
    required int shortCount,
    required Random rng,
  }) {
    if (type == LevelType.tutorial) return _LenTier.medium;
    if (failures > 15)             return _LenTier.medium;

    final total = veryLongCount + longCount + medCount + shortCount;
    if (total == 0) return _LenTier.veryLong; // always start with very long

    final vlRatio  = veryLongCount / total;
    final lRatio   = longCount     / total;
    final medRatio = medCount      / total;

    // Heavily favor long & very-long winding arrows (65% VL, 28% L, 5% M, 2% S) to reduce short arrows
    if (vlRatio  < 0.65) return _LenTier.veryLong;
    if (lRatio   < 0.28) return _LenTier.long;
    if (medRatio < 0.05) return _LenTier.medium;
    return _LenTier.short;
  }

  static int _lengthForTier(_LenTier tier, int veryLongMin, int veryLongMax,
      int longMin, LevelType type, Random rng) {
    switch (tier) {
      case _LenTier.veryLong:
        final range = max(1, veryLongMax - veryLongMin + 1);
        return veryLongMin + rng.nextInt(range);
      case _LenTier.long:
        final longMax = max(longMin, veryLongMin - 1);
        final range   = max(1, longMax - longMin + 1);
        return longMin + rng.nextInt(range);
      case _LenTier.medium:
        return type == LevelType.tutorial
            ? 2 + rng.nextInt(3)
            : 3 + rng.nextInt(3);
      case _LenTier.short:
        return 2;
    }
  }

  static int _minAcceptableLen(_LenTier tier, int curVeryLongMin,
      int curLongMin, LevelType type) {
    switch (tier) {
      case _LenTier.veryLong: return curVeryLongMin;
      case _LenTier.long:     return curLongMin;
      case _LenTier.medium:   return 3;
      case _LenTier.short:    return 2;
    }
  }

  // ── V2: Phase 2 max fill rate ─────────────────────────────────────────────
  static double _phase2MaxFill(int levelNumber, LevelType type) {
    if (type == LevelType.god)  return 0.98; // God levels 98% grid coverage
    if (type == LevelType.boss) return 0.94; // Boss levels 94% grid coverage

    if      (levelNumber <= 10)  return 0.80;
    else if (levelNumber <= 30)  return 0.88;
    else                         return 0.95;
  }

  // ── V2: Color pair mechanic mix ───────────────────────────────────────────
  static void _mechanicMixV2(List<ArrowModel> arrows, int level, LevelType type,
      Random rng, int gridSize, List<OrphanDot> orphanDots) {
    // Feature removed: no color key/lock pairs are generated
    return;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  UNCHANGED FROM V1 — Preserved exactly for correctness
  // ═══════════════════════════════════════════════════════════════════════════

  static void _placeArrow(
    List<ArrowModel> arrows, List<List<int>> path,
    ArrowDirection dir, int levelNumber, int counter,
    Set<String> occupied, Set<int> occupiedPacked,
  ) {
    final head = path[0];
    arrows.add(ArrowModel(
      id: 'a_${levelNumber}_$counter',
      row: head[0], col: head[1],
      direction: dir,
      isPartOfPattern: true,
      path: path,
      mechanic: SnakeMechanic.standard,
    ));
    for (final pt in path) {
      occupied.add('${pt[0]},${pt[1]}');
      occupiedPacked.add(pt[0] * 1000 + pt[1]);
    }
  }

  static void _shuffleCandidatesFromCenter(
      List<_Cand> candidates, int gridSize, Random rng) {
    final centerRow = gridSize / 2;
    final centerCol = gridSize / 2;
    candidates.sort((a, b) {
      final distA = (a.row - centerRow).abs() + (a.col - centerCol).abs();
      final distB = (b.row - centerRow).abs() + (b.col - centerCol).abs();
      final scoreA = distA + a.blockedCount * 3.0 + (rng.nextDouble() * 3.0 - 1.5);
      final scoreB = distB + b.blockedCount * 3.0 + (rng.nextDouble() * 3.0 - 1.5);
      return scoreA.compareTo(scoreB);
    });
  }

  static List<_Cand> _exitCandidates(List<List<int>> maskCells,
      Set<int> occupiedPacked, int gridSize, int maxAllowedBlocks) {
    final out = <_Cand>[];
    for (final cell in maskCells) {
      final r = cell[0], c = cell[1];
      if (occupiedPacked.contains(r * 1000 + c)) continue;
      for (final dir in ArrowDirection.values) {
        final d = dir.delta;
        int nr = r + d[0], nc = c + d[1];
        int blockedCount = 0;
        while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
          if (occupiedPacked.contains(nr * 1000 + nc)) blockedCount++;
          nr += d[0]; nc += d[1];
        }
        if (blockedCount <= maxAllowedBlocks) {
          out.add(_Cand(r, c, dir, blockedCount: blockedCount));
        }
      }
    }
    return out;
  }

  /// Path growth with tangle algorithm + anti-square + self-avoiding.
  /// V2 ASSERTION: verifies no self-intersection and no U-turn in debug builds.
  static List<List<int>>? _growPath({
    required int startRow,
    required int startCol,
    required ArrowDirection exitDir,
    required Set<int> maskPacked,
    required Set<int> occupiedPacked,
    required int targetLen,
    required Random rng,
    required int gridSize,
    double tangleFactor = 0.0,
  }) {
    final exitPath = _getExitPathPacked(startRow, startCol, exitDir, gridSize);
    final path     = <List<int>>[[startRow, startCol]];
    final pathPacked = <int>{startRow * 1000 + startCol};
    int cr = startRow, cc = startCol;
    var growDir = exitDir.opposite;
    int straight = 0;

    final double turnBias   = 0.65 + tangleFactor * 0.20;
    final int    maxStraight = tangleFactor >= 0.7 ? 2 : 3;

    for (int step = 1; step < targetLen; step++) {
      final valid = <ArrowDirection>[];
      for (final d in ArrowDirection.values) {
        if (d == growDir.opposite) continue;
        final nd = d.delta;
        final nr = cr + nd[0], nc = cc + nd[1];
        final np = nr * 1000 + nc;
        if (!maskPacked.contains(np)) continue;
        if (occupiedPacked.contains(np)) continue;
        if (exitPath.contains(np)) continue;
        if (pathPacked.contains(np)) continue;

        // Anti-square: reject if new cell touches any path cell other than current
        bool wouldFormLoop = false;
        for (final nb in [[-1,0],[1,0],[0,-1],[0,1]]) {
          final adjP = (nr + nb[0]) * 1000 + (nc + nb[1]);
          if (adjP != cr * 1000 + cc && pathPacked.contains(adjP)) {
            wouldFormLoop = true; break;
          }
        }
        if (wouldFormLoop) continue;
        valid.add(d);
      }
      if (valid.isEmpty) break;

      if (step == 1 && !valid.contains(growDir)) return null;

      final mustTurn  = straight >= maxStraight;
      final turns     = valid.where((d) => d != growDir).toList();
      final straights = valid.where((d) => d == growDir).toList();

      ArrowDirection chosen;
      if (step == 1) {
        chosen = growDir;
      } else if (mustTurn && turns.isNotEmpty) {
        chosen = _packedPick(turns, cr, cc, occupiedPacked, rng);
      } else if (valid.length == 1) {
        chosen = valid[0];
      } else if (rng.nextDouble() < turnBias && turns.isNotEmpty) {
        chosen = _packedPick(turns, cr, cc, occupiedPacked, rng);
      } else if (straights.isNotEmpty) {
        chosen = straights[0];
      } else {
        chosen = _packedPick(turns, cr, cc, occupiedPacked, rng);
      }

      straight = chosen == growDir ? straight + 1 : 0;
      final nd = chosen.delta;
      cr += nd[0]; cc += nd[1];
      path.add([cr, cc]);
      pathPacked.add(cr * 1000 + cc);
      growDir = chosen;
    }

    final result = path.length >= 2 ? path : null;

    // ── V2 Debug Assertion: self-avoiding verification ────────────────────────
    assert(() {
      if (result == null) return true;
      final seen = <int>{};
      for (int i = 0; i < result.length; i++) {
        final pk = result[i][0] * 1000 + result[i][1];
        assert(!seen.contains(pk),
          'V2: Self-intersection at step $i (row=${result[i][0]}, col=${result[i][1]})');
        seen.add(pk);
        if (i >= 2) {
          final dr1 = result[i-1][0] - result[i-2][0];
          final dc1 = result[i-1][1] - result[i-2][1];
          final dr2 = result[i][0]   - result[i-1][0];
          final dc2 = result[i][1]   - result[i-1][1];
          assert(!(dr2 == -dr1 && dc2 == -dc1),
            'V2: U-turn (180° reversal) at step $i');
        }
      }
      return true;
    }());

    return result;
  }

  static ArrowDirection _packedPick(List<ArrowDirection> dirs,
      int cr, int cc, Set<int> occupiedPacked, Random rng) {
    if (dirs.length == 1) return dirs[0];
    int best = -1;
    final bestDirs = <ArrowDirection>[];
    for (final d in dirs) {
      final nd = d.delta;
      final nr = cr + nd[0], nc = cc + nd[1];
      int score = 0;
      for (final nb in [[-1,0],[1,0],[0,-1],[0,1]]) {
        if (occupiedPacked.contains((nr + nb[0]) * 1000 + (nc + nb[1]))) score++;
      }
      if (score > best) { best = score; bestDirs.clear(); bestDirs.add(d); }
      else if (score == best) bestDirs.add(d);
    }
    return bestDirs[rng.nextInt(bestDirs.length)];
  }

  static int _evalPlacement({
    required List<List<int>> maskCells,
    required Set<int> maskPacked,
    required Set<int> currentOccupiedPacked,
    required List<List<int>> newPath,
    required int gridSize,
  }) {
    final bool runLookAhead = gridSize < 20 &&
        currentOccupiedPacked.length >= maskPacked.length * 0.7;
    if (!runLookAhead) return 0;
    return _countBlockedEmptyCells(
      maskCells: maskCells,
      maskPacked: maskPacked,
      currentOccupiedPacked: currentOccupiedPacked,
      newPath: newPath,
      gridSize: gridSize,
    );
  }

  static List<List<int>>? _fallbackPlacement({
    required _LenTier wantTier,
    required List<_Cand> candidates,
    required int curVeryLongMin,
    required int curVeryLongMax,
    required int curLongMin,
    required Set<int> maskPacked,
    required Set<int> occupiedPacked,
    required int gridSize,
    required Random rng,
    required void Function(_Cand) bestCandOut,
    required void Function(int) minBlockedOut,
  }) {
    List<List<int>>? bestPath;
    int minBlocked = 9999;
    _Cand? bestCand;

    void tryTier(int Function() lenGen, int minLen) {
      for (final cand in candidates.take(15)) {
        final len  = lenGen();
        final path = _growPath(
          startRow: cand.row, startCol: cand.col, exitDir: cand.dir,
          maskPacked: maskPacked, occupiedPacked: occupiedPacked,
          targetLen: len, rng: rng, gridSize: gridSize,
        );
        if (path != null && path.length >= minLen) {
          final bc = _evalPlacement(
            maskCells: [], maskPacked: maskPacked,
            currentOccupiedPacked: occupiedPacked,
            newPath: path, gridSize: gridSize,
          );
          if (bc == 0) { bestCand = cand; bestPath = path; minBlocked = 0; return; }
          if (bc < minBlocked) { minBlocked = bc; bestCand = cand; bestPath = path; }
        }
      }
    }

    if (wantTier == _LenTier.veryLong) {
      tryTier(() {
        final longMax = max(curLongMin, curVeryLongMin - 1);
        return curLongMin + rng.nextInt(max(1, longMax - curLongMin + 1));
      }, curLongMin);
    }

    if (bestPath == null &&
        (wantTier == _LenTier.veryLong || wantTier == _LenTier.long)) {
      tryTier(() => 3 + rng.nextInt(3), 3);
    }

    if (bestCand != null) {
      bestCandOut(bestCand!);
      minBlockedOut(minBlocked);
    }
    return bestPath;
  }

  static bool _canExitClean(int headRow, int headCol, ArrowDirection dir,
      Set<int> occupiedPacked, int gridSize) {
    final d = dir.delta;
    int nr = headRow + d[0], nc = headCol + d[1];
    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      if (occupiedPacked.contains(nr * 1000 + nc)) return false;
      nr += d[0]; nc += d[1];
    }
    return true;
  }

  static Set<int> _getExitPathPacked(
      int startRow, int startCol, ArrowDirection exitDir, int gridSize) {
    final path = <int>{};
    final d = exitDir.delta;
    int nr = startRow + d[0], nc = startCol + d[1];
    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      path.add(nr * 1000 + nc);
      nr += d[0]; nc += d[1];
    }
    return path;
  }

  static _Params _paramsFor(
      int level, LevelType type, int gridSize, Set<String> mask) {
    int avgLen, arrowCount;
    if (level <= 3) {
      avgLen = 2; arrowCount = 4;
    } else {
      if (level == 395 || level == 437) {
        avgLen = 6;
      } else if (level <= 15) {
        avgLen = 3;
      } else if (level <= 50) {
        avgLen = 4;
      } else {
        avgLen = 5;
      }
      arrowCount =
          ((mask.length * 1.0) / avgLen).round().clamp(4, 300);
    }
    return _Params(arrowCount, avgLen);
  }

  static Difficulty _difficultyFor(int level, LevelType type) {
    if (type == LevelType.tutorial) return Difficulty.tutorial;
    if (type == LevelType.god)      return Difficulty.legend;
    if (type == LevelType.boss) {
      if (level <= 20)  return Difficulty.hard;
      if (level <= 50)  return Difficulty.expert;
      if (level <= 100) return Difficulty.master;
      return Difficulty.legend;
    }
    if (level <= 20)  return Difficulty.easy;
    if (level <= 50)  return Difficulty.medium;
    if (level <= 100) return Difficulty.hard;
    if (level <= 200) return Difficulty.expert;
    if (level <= 400) return Difficulty.master;
    return Difficulty.legend;
  }

  static String _nameFor(LevelType type, int level) {
    switch (type) {
      case LevelType.boss:     return 'Boss $level';
      case LevelType.god:      return 'God $level';
      case LevelType.tutorial: return 'Tutorial';
      default:                 return 'Level $level';
    }
  }

  static LevelModel _fallback(
      int levelNumber, int gridSize, Set<String> mask, LevelType type) {
    final arrows = <ArrowModel>[];
    final mid = gridSize ~/ 2;
    int i = 0;
    for (int col = 0; col < gridSize && i < 4; col++) {
      if (!mask.contains('$mid,$col')) continue;
      arrows.add(ArrowModel(
        id: 'fb_${levelNumber}_$i',
        row: mid, col: col,
        direction: ArrowDirection.right,
        isPartOfPattern: true,
        path: [[mid, col]],
      ));
      i++;
    }
    return LevelModel(
      levelNumber: levelNumber,
      gridSize: gridSize,
      arrows: arrows,
      patternName: 'fallback',
      difficulty: Difficulty.easy,
      solutionOrder: arrows.reversed.map((a) => a.id).toList(),
      mask: mask,
    );
  }

  static int _countBlockedEmptyCells({
    required List<List<int>> maskCells,
    required Set<int> maskPacked,
    required Set<int> currentOccupiedPacked,
    required List<List<int>> newPath,
    required int gridSize,
  }) {
    final newPathPacked = <int>{};
    for (final pt in newPath) newPathPacked.add(pt[0] * 1000 + pt[1]);

    bool isOccupied(int packed) =>
        currentOccupiedPacked.contains(packed) || newPathPacked.contains(packed);

    final rowsToCheck   = newPath.map((pt) => pt[0]).toSet();
    final colsToCheck   = newPath.map((pt) => pt[1]).toSet();
    final adjacentKeys  = <int>{};
    for (final pt in newPath) {
      for (final offset in [[-1,0],[1,0],[0,-1],[0,1]]) {
        adjacentKeys.add((pt[0] + offset[0]) * 1000 + (pt[1] + offset[1]));
      }
    }

    int blocked = 0;
    for (final cell in maskCells) {
      final r = cell[0], c = cell[1];
      final packed = r * 1000 + c;
      if (isOccupied(packed)) continue;
      final isNear = rowsToCheck.contains(r) || colsToCheck.contains(c) ||
          adjacentKeys.contains(packed);
      if (!isNear) continue;

      int emptyNeighbors = 0;
      for (final nb in [[-1,0],[1,0],[0,-1],[0,1]]) {
        final np = (r + nb[0]) * 1000 + (c + nb[1]);
        if (maskPacked.contains(np) && !isOccupied(np)) emptyNeighbors++;
      }
      if (emptyNeighbors == 0) { blocked += 100; continue; }

      bool hasExit = false;
      for (final dir in ArrowDirection.values) {
        final d = dir.delta;
        final backPacked = (r - d[0]) * 1000 + (c - d[1]);
        if (!maskPacked.contains(backPacked) || isOccupied(backPacked)) continue;
        int nr = r + d[0], nc = c + d[1];
        bool pathClear = true;
        while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
          if (isOccupied(nr * 1000 + nc)) { pathClear = false; break; }
          nr += d[0]; nc += d[1];
        }
        if (pathClear) { hasExit = true; break; }
      }
      if (!hasExit) blocked += 100;
    }
    return blocked;
  }

  static void _absorbOrphans(List<ArrowModel> arrows, Set<String> occupied,
      Set<int> occupiedPacked, Set<String> mask) {
    final orphans = mask.where((k) => !occupied.contains(k)).toList();
    for (final cellKey in orphans) {
      final parts = cellKey.split(',');
      final r = int.parse(parts[0]), c = int.parse(parts[1]);
      for (int i = 0; i < arrows.length; i++) {
        final arrow = arrows[i];
        final tail  = arrow.path.last;
        final dist  = (tail[0] - r).abs() + (tail[1] - c).abs();
        if (dist == 1) {
          bool wouldFormLoop = false;
          if (arrow.path.length >= 3) {
            for (final nb in [[-1,0],[1,0],[0,-1],[0,1]]) {
              final adjR = r + nb[0], adjC = c + nb[1];
              if (adjR == tail[0] && adjC == tail[1]) continue;
              for (final pt in arrow.path) {
                if (pt[0] == adjR && pt[1] == adjC) { wouldFormLoop = true; break; }
              }
              if (wouldFormLoop) break;
            }
          }
          if (wouldFormLoop) continue;
          final newPath = List<List<int>>.from(arrow.path)..add([r, c]);
          arrows[i] = arrow.copyWith(path: newPath);
          occupied.add(cellKey);
          occupiedPacked.add(r * 1000 + c);
          break;
        }
      }
    }
  }

  // ── Greedy solver (identical to V1) ────────────────────────────────────────

  static List<String>? _greedySolveWithMap(
      int gridSize, List<ArrowModel> arrows, Map<int, OrphanDotType> orphanMap) {
    final board = Uint16List(gridSize * gridSize);
    for (int i = 0; i < arrows.length; i++) {
      for (final pt in arrows[i].path) {
        board[pt[0] * gridSize + pt[1]] = i + 1;
      }
    }
    final orphanTypes  = Uint8List(gridSize * gridSize);
    final orphanActive = List<bool>.filled(gridSize * gridSize, false);
    orphanMap.forEach((packed, type) {
      final r = packed ~/ 1000, c = packed % 1000;
      final idx = r * gridSize + c;
      orphanTypes[idx]  = type.index;
      orphanActive[idx] = true;
    });

    final partnerOf  = List<int>.filled(arrows.length, -1);
    final grpBuckets = <int, List<int>>{};
    for (int i = 0; i < arrows.length; i++) {
      final g = arrows[i].colorGroup;
      if (g != null) grpBuckets.putIfAbsent(g, () => []).add(i);
    }
    for (final v in grpBuckets.values) {
      if (v.length == 2) { partnerOf[v[0]] = v[1]; partnerOf[v[1]] = v[0]; }
    }

    final active    = List<bool>.filled(arrows.length, true);
    final order     = <String>[];
    int remaining   = arrows.length;
    final exitVisited = Uint16List(gridSize * gridSize);
    int exitToken   = 0;

    List<int>? tryExit(int ai, int pi) {
      exitToken++;
      ArrowDirection dir = arrows[ai].direction;
      final h = arrows[ai].path[0];
      var d = dir.delta;
      int nr = h[0] + d[0], nc = h[1] + d[1];
      final consumed = <int>[];
      while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
        final idx = nr * gridSize + nc;
        if (exitVisited[idx] == exitToken) return null;
        exitVisited[idx] = exitToken;
        if (orphanActive[idx]) {
          consumed.add(idx);
          final t = orphanTypes[idx];
          if      (t == 0) dir = ArrowDirection.up;
          else if (t == 1) dir = ArrowDirection.down;
          else if (t == 2) dir = ArrowDirection.left;
          else if (t == 3) dir = ArrowDirection.right;
        } else {
          final val = board[idx];
          if (val != 0 && val != ai + 1 && (pi == -1 || val != pi + 1)) return null;
        }
        d = dir.delta; nr += d[0]; nc += d[1];
      }
      return consumed;
    }

    void clearArrow(int idx) {
      active[idx] = false;
      remaining--;
      for (final pt in arrows[idx].path) board[pt[0] * gridSize + pt[1]] = 0;
      order.add(arrows[idx].id);
    }

    bool madeProgress = true;
    final seenGroups  = <int>{};
    while (madeProgress && remaining > 0) {
      madeProgress = false;
      seenGroups.clear();
      for (int i = 0; i < arrows.length; i++) {
        if (!active[i]) continue;
        final p = partnerOf[i];
        if (p == -1) continue;
        final g = arrows[i].colorGroup!;
        if (seenGroups.contains(g)) continue;
        seenGroups.add(g);
        if (!active[p]) continue;
        final c1 = tryExit(i, p), c2 = tryExit(p, i);
        if (c1 != null && c2 != null) {
          final consumed = <int>{...c1, ...c2};
          for (final f in consumed) orphanActive[f] = false;
          clearArrow(i); clearArrow(p);
          madeProgress = true;
        }
      }
      for (int i = 0; i < arrows.length; i++) {
        if (!active[i] || partnerOf[i] != -1) continue;
        final c = tryExit(i, -1);
        if (c != null) {
          for (final f in c) orphanActive[f] = false;
          clearArrow(i);
          madeProgress = true;
        }
      }
    }
    return remaining == 0 ? order : null;
  }

  static List<String>? _greedySolve(LevelModel level) {
    final orphanMap = <int, OrphanDotType>{};
    for (final od in level.orphanDots) {
      orphanMap[od.row * 1000 + od.col] = od.type;
    }
    return _greedySolveWithMap(level.gridSize, level.arrows, orphanMap);
  }

  static void _log(String msg) {
    try {
      File('attempt_log_v2.txt').writeAsStringSync(msg,
          mode: FileMode.append, flush: true);
    } catch (_) {}
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Internal helpers
// ═══════════════════════════════════════════════════════════════════════════════

enum _LenTier { veryLong, long, medium, short }

class _Cand {
  final int row, col, blockedCount;
  final ArrowDirection dir;
  _Cand(this.row, this.col, this.dir, {this.blockedCount = 0});
}

class _Params {
  final int arrowCount, avgLen;
  _Params(this.arrowCount, this.avgLen);
}
