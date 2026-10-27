import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/level.dart';
import '../level_generator/level_generator_v2.dart';
import '../level_generator/level_schedule.dart';
import '../level_binary_codec.dart';

// Top-level function required by compute() to run in a background isolate.
LevelModel _generateLevelIsolate(int levelNumber) {
  return LevelGeneratorV2.generateLevel(levelNumber);
}

/// Caches generated levels and provides access by level number.
///
/// Level loading priority:
///   1. In-memory cache  (instant)
///   2. levels.bin binary asset  (O(1) seek, microseconds)
///   3. SharedPreferences disk cache
///   4. On-the-fly generation  (only for levels beyond the binary asset)
class LevelRepository {
  final SharedPreferences? _prefs;
  final Map<int, LevelModel> _cache = {};
  final Set<int> _generating = {};

  LevelBinaryDecoder? _binaryDecoder;
  bool _binaryLoaded = false;

  bool get isBinaryLoaded => _binaryLoaded;

  LevelRepository([this._prefs]);

  /// Load the binary level asset. Reads only the 8-byte header + index table
  /// on startup — individual levels are decoded lazily on demand.
  Future<void> loadPregeneratedLevels() async {
    if (_binaryLoaded) return;
    try {
      final byteData = await rootBundle.load('assets/levels.bin');
      final bytes = byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      _binaryDecoder = LevelBinaryDecoder.fromBytes(bytes);
      _binaryLoaded = true;

      // Wipe old memory & disk cache once if needed so updated pregenerated levels take effect
      _cache.clear();
      if (_prefs != null) {
        const cacheClearedKey = 'v2_cache_cleared_v5';
        if (!(_prefs!.getBool(cacheClearedKey) ?? false)) {
          final keysToRemove =
              _prefs!.getKeys().where((k) => k.startsWith('cached_level_')).toList();
          for (final key in keysToRemove) {
            _prefs!.remove(key);
          }
          await _prefs!.setBool(cacheClearedKey, true);
        }
      }
    } catch (e) {
      debugPrint('Error loading level cache: $e');
    }
  }

  /// Get a level synchronously. Always returns immediately.
  LevelModel getLevel(int levelNumber) {
    final expectedShape = LevelSchedule.maskShapeFor(levelNumber);

    // 1. In-memory cache (instant lookup — 0ms)
    if (_cache.containsKey(levelNumber)) {
      final cached = _cache[levelNumber]!;
      if (cached.maskShape == expectedShape) {
        return cached;
      }
      _cache.remove(levelNumber);
    }

    // 2. Binary decoder — O(1) seek from levels.bin
    if (_binaryLoaded && _binaryDecoder != null) {
      try {
        final level = _binaryDecoder!.decodeLevelByNumber(levelNumber);
        if (level != null && level.maskShape == expectedShape) {
          _cache[levelNumber] = level;
          return level;
        }
      } catch (e) {
        debugPrint('Error decoding binary level $levelNumber: $e');
      }
    }

    // 3. Disk cache (SharedPreferences)
    if (_prefs != null) {
      final jsonStr = _prefs!.getString('cached_level_$levelNumber');
      if (jsonStr != null) {
        try {
          final level = LevelModel.fromJson(jsonDecode(jsonStr));
          if (level.maskShape == expectedShape) {
            _cache[levelNumber] = level;
            return level;
          }
          _prefs!.remove('cached_level_$levelNumber');
        } catch (e) {
          debugPrint('Error decoding cached level: $e');
        }
      }
    }

    // 4. Generate on-the-fly via LevelGeneratorV2 (Master 2000-Level Schedule)
    final level = LevelGeneratorV2.generateLevel(levelNumber);
    _cache[levelNumber] = level;
    _saveToDisk(levelNumber, level);
    return level;
  }

  /// Asynchronously warm up [levelNumber] in a background isolate.
  /// Safe to call multiple times — duplicates are ignored.
  Future<void> preGenerateAsync(int levelNumber) async {
    if (isCached(levelNumber)) return;
    if (_generating.contains(levelNumber)) return;
    _generating.add(levelNumber);

    try {
      if (!_binaryLoaded) {
        await loadPregeneratedLevels();
      }

      // Binary asset covers it — decode directly into memory cache
      if (_binaryLoaded && _binaryDecoder != null) {
        final level = _binaryDecoder!.decodeLevelByNumber(levelNumber);
        if (level != null) {
          _cache[levelNumber] = level;
          return;
        }
      }

      // Check disk cache before spinning up an isolate
      if (_prefs != null && _prefs!.containsKey('cached_level_$levelNumber')) {
        final jsonStr = _prefs!.getString('cached_level_$levelNumber');
        if (jsonStr != null) {
          final level = LevelModel.fromJson(jsonDecode(jsonStr));
          _cache[levelNumber] = level;
          return;
        }
      }

      // Generate in a background isolate (only for levels beyond binary asset)
      final level = await compute(_generateLevelIsolate, levelNumber);
      _cache[levelNumber] = level;
      _saveToDisk(levelNumber, level);
    } catch (_) {
      // Silently ignore — getLevel() will regenerate if needed
    } finally {
      _generating.remove(levelNumber);
    }
  }

  /// Asynchronously warm up a range of levels.
  Future<void> preGenerateRangeAsync(int from, int count) async {
    if (!_binaryLoaded) {
      await loadPregeneratedLevels();
    }
    for (int i = from; i < from + count && i <= totalLevels; i++) {
      if (!_cache.containsKey(i) && !_generating.contains(i)) {
        if (_binaryLoaded && _binaryDecoder != null) {
          final level = _binaryDecoder!.decodeLevelByNumber(i);
          if (level != null) {
            _cache[i] = level;
            continue;
          }
        }
        Future.microtask(() => preGenerateAsync(i));
      }
    }
  }

  /// Pending completers for levels currently being generated.
  final Map<int, Completer<LevelModel>> _pendingCompleters = {};

  /// Async get — returns immediately if cached/binary, otherwise waits for background generation.
  Future<LevelModel> getLevelAsync(int levelNumber) async {
    if (!_binaryLoaded) {
      await loadPregeneratedLevels();
    }

    if (isCached(levelNumber)) return getLevel(levelNumber);

    // Return existing completer if generation already in flight
    if (_pendingCompleters.containsKey(levelNumber)) {
      return _pendingCompleters[levelNumber]!.future;
    }

    final completer = Completer<LevelModel>();
    _pendingCompleters[levelNumber] = completer;

    // Kick off generation
    preGenerateAsync(levelNumber).then((_) {
      if (_cache.containsKey(levelNumber) && !completer.isCompleted) {
        completer.complete(_cache[levelNumber]!);
      }
    }).catchError((e) {
      if (!completer.isCompleted) {
        // Fallback: generate synchronously
        completer.complete(getLevel(levelNumber));
      }
    });

    // Safety timeout
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingCompleters.remove(levelNumber);
        return getLevel(levelNumber);
      },
    ).whenComplete(() => _pendingCompleters.remove(levelNumber));
  }

  /// True if [levelNumber] is instantly available (no generation needed).
  bool isCached(int levelNumber) {
    final expectedShape = LevelSchedule.maskShapeFor(levelNumber);
    if (_cache.containsKey(levelNumber)) {
      if (_cache[levelNumber]!.maskShape == expectedShape) return true;
      _cache.remove(levelNumber);
    }
    if (_binaryLoaded && _binaryDecoder != null) {
      try {
        final level = _binaryDecoder!.decodeLevelByNumber(levelNumber);
        if (level != null && level.maskShape == expectedShape) {
          _cache[levelNumber] = level;
          return true;
        }
      } catch (_) {}
    }
    if (_prefs != null && _prefs!.containsKey('cached_level_$levelNumber')) {
      final jsonStr = _prefs!.getString('cached_level_$levelNumber');
      if (jsonStr != null) {
        try {
          final level = LevelModel.fromJson(jsonDecode(jsonStr));
          if (level.maskShape == expectedShape) {
            _cache[levelNumber] = level;
            return true;
          }
          _prefs!.remove('cached_level_$levelNumber');
        } catch (_) {}
      }
    }
    return false;
  }

  /// Trim in-memory cache, keeping levels around [currentLevel].
  void trimCache(int currentLevel) {
    final keys = _cache.keys.toList();
    for (final key in keys) {
      if (key < currentLevel - 5 || key > currentLevel + 15) {
        _cache.remove(key);
      }
    }
  }

  void _saveToDisk(int levelNumber, LevelModel level) {
    if (_prefs == null) return;
    try {
      _prefs!.setString('cached_level_$levelNumber', jsonEncode(level.toJson()));
    } catch (e) {
      debugPrint('Error saving level to disk: $e');
    }
  }

  static int get totalLevels => 2000;
}
