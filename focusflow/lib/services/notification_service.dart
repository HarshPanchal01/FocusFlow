import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart' as task_model;
import '../providers/timer_provider.dart';

/// NotificationService
///
/// Handles:
/// - Task reminders
/// - Focus session completion alerts
/// - Notification suppression during focus
///
/// IMPORTANT:
/// Firestore uses String IDs → notifications need int IDs
/// → we convert using task.id.hashCode
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  TimerProvider? _timerProvider;

  // =============================================================
  // INITIALIZATION
  // =============================================================

  /// Initialize notification plugin + timezone
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz_data.initializeTimeZones();

      debugPrint('Device timezone: ${DateTime.now().timeZoneName}');
      debugPrint('Timezone test: ${tz.TZDateTime.now(tz.local)}');

      // Request Android permissions
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('Notification permission granted: $granted');
      }

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final didInitialize = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (didInitialize == true) {
        _isInitialized = true;
        await _createNotificationChannels();
        debugPrint('✅ Notifications initialized');
      }
    } catch (e) {
      debugPrint('❌ Notification init error: $e');
    }
  }

  /// Create Android channels
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'task_reminders',
        'Task Reminders',
        description: 'Upcoming tasks',
        importance: Importance.defaultImportance,
      ),
    );

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'focus_sessions',
        'Focus Sessions',
        description: 'Focus completion alerts',
        importance: Importance.defaultImportance,
      ),
    );

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'general',
        'General Notifications',
        importance: Importance.defaultImportance,
      ),
    );
  }

  /// Set timer provider (used for focus suppression logic)
  void setTimerProvider(TimerProvider? provider) {
    _timerProvider = provider;
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  // =============================================================
  // SETTINGS + SUPPRESSION
  // =============================================================

  /// Should we suppress notifications (during focus session)
  Future<bool> _shouldSuppressNotification() async {
    if (_timerProvider?.isSessionActive == true) {
      final prefs = await SharedPreferences.getInstance();
      final focusMode = prefs.getInt('focusMode') ?? 1;

      // Deep (0) → always suppress
      if (focusMode == 0) return true;

      // Balanced (1) → suppress during focus
      return focusMode == 1;
    }

    return false;
  }

  /// Check if a specific notification type is enabled
  Future<bool> _isNotificationEnabled(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true;
  }

  // =============================================================
  // TASK REMINDERS
  // =============================================================

  Future<void> scheduleTaskReminder(task_model.Task task) async {
    if (!_isInitialized) await initialize();

    if (!await _isNotificationEnabled('taskReminders')) return;
    if (await _shouldSuppressNotification()) return;
    if (task.dueDate == null) return;

    final now = DateTime.now();
    final dueDate = task.dueDate!;

    if (dueDate.isBefore(now)) return;

    /// 🔥 CRITICAL FIX:
    /// Firestore ID (String) → convert to int for notification
    final notificationId =
        (task.id ?? DateTime.now().toString()).hashCode;

    final reminderTime = dueDate.subtract(const Duration(hours: 1));

    final scheduleTime =
        reminderTime.isBefore(now.add(const Duration(minutes: 2)))
            ? now.add(const Duration(minutes: 2))
            : reminderTime;

    final androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Task Reminders',
      channelDescription: 'Upcoming tasks',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      final tzTime = tz.TZDateTime.from(scheduleTime, tz.local);

      await _notifications.zonedSchedule(
        notificationId,
        'Task Reminder',
        '${task.title} is due soon',
        tzTime,
        details,
        payload: 'task_${task.id}',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('✅ Scheduled: ${task.title}');
      debugPrint('   Notification ID: $notificationId');
    } catch (e) {
      debugPrint('❌ Scheduling error: $e');
    }
  }

  // =============================================================
  // FOCUS SESSION COMPLETE
  // =============================================================

  Future<void> scheduleFocusSessionComplete(DateTime completionTime) async {
    if (!_isInitialized) await initialize();

    if (!await _isNotificationEnabled('focusSessionAlerts')) return;

    final androidDetails = AndroidNotificationDetails(
      'focus_sessions',
      'Focus Sessions',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'Focus Session Complete',
      'Great job! Take a break.',
      details,
    );
  }

  // =============================================================
  // GENERIC NOTIFICATIONS
  // =============================================================

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();
    if (await _shouldSuppressNotification()) return;

    final androidDetails = AndroidNotificationDetails(
      'general',
      'General Notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // =============================================================
  // CANCEL / DEBUG
  // =============================================================

  /// Cancel a single notification (pass hashCode ID)
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Reschedule all task reminders (used after timezone changes/debug)
  Future<void> rescheduleAllTaskReminders(
      List<task_model.Task> tasks) async {
    for (final task in tasks) {
      if (task.id != null) {
        await cancelNotification(task.id.hashCode);
      }
    }

    for (final task in tasks) {
      if (task.dueDate != null && !task.isCompleted) {
        await scheduleTaskReminder(task);
      }
    }
  }
}