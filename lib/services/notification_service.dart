import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('Error initializing timezones: $e');
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notifications.initialize(initSettings);
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService initialization error: $e');
    }
  }

  Future<void> requestPermissions() async {
    try {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'daily_challenges',
      'Daily Challenges',
      channelDescription:
          'Notifications for daily challenge availability and completion',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(id, title, body, details);
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  /// Schedule a daily recurring notification even when the app is closed
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (!_initialized) await initialize();

    try {
      final location = tz.local;
      final now = tz.TZDateTime.now(location);
      var scheduledDate = tz.TZDateTime(
        location,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If the scheduled time has already passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        'daily_challenges',
        'Daily Challenges',
        channelDescription:
            'Notifications for daily challenge availability and completion',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
      );

      const iosDetails = DarwinNotificationDetails();

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('Scheduled background daily notification #$id at $hour:$minute for $scheduledDate');
    } catch (e) {
      debugPrint('Error scheduling daily notification: $e');
    }
  }

  /// Cancel a specific notification by ID
  Future<void> cancelNotification(int id) async {
    try {
      await _notifications.cancel(id);
    } catch (e) {
      debugPrint('Error canceling notification $id: $e');
    }
  }

  /// Schedule daily challenge background notifications (10:00 AM & 7:00 PM)
  Future<void> scheduleDailyChallengeReminders({required bool isCompletedToday}) async {
    if (isCompletedToday) {
      // Today is completed - cancel today's evening reminder
      await cancelNotification(102);

      // Schedule tomorrow morning at 10:00 AM
      await scheduleDailyNotification(
        id: 101,
        title: '🎯 Daily Challenge Ready!',
        body: 'Tomorrow\'s Hard puzzle is waiting! Play now to earn your star.',
        hour: 10,
        minute: 0,
      );
    } else {
      // Today is NOT completed - schedule 10:00 AM & 7:00 PM notifications
      await scheduleDailyNotification(
        id: 101,
        title: '🎯 Daily Challenge Ready!',
        body: 'Today\'s Hard puzzle is waiting! Play now to earn your star.',
        hour: 10,
        minute: 0,
      );

      await scheduleDailyNotification(
        id: 102,
        title: '🔥 Don\'t forget your Daily Challenge!',
        body: 'Finish today\'s puzzle before midnight to keep your streak!',
        hour: 19,
        minute: 0,
      );
    }
  }

  /// Triggered when daily challenge is available & not started
  Future<void> showNotStartedNotification() async {
    await showNotification(
      id: 101,
      title: '🎯 Daily Challenge Ready!',
      body: 'Today\'s Hard puzzle is waiting! Play now to earn your star.',
    );
  }

  /// Triggered when daily challenge is halfway completed
  Future<void> showHalfwayNotification() async {
    await showNotification(
      id: 102,
      title: '🔥 You\'re Halfway There!',
      body: 'Great progress on today\'s challenge! Finish it now to win.',
    );
  }

  /// Triggered when daily challenge is completed
  Future<void> showCompletedNotification() async {
    await showNotification(
      id: 103,
      title: '🎉 Daily Challenge Completed!',
      body: 'Awesome job! You earned your star for today\'s challenge.',
    );
  }

  // ── Shop Rewards Notifications ─────────────────────────────────────────────

  /// Schedule a notification for a specific future timestamp (e.g. when timer finishes)
  Future<void> scheduleShopRewardReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (!_initialized) await initialize();
    await requestPermissions();

    try {
      final location = tz.local;
      final tzScheduledDate = tz.TZDateTime.from(scheduledTime, location);

      if (tzScheduledDate.isBefore(tz.TZDateTime.now(location))) return;

      const androidDetails = AndroidNotificationDetails(
        'shop_rewards',
        'Shop Rewards',
        channelDescription:
            'Notifications for Daily Gift and Free Coins rewards availability',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
      );

      const iosDetails = DarwinNotificationDetails();

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await cancelNotification(id);

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('Scheduled shop reward notification #$id for $tzScheduledDate');
    } catch (e) {
      debugPrint('Error scheduling shop reward notification: $e');
    }
  }

  /// Schedule Daily Gift Push Notification (24 Hours)
  Future<void> scheduleDailyGiftReminder(DateTime claimableAt) async {
    await scheduleShopRewardReminder(
      id: 201,
      title: '🎁 Daily Gift Ready!',
      body: 'Your 50 Free Coins daily gift is ready to claim! Tap to get your coins now.',
      scheduledTime: claimableAt,
    );
  }

  /// Schedule Free Coins Push Notification (4 Hours)
  Future<void> scheduleFreeCoinsReminder(DateTime claimableAt) async {
    await scheduleShopRewardReminder(
      id: 202,
      title: '💰 Free Coins Available!',
      body: 'Your Free Coins offer is ready! Watch a short ad and claim 50 free coins now.',
      scheduledTime: claimableAt,
    );
  }
}
