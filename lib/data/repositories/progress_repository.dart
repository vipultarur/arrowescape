import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

import '../models/level.dart';
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../core/audio_manager.dart';
import '../../core/localization.dart';



class ProgressRepository extends ChangeNotifier {
  final SharedPreferences? _prefs;

  // State fields
  int _lives = AppConstants.maxLives;
  int _currentLevel = 1;
  int _highestUnlockedLevel = 1;
  int _totalScore = 0;
  int _coins = 0;

  // Streak
  int _streakDays = 0;
  DateTime? _lastPlayedDate;

  // Level results
  final Map<int, LevelResult> _levelResults = {};

  // Settings
  String _selectedLanguage = 'English';
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  String _bgMusicTrack = 'smooth_ambient.wav';
  bool _vibrationEnabled = true;
  AppThemeOption _themeOption = AppThemeOption.lightColor;
  bool _useColorArrows = true;

  // Hints & Scale Points
  int _hints = 2;
  int _scaleUses = 2;

  // 40x40 warning state
  bool _hasSeen40x40Warning = false;

  // Zoom hint state
  bool _hasSeenZoomHint = false;

  // Demo Mode
  bool _isDemoMode = false;

  // Passive Life Regeneration
  DateTime? _lastLifeRegenTime;
  static const Duration heartRegenInterval = Duration(minutes: 15);
  Timer? _regenTimer;

  // ── Getters ──────────────────────────────────────────────────────────────────
  bool get isDemoMode => _isDemoMode;
  int get lives {
    return _isDemoMode ? 999 : _lives;
  }
  int get maxLives => AppConstants.maxLives;
  int get currentLevel => _currentLevel;
  int get highestUnlockedLevel => _highestUnlockedLevel;
  int get totalScore => _totalScore;
  int get coins => _coins;
  int get hints => _isDemoMode ? 99 : _hints;
  int get scaleUses => _isDemoMode ? 99 : _scaleUses;
  int get streakDays => _streakDays;
  DateTime? get lastPlayedDate => _lastPlayedDate;
  bool get hasLives {
    return _isDemoMode ? true : _lives > 0;
  }
  bool get livesAreFull {
    return _isDemoMode ? true : _lives >= AppConstants.maxLives;
  }

  Duration? get timeUntilNextLife {
    if (_lives >= AppConstants.maxLives || _lastLifeRegenTime == null) return null;
    final elapsed = DateTime.now().difference(_lastLifeRegenTime!);
    final remaining = heartRegenInterval - Duration(seconds: elapsed.inSeconds % heartRegenInterval.inSeconds);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String get formattedTimeUntilNextLife {
    final remaining = timeUntilNextLife;
    if (remaining == null) return '';
    final mins = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String get selectedLanguage => _selectedLanguage;
  Locale get locale => AppLocalizations.getLocale(_selectedLanguage);
  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  String get bgMusicTrack => _bgMusicTrack;
  bool get vibrationEnabled => _vibrationEnabled;
  ThemeMode get themeMode => (_themeOption == AppThemeOption.darkMono || _themeOption == AppThemeOption.darkColor) ? ThemeMode.dark : ThemeMode.light;
  bool get useColorArrows => _themeOption == AppThemeOption.darkColor || _themeOption == AppThemeOption.lightColor;
  AppThemeOption get themeOption => _themeOption;
  bool get hasSeen40x40Warning => _hasSeen40x40Warning;
  bool get hasSeenZoomHint => _hasSeenZoomHint;

  Future<void> setLanguage(String language) async {
    if (_selectedLanguage == language) return;
    _selectedLanguage = language;
    if (_prefs != null) {
      await _prefs!.setString('selectedLanguage', language);
    }
    notifyListeners();
  }

  int getStarsForLevel(int level) => _levelResults[level]?.stars ?? 0;

  bool isLevelUnlocked(int level) => level <= _highestUnlockedLevel;

  void toggleDemoMode() {
    _isDemoMode = !_isDemoMode;
    notifyListeners();
  }

  bool isLevelCompleted(int level) => _levelResults.containsKey(level);

  ProgressRepository([this._prefs]) {
    _load();
    _startRegenTimer();
  }

  void _startRegenTimer() {
    _regenTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final oldLives = _lives;
      _checkLifeRegeneration();
      if (_lives != oldLives) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _regenTimer?.cancel();
    _regenTimer = null;
    super.dispose();
  }


  // ── Load / Save ──────────────────────────────────────────────────────────────

  void _load() {
    if (_prefs == null) return;
    try {
      _lives = _prefs!.getInt('lives') ?? AppConstants.maxLives;
      _currentLevel = _prefs!.getInt('currentLevel') ?? 1;
      _highestUnlockedLevel = _prefs!.getInt('highestUnlockedLevel') ?? 1;
      _totalScore = _prefs!.getInt('totalScore') ?? 0;
      _coins = _prefs!.getInt('coins') ?? 0;
      _streakDays = _prefs!.getInt('streakDays') ?? 0;

      _soundEnabled = _prefs!.getBool('soundEnabled') ?? true;
      _musicEnabled = _prefs!.getBool('musicEnabled') ?? true;
      _bgMusicTrack = _prefs!.getString('bgMusicTrack') ?? 'smooth_ambient.wav';
      _vibrationEnabled = _prefs!.getBool('vibrationEnabled') ?? true;
      _selectedLanguage = _prefs!.getString('selectedLanguage') ?? 'English';
      _hasSeen40x40Warning = _prefs!.getBool('hasSeen40x40Warning') ?? false;
      _hasSeenZoomHint = _prefs!.getBool('hasSeenZoomHint') ?? false;
      _hints = _prefs!.getInt('hints') ?? 2;
      _scaleUses = _prefs!.getInt('scaleUses') ?? 2;
      final themeStr = _prefs!.getString('themeOption') ?? 'lightColor';
      _themeOption = AppThemeOption.values.firstWhere(
        (e) => e.name == themeStr,
        orElse: () => AppThemeOption.lightColor,
      );
      _useColorArrows = _themeOption == AppThemeOption.darkColor || _themeOption == AppThemeOption.lightColor;

      // Synchronize to AppColors & AudioManager
      AppColors.updateTheme(_themeOption);
      AudioManager.instance.setSoundEnabled(_soundEnabled);
      AudioManager.instance.setMusicEnabled(_musicEnabled);
      AudioManager.instance.setBgTrack(_bgMusicTrack);

      final lastPlayedStr = _prefs!.getString('lastPlayedDate');
      if (lastPlayedStr != null) {
        _lastPlayedDate = DateTime.tryParse(lastPlayedStr);
      }

      final lastRegenStr = _prefs!.getString('lastLifeRegenTime');
      if (lastRegenStr != null) {
        _lastLifeRegenTime = DateTime.tryParse(lastRegenStr);
      }

      final resultsJson = _prefs!.getString('levelResults');
      if (resultsJson != null) {
        final Map<String, dynamic> map = jsonDecode(resultsJson);
        for (final entry in map.entries) {
          final level = int.tryParse(entry.key);
          if (level != null) {
            _levelResults[level] =
                LevelResult.fromJson(entry.value as Map<String, dynamic>);
          }
        }
      }

      // Check max completed level to ensure highestUnlockedLevel is accurate
      int maxCompleted = 0;
      for (final key in _levelResults.keys) {
        if (key > maxCompleted) maxCompleted = key;
      }
      if (maxCompleted + 1 > _highestUnlockedLevel) {
        _highestUnlockedLevel = maxCompleted + 1;
      }

      // Check streak and passive life regen
      _updateStreak();
      _checkLifeRegeneration();

      // Integrity validation: clamp loaded values to sane bounds
      _lives = _lives.clamp(0, AppConstants.maxLives);
      _coins = _coins.clamp(0, 999999);
      _hints = _hints.clamp(0, 999);
      _scaleUses = _scaleUses.clamp(0, 999);
      _streakDays = _streakDays.clamp(0, 3650);
      _currentLevel = _currentLevel.clamp(1, 2000);
      _highestUnlockedLevel = _highestUnlockedLevel.clamp(1, 2000);
      _totalScore = _totalScore.clamp(0, 99999999);
    } catch (e) {
      debugPrint('Error loading progress from SharedPreferences: $e');
    }
  }

  void _checkLifeRegeneration() {
    if (_lives >= AppConstants.maxLives) {
      if (_lastLifeRegenTime != null) {
        _lastLifeRegenTime = null;
        _prefs?.remove('lastLifeRegenTime');
      }
      return;
    }

    if (_lastLifeRegenTime == null) {
      _lastLifeRegenTime = DateTime.now();
      _prefs?.setString('lastLifeRegenTime', _lastLifeRegenTime!.toIso8601String());
      return;
    }

    final elapsed = DateTime.now().difference(_lastLifeRegenTime!);
    final regenerated = elapsed.inSeconds ~/ heartRegenInterval.inSeconds;
    if (regenerated > 0) {
      _lives = (_lives + regenerated).clamp(0, AppConstants.maxLives);
      if (_lives >= AppConstants.maxLives) {
        _lastLifeRegenTime = null;
        _prefs?.remove('lastLifeRegenTime');
      } else {
        final remainderSeconds = elapsed.inSeconds % heartRegenInterval.inSeconds;
        _lastLifeRegenTime = DateTime.now().subtract(Duration(seconds: remainderSeconds));
        _prefs?.setString('lastLifeRegenTime', _lastLifeRegenTime!.toIso8601String());
      }
      _save();
    }
  }

  Future<void> _save() async {
    if (_prefs == null) return;
    try {
      await Future.wait([
        _prefs!.setInt('lives', _lives),
        _prefs!.setInt('currentLevel', _currentLevel),
        _prefs!.setInt('highestUnlockedLevel', _highestUnlockedLevel),
        _prefs!.setInt('totalScore', _totalScore),
        _prefs!.setInt('coins', _coins),
        _prefs!.setInt('streakDays', _streakDays),
        _prefs!.setInt('hints', _hints),
        _prefs!.setInt('scaleUses', _scaleUses),
        if (_lastPlayedDate != null)
          _prefs!.setString('lastPlayedDate', _lastPlayedDate!.toIso8601String()),
        if (_lastLifeRegenTime != null)
          _prefs!.setString('lastLifeRegenTime', _lastLifeRegenTime!.toIso8601String())
        else
          _prefs!.remove('lastLifeRegenTime'),
      ]);
    } catch (e) {
      debugPrint('Error saving progress: $e');
    }

    // Save level results
    if (_prefs != null) {
      final Map<String, dynamic> resultsMap = {};
      for (final entry in _levelResults.entries) {
        resultsMap[entry.key.toString()] = entry.value.toJson();
      }
      await _prefs?.setString('levelResults', jsonEncode(resultsMap));
    }
  }

  // ── Lives System ────────────────────────────────────────────────────────────

  /// Deduct 1 life from the global pool (when player makes a wrong move or fails level).
  Future<void> deductLife({int amount = 1}) async {
    if (_isDemoMode) return;
    _lives = (_lives - amount).clamp(0, AppConstants.maxLives);
    if (_lives < AppConstants.maxLives && _lastLifeRegenTime == null) {
      _lastLifeRegenTime = DateTime.now();
      _prefs?.setString('lastLifeRegenTime', _lastLifeRegenTime!.toIso8601String());
    }
    await _save();
    notifyListeners();
  }

  /// Synchronize global lives count with gameplay state.
  Future<void> syncLives(int count) async {
    if (_isDemoMode) return;
    _lives = count.clamp(0, AppConstants.maxLives);
    if (_lives < AppConstants.maxLives && _lastLifeRegenTime == null) {
      _lastLifeRegenTime = DateTime.now();
      _prefs?.setString('lastLifeRegenTime', _lastLifeRegenTime!.toIso8601String());
    } else if (_lives >= AppConstants.maxLives) {
      _lastLifeRegenTime = null;
      _prefs?.remove('lastLifeRegenTime');
    }
    await _save();
    notifyListeners();
  }

  /// Restore lives to full or by specified amount.
  Future<void> restoreLives({int amount = AppConstants.maxLives}) async {
    _lives = (_lives + amount).clamp(0, AppConstants.maxLives);
    if (_lives >= AppConstants.maxLives) {
      _lastLifeRegenTime = null;
      _prefs?.remove('lastLifeRegenTime');
    }
    await _save();
    notifyListeners();
  }

  /// Reset lives to full — called when player restarts a level.
  Future<void> resetLivesToFull() async {
    await restoreLives(amount: AppConstants.maxLives);
  }

  // ── Streak ───────────────────────────────────────────────────────────────────

  void _updateStreak() {
    if (_lastPlayedDate == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastPlayed = DateTime(
      _lastPlayedDate!.year,
      _lastPlayedDate!.month,
      _lastPlayedDate!.day,
    );
    final diff = today.difference(lastPlayed).inDays;
    if (diff > 1) {
      // Streak broken
      _streakDays = 0;
      _save();
    }
  }

  Future<void> recordDailyPlay() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastPlayedDate != null) {
      final lastPlayed = DateTime(
        _lastPlayedDate!.year,
        _lastPlayedDate!.month,
        _lastPlayedDate!.day,
      );
      final diff = today.difference(lastPlayed).inDays;
      if (diff == 0) return; // Already recorded today
      if (diff == 1) {
        _streakDays++; // Consecutive day
      } else {
        _streakDays = 1; // Restart streak
      }
    } else {
      _streakDays = 1;
    }

    _lastPlayedDate = now;
    await _save();
    notifyListeners();
  }

  Future<void> protectStreak() async {
    // Called after watching a rewarded ad on streak break
    _lastPlayedDate = DateTime.now();
    await _save();
    notifyListeners();
  }

  /// Purchase 1 heart (life) for 15 coins (or [cost] coins).
  /// Returns true if purchase succeeded.
  Future<bool> buyHeart({int cost = AppConstants.heartCoinCost}) async {
    if (_coins >= cost && _lives < AppConstants.maxLives) {
      _coins -= cost;
      _lives = (_lives + 1).clamp(0, AppConstants.maxLives);
      if (_lives >= AppConstants.maxLives) {
        _lastLifeRegenTime = null;
        _prefs?.remove('lastLifeRegenTime');
      }
      await _save();
      notifyListeners();
      return true;
    }
    return false;
  }

  // ── Level Progress ────────────────────────────────────────────────────────────

  Future<void> recordLevelComplete(LevelResult result, {int? coinsEarned}) async {
    final existing = _levelResults[result.levelNumber];
    if (existing == null || result.stars > existing.stars) {
      _levelResults[result.levelNumber] = result;
    }
    _totalScore += result.score;
    final earned = coinsEarned ?? AppConstants.coinsForLevel(result.levelNumber);
    _coins += earned;
    _currentLevel = result.levelNumber + 1;
    if (_currentLevel > _highestUnlockedLevel) {
      _highestUnlockedLevel = _currentLevel;
    }
    await resetLivesToFull();
  }

  Future<void> setCurrentLevel(int level) async {
    if (!isLevelUnlocked(level)) return;
    _currentLevel = level;
    await _save();
    notifyListeners();
  }

  Future<void> addCoins(int amount) async {
    _coins += amount;
    await _save();
    notifyListeners();
    AudioManager.instance.playCoinCollect();
  }

  Future<void> useHint() async {
    if (_isDemoMode) return;
    if (_hints > 0) {
      _hints--;
      notifyListeners();
      await _save();
    }
  }

  Future<void> addHints(int amount) async {
    _hints += amount;
    notifyListeners();
    await _save();
  }

  Future<void> useScale() async {
    if (_isDemoMode) return;
    if (_scaleUses > 0) {
      _scaleUses--;
      notifyListeners();
      await _save();
    }
  }

  Future<void> addScaleUses(int amount) async {
    _scaleUses += amount;
    notifyListeners();
    await _save();
  }

  // ── Settings Setters ─────────────────────────────────────────────────────────

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    AudioManager.instance.setSoundEnabled(value);
    await _prefs?.setBool('soundEnabled', value);
    notifyListeners();
  }

  Future<void> setMusicEnabled(bool value) async {
    _musicEnabled = value;
    AudioManager.instance.setMusicEnabled(value);
    await _prefs?.setBool('musicEnabled', value);
    notifyListeners();
  }

  Future<void> setBgMusicTrack(String track) async {
    _bgMusicTrack = track;
    await AudioManager.instance.setBgTrack(track);
    await _prefs?.setString('bgMusicTrack', track);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    await _prefs?.setBool('vibrationEnabled', value);
    notifyListeners();
  }

  Future<void> setUseColorArrows(bool value) async {
    _useColorArrows = value;
    if (_themeOption == AppThemeOption.darkMono || _themeOption == AppThemeOption.darkColor) {
      _themeOption = value ? AppThemeOption.darkColor : AppThemeOption.darkMono;
    } else {
      _themeOption = value ? AppThemeOption.lightColor : AppThemeOption.lightMono;
    }
    AppColors.updateTheme(_themeOption);
    await _prefs?.setString('themeOption', _themeOption.name);
    notifyListeners();
  }

  Future<void> setThemeOption(AppThemeOption option) async {
    _themeOption = option;
    _useColorArrows = option == AppThemeOption.darkColor || option == AppThemeOption.lightColor;
    AppColors.updateTheme(_themeOption);
    await _prefs?.setString('themeOption', _themeOption.name);
    notifyListeners();
  }

  Future<void> setHasSeen40x40Warning(bool value) async {
    _hasSeen40x40Warning = value;
    await _prefs?.setBool('hasSeen40x40Warning', value);
    notifyListeners();
  }

  Future<void> setHasSeenZoomHint(bool value) async {
    _hasSeenZoomHint = value;
    await _prefs?.setBool('hasSeenZoomHint', value);
    notifyListeners();
  }

  // ── Star rating calculator ────────────────────────────────────────────────────
  static int calculateStars(int livesLost, int totalArrows, int movesUsed) {
    if (livesLost == 0) return 3;
    if (livesLost == 1) return 2;
    return 1;
  }
}
