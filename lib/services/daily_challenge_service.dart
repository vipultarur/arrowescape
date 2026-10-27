import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/level.dart';
import '../data/level_generator/level_generator_v2.dart';
import 'notification_service.dart';

class DailyChallengeService extends ChangeNotifier {
  static final DailyChallengeService instance =
      DailyChallengeService._internal();
  factory DailyChallengeService() => instance;
  DailyChallengeService._internal();

  SharedPreferences? _prefs;
  final Map<String, bool> _completedDates = {};
  final Map<String, LevelModel> _levelCache = {};
  final Map<String, String> _dailyStates = {};

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _levelCache.clear();
    _loadCompletedDates();
    await _scheduleBackgroundReminders();
  }

  Future<void> _scheduleBackgroundReminders() async {
    final today = DateTime.now();
    final completedToday = isDateCompleted(today);
    await NotificationService.instance.scheduleDailyChallengeReminders(
      isCompletedToday: completedToday,
    );
  }

  void _loadCompletedDates() {
    if (_prefs == null) return;
    final keys = _prefs!.getKeys();
    for (final key in keys) {
      if (key.startsWith('daily_completed_')) {
        final dateStr = key.replaceFirst('daily_completed_', '');
        _completedDates[dateStr] = _prefs!.getBool(key) ?? false;
      }
    }
    notifyListeners();
  }

  String formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  bool isDateCompleted(DateTime date) {
    final key = formatDateKey(date);
    return _completedDates[key] ?? false;
  }

  Future<void> markDateCompleted(DateTime date) async {
    final key = formatDateKey(date);
    _completedDates[key] = true;
    if (_prefs != null) {
      await _prefs!.setBool('daily_completed_$key', true);
    }
    // Also clear any saved in-progress state since completed
    await clearDailyState(date);

    // Trigger local push notification for completion!
    await NotificationService.instance.showCompletedNotification();
    await NotificationService.instance.scheduleDailyChallengeReminders(
      isCompletedToday: true,
    );

    notifyListeners();
  }

  /// Pre-generates today's daily challenge level in the background on app startup
  Future<void> preGenerateTodayLevel(dynamic repository) async {
    final today = DateTime.now();
    final key = formatDateKey(today);
    if (_levelCache.containsKey(key)) return;

    try {
      final level = await getLevelForDateAsync(today, repository);
      _levelCache[key] = level;
      debugPrint('DailyChallengeService: Pre-generated today level ($key) successfully');
    } catch (e) {
      debugPrint('DailyChallengeService: Error pre-generating today level: $e');
    }
  }

  /// Saves the user's in-progress playing state for a specific date
  Future<void> saveDailyState(DateTime date, Map<String, dynamic> stateData) async {
    final key = formatDateKey(date);
    final encoded = jsonEncode(stateData);
    _dailyStates[key] = encoded;
    if (_prefs != null) {
      await _prefs!.setString('daily_state_$key', encoded);
    }
  }

  /// Returns the saved in-progress playing state for a specific date (if any)
  Map<String, dynamic>? getDailyState(DateTime date) {
    final key = formatDateKey(date);
    String? raw = _dailyStates[key];
    if (raw == null && _prefs != null) {
      raw = _prefs!.getString('daily_state_$key');
      if (raw != null) _dailyStates[key] = raw;
    }
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Clears the saved in-progress playing state for a specific date
  Future<void> clearDailyState(DateTime date) async {
    final key = formatDateKey(date);
    _dailyStates.remove(key);
    if (_prefs != null) {
      await _prefs!.remove('daily_state_$key');
    }
  }

  /// Returns progress ratio (0.0 to 1.0) for a date. Returns 1.0 if completed.
  double getDateProgress(DateTime date) {
    if (isDateCompleted(date)) return 1.0;
    final state = getDailyState(date);
    if (state == null) return 0.0;
    final cleared = (state['clearedArrowIds'] as List<dynamic>?)?.length ?? 0;
    final total = (state['totalArrows'] as int?) ?? 0;
    if (total <= 0) return 0.0;
    return (cleared / total).clamp(0.0, 1.0);
  }

  int getCompletedCountForMonth(int year, int month) {
    int count = 0;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(year, month, d);
      if (isDateCompleted(date)) {
        count++;
      }
    }
    return count;
  }

  /// Returns difficulty title ("Hard" or "Super Hard") for a specific date
  String getDifficultyForDate(DateTime date) {
    // Alternate or use day formula
    return (date.day % 2 == 0) ? 'Super Hard' : 'Hard';
  }

  /// Returns deterministic level number in range 1..100 pre-compiled in assets/levels.bin
  int getLevelNumberForDate(DateTime date) {
    final int seed = date.year * 10000 + date.month * 100 + date.day;
    if (date.day % 3 == 0) {
      return 70 + (seed % 30); // 70..99 (Super Hard)
    } else if (date.day % 2 == 0) {
      return 40 + (seed % 30); // 40..69 (Hard)
    } else {
      return 20 + (seed % 20); // 20..39 (Normal)
    }
  }

  /// Generates or maps a specialized LevelModel for a date (async)
  Future<LevelModel> getLevelForDateAsync(DateTime date, dynamic repository) async {
    return getLevelForDate(date, repository);
  }

  /// Generates or maps a specialized LevelModel for a date
  LevelModel getLevelForDate(DateTime date, [dynamic repository]) {
    final key = formatDateKey(date);
    if (_levelCache.containsKey(key)) {
      return _levelCache[key]!;
    }

    final levelNum = getLevelNumberForDate(date);

    LevelModel level;
    if (repository != null) {
      try {
        level = repository.getLevel(levelNum);
        _levelCache[key] = level;
        return level;
      } catch (e) {
        debugPrint('Error getting level $levelNum from repository: $e');
      }
    }
    level = LevelGeneratorV2.generateLevel(levelNum);
    _levelCache[key] = level;
    return level;
  }

  /// Check & send reminder notifications
  Future<void> checkNotificationsForToday() async {
    final today = DateTime.now();
    final completed = isDateCompleted(today);

    if (!completed) {
      final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
      final monthCompleted = getCompletedCountForMonth(today.year, today.month);

      if (monthCompleted >= (daysInMonth / 2).floor()) {
        await NotificationService.instance.showHalfwayNotification();
      } else {
        await NotificationService.instance.showNotStartedNotification();
      }
    }
  }
}
