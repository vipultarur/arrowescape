import 'dart:typed_data';
import '../models/arrow.dart';
import '../models/level.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  LevelSolver — DFS solver with node budget
// ═══════════════════════════════════════════════════════════════════════════════

class LevelSolver {
  static List<String>? solve(LevelModel level, int maxNodes) {
    final arrows   = level.arrows;
    final n        = arrows.length;
    final gridSize = level.gridSize;

    final board = Uint16List(gridSize * gridSize);
    for (int i = 0; i < n; i++) {
      for (final pt in arrows[i].path) {
        board[pt[0] * gridSize + pt[1]] = i + 1;
      }
    }

    final orphanTypes  = Uint8List(gridSize * gridSize);
    final orphanActive = List<bool>.filled(gridSize * gridSize, false);
    for (final od in level.orphanDots) {
      final idx = od.row * gridSize + od.col;
      orphanTypes[idx]  = od.type.index;
      orphanActive[idx] = true;
    }

    final partnerOf  = List<int>.filled(n, -1);
    final grpBuckets = <int, List<int>>{};
    for (int i = 0; i < n; i++) {
      final g = arrows[i].colorGroup;
      if (g != null) grpBuckets.putIfAbsent(g, () => []).add(i);
    }
    for (final v in grpBuckets.values) {
      if (v.length == 2) {
        partnerOf[v[0]] = v[1];
        partnerOf[v[1]] = v[0];
      }
    }

    int nodesExpanded   = 0;
    final active        = List<bool>.filled(n, true);
    final order         = <String>[];
    final consumedStack = <List<int>>[];

    List<int>? tryExit(int ai, int pi) {
      ArrowDirection dir = arrows[ai].direction;
      final h  = arrows[ai].path[0];
      var d    = dir.delta;
      int nr   = h[0] + d[0], nc = h[1] + d[1];
      final consumed = <int>[];
      final visited  = <int>{};
      while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
        final idx = nr * gridSize + nc;
        if (visited.contains(idx)) return null;
        visited.add(idx);
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
      for (final pt in arrows[idx].path) board[pt[0] * gridSize + pt[1]] = 0;
      order.add(arrows[idx].id);
    }

    void restoreArrow(int idx) {
      active[idx] = true;
      for (final pt in arrows[idx].path) board[pt[0] * gridSize + pt[1]] = idx + 1;
      order.removeLast();
    }

    bool dfs(int remaining) {
      if (remaining == 0) return true;
      if (nodesExpanded >= maxNodes) return false;
      nodesExpanded++;

      final seenGroups = <int>{};
      for (int i = 0; i < n; i++) {
        if (!active[i]) continue;
        final p = partnerOf[i];
        if (p == -1) continue;
        final g = arrows[i].colorGroup!;
        if (seenGroups.contains(g)) continue;
        seenGroups.add(g);
        if (!active[p]) continue;
        final c1 = tryExit(i, p), c2 = tryExit(p, i);
        if (c1 != null && c2 != null) {
          final consumed = <int>{...c1, ...c2}.toList();
          consumedStack.add(consumed);
          for (final f in consumed) orphanActive[f] = false;
          clearArrow(i); clearArrow(p);
          if (dfs(remaining - 2)) return true;
          restoreArrow(p); restoreArrow(i);
          for (final f in consumedStack.removeLast()) orphanActive[f] = true;
        }
      }

      for (int i = 0; i < n; i++) {
        if (!active[i] || partnerOf[i] != -1) continue;
        final c = tryExit(i, -1);
        if (c != null) {
          consumedStack.add(c);
          for (final f in c) orphanActive[f] = false;
          clearArrow(i);
          if (dfs(remaining - 1)) return true;
          restoreArrow(i);
          for (final f in consumedStack.removeLast()) orphanActive[f] = true;
        }
      }
      return false;
    }

    return dfs(n) ? List<String>.from(order) : null;
  }
}
