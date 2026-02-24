import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart' as task_model;
import '../providers/timer_provider.dart';

/// Service for managing context-aware notifications.
/// 
/// Features:
/// - Suppresses notifications during active focus sessions
/// - Respects user notification preferences
/// - Schedules task reminders based on due dates
/// - Handles different focus modes (Deep/Balanced/Light)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  TimerProvider? _timerProvider;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone data
      tz_data.initializeTimeZones();
      
      // Get device's local timezone
      // The timezone package will use the system's local timezone by default
      // We don't need to explicitly set it - tz.local will use the system timezone
      final deviceTimeZone = DateTime.now().timeZoneName;
      debugPrint('Device timezone: $deviceTimeZone');
      
      // Verify timezone is working
      final testTime = tz.TZDateTime.now(tz.local);
      debugPrint('Current timezone-aware time: $testTime');

      // Request permissions (Android 13+)
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        // Request notification permission
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('Notification permission granted: $granted');
        
        if (granted == false) {
          debugPrint('Warning: Notification permission not granted');
        }
        
        // Note: Exact alarm permission is handled automatically by Android
        // We'll catch the error and fallback to approximate scheduling if needed
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
        debugPrint('✅ Notification service initialized: $didInitialize');
        
        // Create notification channels (Android)
        await _createNotificationChannels();
      } else {
        debugPrint('❌ Notification service failed to initialize');
      }
    } catch (e) {
      debugPrint('❌ Error initializing notification service: $e');
    }
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    try {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        // Task reminders channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'task_reminders',
            'Task Reminders',
            description: 'Notifications for upcoming task due dates',
            importance: Importance.defaultImportance,
          ),
        );
        
        // Focus sessions channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'focus_sessions',
            'Focus Sessions',
            description: 'Notifications for focus session completion',
            importance: Importance.low,
          ),
        );
        
        // General channel
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'general',
            'General Notifications',
            description: 'General app notifications',
            importance: Importance.defaultImportance,
          ),
        );
        
        debugPrint('✅ Notification channels created');
      }
    } catch (e) {
      debugPrint('❌ Error creating notification channels: $e');
    }
  }

  /// Set the timer provider to check focus session state
  void setTimerProvider(TimerProvider? provider) {
    _timerProvider = provider;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // TODO: Navigate to relevant screen based on payload
  }

  /// Check if notifications should be suppressed
  Future<bool> _shouldSuppressNotification() async {
    // Check if user is in an active focus session
    if (_timerProvider?.isSessionActive == true) {
      // Check focus mode setting
      final prefs = await SharedPreferences.getInstance();
      final focusMode = prefs.getInt('focusMode') ?? 1; // Default: Balanced
      
      // Deep Focus (0): Suppress all
      if (focusMode == 0) return true;
      
      // Balanced (1): Only suppress non-urgent
      // Light (2): Don't suppress
      // For now, we'll suppress in Balanced mode during focus
      return focusMode == 1;
    }
    
    return false;
  }

  /// Check if a specific notification type is enabled
  Future<bool> _isNotificationEnabled(String preferenceKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(preferenceKey) ?? true; // Default: enabled
  }

  /// Schedule a task reminder notification
  Future<void> scheduleTaskReminder(task_model.Task task) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // Check if task reminders are enabled
    if (!await _isNotificationEnabled('taskReminders')) {
      debugPrint('Task reminders disabled for task: ${task.title}');
      return;
    }
    
    // Check if we should suppress
    if (await _shouldSuppressNotification()) {
      debugPrint('Suppressing task reminder during focus session');
      return;
    }
    
    if (task.dueDate == null) {
      debugPrint('Task ${task.title} has no due date, skipping reminder');
      return;
    }
    
    final now = DateTime.now();
    final dueDate = task.dueDate!;
    
    // Don't schedule if already past due
    if (dueDate.isBefore(now)) {
      debugPrint('Task ${task.title} is already past due, skipping reminder');
      return;
    }
    
    // Schedule reminder 1 hour before due date
    final reminderTime = dueDate.subtract(const Duration(hours: 1));
    
    // If reminder time is in the past or too soon, schedule for 2 minutes from now (for testing)
    // In production, you might want to skip if reminder time is too far in the past
    final scheduleTime = reminderTime.isBefore(now.add(const Duration(minutes: 2)))
        ? now.add(const Duration(minutes: 2))
        : reminderTime;
    
    debugPrint('Task: ${task.title}');
    debugPrint('Due date: $dueDate');
    debugPrint('Reminder time (1hr before): $reminderTime');
    debugPrint('Scheduled time: $scheduleTime');
    debugPrint('Current time: $now');
    debugPrint('Time until notification: ${scheduleTime.difference(now).inMinutes} minutes');
    
    final androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Task Reminders',
      channelDescription: 'Notifications for upcoming task due dates',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      enableVibration: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    try {
      // Convert to timezone-aware datetime
      final tzScheduledTime = tz.TZDateTime.from(scheduleTime, tz.local);
      
      debugPrint('Timezone-aware scheduled time: $tzScheduledTime');
      
      // Try exact scheduling first, fallback to approximate if permission denied
      AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      
      try {
        await _notifications.zonedSchedule(
          task.id ?? 0,
          'Task Reminder',
          '${task.title} is due soon',
          tzScheduledTime,
          details,
          payload: 'task_${task.id}',
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
        
        debugPrint('✅ Scheduled reminder for task: ${task.title}');
        debugPrint('   Due: $dueDate');
        debugPrint('   Notification at: $scheduleTime (${scheduleTime.difference(now).inMinutes} min from now)');
        debugPrint('   Notification ID: ${task.id ?? 0}');
        debugPrint('   Schedule mode: exact');
      } catch (e) {
        // If exact alarm failed, try with approximate scheduling
        if (e.toString().contains('exact_alarms_not_permitted') || 
            e.toString().contains('exact_alarm')) {
          debugPrint('⚠️ Exact alarms not permitted, retrying with approximate scheduling...');
          try {
            await _notifications.zonedSchedule(
              task.id ?? 0,
              'Task Reminder',
              '${task.title} is due soon',
              tzScheduledTime,
              details,
              payload: 'task_${task.id}',
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            );
            debugPrint('✅ Scheduled with approximate timing (may be slightly delayed)');
            debugPrint('   Due: $dueDate');
            debugPrint('   Notification at: $scheduleTime (${scheduleTime.difference(now).inMinutes} min from now)');
            debugPrint('   Notification ID: ${task.id ?? 0}');
          } catch (retryError) {
            debugPrint('❌ Retry also failed: $retryError');
            debugPrint('   Stack trace: ${StackTrace.current}');
          }
        } else {
          debugPrint('❌ Error scheduling reminder for ${task.title}: $e');
          debugPrint('   Stack trace: ${StackTrace.current}');
        }
      }
    } catch (e) {
      debugPrint('❌ Unexpected error in scheduleTaskReminder: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
    }
  }

  /// Show a focus session completion notification immediately
  /// This notification bypasses suppression since it's the completion alert itself
  Future<void> scheduleFocusSessionComplete(DateTime completionTime) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // Check if focus session alerts are enabled
    if (!await _isNotificationEnabled('focusSessionAlerts')) {
      debugPrint('Focus session alerts disabled');
      return;
    }
    
    // Note: We don't check suppression here because this IS the completion notification
    // It should always show when a session completes
    
    // Show notification immediately instead of scheduling
    final androidDetails = AndroidNotificationDetails(
      'focus_sessions',
      'Focus Sessions',
      channelDescription: 'Notifications for focus session completion',
      importance: Importance.defaultImportance, // Changed from low to default so it's more visible
      priority: Priority.defaultPriority, // Changed from low to default
      playSound: true,
      enableVibration: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        'Focus Session Complete',
        'Great job! Take a break.',
        details,
        payload: 'focus_complete',
      );
      
      debugPrint('✅ Showed focus completion notification');
    } catch (e) {
      debugPrint('❌ Error showing focus completion notification: $e');
    }
  }

  /// Show an immediate notification (for testing or urgent alerts)
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // Check if we should suppress
    if (await _shouldSuppressNotification()) {
      debugPrint('Suppressing notification during focus session');
      return;
    }
    
    final androidDetails = AndroidNotificationDetails(
      'general',
      'General Notifications',
      channelDescription: 'General app notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    
    const iosDetails = DarwinNotificationDetails();
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        details,
        payload: payload,
      );
      debugPrint('✅ Showed notification: $title');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  /// Cancel a scheduled notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Cancel all task reminder notifications
  Future<void> cancelTaskReminders() async {
    // Note: This is a simplified approach
    // In production, you'd track notification IDs
    final prefs = await SharedPreferences.getInstance();
    final taskIds = prefs.getStringList('scheduled_task_ids') ?? [];
    
    for (final idStr in taskIds) {
      final id = int.tryParse(idStr);
      if (id != null) {
        await _notifications.cancel(id);
      }
    }
    
    await prefs.remove('scheduled_task_ids');
  }

  /// Get all pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Reschedule all task reminders (useful for debugging or after timezone changes)
  Future<void> rescheduleAllTaskReminders(List<task_model.Task> tasks) async {
    debugPrint('Rescheduling notifications for ${tasks.length} tasks');
    
    // Cancel all existing task notifications first
    for (final task in tasks) {
      if (task.id != null) {
        await cancelNotification(task.id!);
      }
    }
    
    // Schedule new notifications
    for (final task in tasks) {
      if (task.dueDate != null && !task.isCompleted) {
        await scheduleTaskReminder(task);
      }
    }
    
    // Show pending notifications for debugging
    final pending = await getPendingNotifications();
    debugPrint('Total pending notifications: ${pending.length}');
    for (final notif in pending) {
      debugPrint('  - ID: ${notif.id}, Title: ${notif.title}, Scheduled: ${notif.body}');
    }
  }
}