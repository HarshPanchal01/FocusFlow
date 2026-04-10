import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import '../models/task.dart';
import '../models/session.dart';
import '../services/data_sync_service.dart';
import '../services/ml_service.dart';
import '../services/notification_service.dart';
import '../services/device_orientation_service.dart';
import '../services/phone_activity_service.dart';
import '../utils/haptic_utils.dart';

/// TimerProvider manages focus session state and lifecycle.
///
/// Session flow:
///   1. User selects a task → timer auto-sets to task duration
///   2. User starts timer → session becomes active
///   3. During session: pause/resume, log interruptions (manual + auto)
///   4. Session ends (completed or stopped early)
///   5. Rating dialog shown → user rates focus quality 1-5
///   6. Session saved to SQLite + Firestore with rating
///   7. ML service extracts focus pattern and saves it
///
/// Uses DataSyncService for offline-first behavior:
/// writes to SQLite first, then syncs to Firestore in background.
class TimerProvider extends ChangeNotifier {
  final DataSyncService _dbService = DataSyncService();
  final MLService _mlService = MLService();
  final DeviceOrientationService _orientationService = DeviceOrientationService();
  final PhoneActivityService _phoneActivity = PhoneActivityService.instance;

  // Timer state
  Timer? _timer;
  int _secondsLeft = 0;
  int _totalSeconds = 0;
  bool _isRunning = false;
  bool _isSessionActive = false;

  // Selected task for the session
  Task? _selectedTask;

  // Interruption tracking
  List<Map<String, String>> _interruptions = [];
  int get interruptionCount => _interruptions.length;
  List<Map<String, String>> get interruptions => _interruptions;

  // Post-session state: holds the session until the user rates it
  Session? _pendingSession;
  bool _isAwaitingRating = false;

  // Getters
  int get secondsLeft => _secondsLeft;
  int get totalSeconds => _totalSeconds;
  bool get isRunning => _isRunning;
  bool get isSessionActive => _isSessionActive;
  Task? get selectedTask => _selectedTask;
  bool get isAwaitingRating => _isAwaitingRating;

  // Progress (0.0 to 1.0)
  double get progress {
    if (_totalSeconds == 0) return 0.0;
    return 1.0 - (_secondsLeft / _totalSeconds);
  }

  // ════════════════════════════════════════════════════════════
  // TASK SELECTION
  // ════════════════════════════════════════════════════════════

  TimerProvider() {
    _orientationService.addListener(_onOrientationChanged);
  }

  void _onOrientationChanged() {
    if (!_isSessionActive || !_isRunning) return;

    final state = _orientationService.currentState;
    if (state == DeviceOrientationState.held) {
      // If the user picks up the phone during a session, we log an automatic interruption.
      // But we don't want to spam interruptions if they keep holding it, 
      // so we check the time of the last interruption.
      if (_interruptions.isEmpty || _timeSinceLastInterruption() > const Duration(minutes: 1)) {
        logInterruption('Picked Up Phone (Auto-Detected)');
      }
    }
  }

  Duration _timeSinceLastInterruption() {
    if (_interruptions.isEmpty) return const Duration(days: 99); // Safe large value
    return DateTime.now().difference(_lastAutoInterruptionTime ?? DateTime.fromMillisecondsSinceEpoch(0));
  }

  DateTime? _lastAutoInterruptionTime;

  /// When the screen was turned off (Android), used to avoid double-counting
  /// "Switched away" right after [screen_off].
  DateTime? _lastScreenOffAt;

  Timer? _inactiveDebounce;

  /// Select a task and auto-set timer to its estimated duration.
  void selectTask(Task? task) {
    if (_isSessionActive) return;
    _selectedTask = task;

    if (task != null && task.durationMinutes > 0) {
      final hours = task.durationMinutes ~/ 60;
      final minutes = task.durationMinutes % 60;
      setDuration(hours, minutes, 0);
    }

    notifyListeners();
  }

  /// Set timer duration manually.
  void setDuration(int hours, int minutes, int seconds) {
    if (_isSessionActive) return;
    _totalSeconds = (hours * 3600) + (minutes * 60) + seconds;
    _secondsLeft = _totalSeconds;
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════════
  // SESSION LIFECYCLE
  // ════════════════════════════════════════════════════════════

  /// Starts the countdown. Use [resume] only from [resumeTimer] so cooldown /
  /// screen-off debounce state is not cleared mid-session.
  void startTimer({bool resume = false}) {
    if (_totalSeconds <= 0) return;

    if (!resume) HapticUtils.mediumTap(); // Satisfying start feedback

    _isRunning = true;
    _isSessionActive = true;

    _orientationService.startMonitoring();
    if (!resume) {
      _lastAutoInterruptionTime = null;
      _lastScreenOffAt = null;
    }
    _phoneActivity.start(_onPhoneActivityEvent);
    notifyListeners();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        _secondsLeft--;
        notifyListeners();
      } else {
        _completeSession();
      }
    });
  }

  void pauseTimer() {
    _isRunning = false;
    _timer?.cancel();
    _orientationService.stopMonitoring();
    _phoneActivity.stop();
    _cancelInactiveDebounce();
    notifyListeners();
  }

  void resumeTimer() {
    if (!_isSessionActive || _secondsLeft <= 0) return;
    startTimer(resume: true);
  }

  /// Stop session early — still saves data and asks for rating.
  void stopSession() {
    _endSession(completed: false);
  }

  /// Timer finished naturally.
  void _completeSession() {
    HapticUtils.successBuzz(); // Celebration buzz on completion
    _endSession(completed: true);

    NotificationService().scheduleFocusSessionComplete(DateTime.now()).catchError((e) {
      debugPrint('Error showing completion notification: $e');
    });
  }

  /// Common end-of-session logic: creates the session object,
  /// enters the "awaiting rating" state so the UI can show the dialog.
  void _endSession({required bool completed}) {
    _timer?.cancel();
    _isRunning = false;
    _isSessionActive = false;
    _orientationService.stopMonitoring();
    _phoneActivity.stop();
    _cancelInactiveDebounce();

    // Create the session but don't save yet — wait for rating
    _pendingSession = Session(
      taskId: _selectedTask?.id,
      startTime: DateTime.now().subtract(
        Duration(seconds: _totalSeconds - _secondsLeft),
      ),
      duration: _totalSeconds - _secondsLeft,
      isCompleted: completed,
      interruptionCount: _interruptions.length,
      // selfRating will be set when submitRating is called
    );

    _isAwaitingRating = true;
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════════
  // POST-SESSION RATING + ML EXTRACTION
  // ════════════════════════════════════════════════════════════

  /// Called by the UI after the user picks a rating (1-5) or skips.
  /// Saves the session to Firestore and triggers ML feature extraction.
  Future<void> submitRating(int? rating) async {
    if (_pendingSession == null) return;
    HapticUtils.mediumTap(); // Feedback on rating submit

    // Apply the rating to the session
    final session = Session(
      taskId: _pendingSession!.taskId,
      startTime: _pendingSession!.startTime,
      duration: _pendingSession!.duration,
      isCompleted: _pendingSession!.isCompleted,
      interruptionCount: _pendingSession!.interruptionCount,
      selfRating: rating,
    );

    try {
      // Save session to Firestore
      final savedSession = await _dbService.insertSession(session);
      debugPrint('Session saved to Firestore: ${savedSession.id}');

      // Extract focus pattern and save it for ML clustering
      final pattern = _mlService.extractPattern(
        session: savedSession,
        task: _selectedTask,
        totalPlannedSeconds: _totalSeconds,
      );
      await _mlService.savePattern(pattern);

    } catch (e) {
      debugPrint('Error saving session/pattern: $e');
    }

    // Reset everything for next session
    _pendingSession = null;
    _isAwaitingRating = false;
    _interruptions = [];
    _secondsLeft = _totalSeconds;
    notifyListeners();
  }

  /// Skip rating entirely — still saves the session with null rating.
  Future<void> skipRating() async {
    await submitRating(null);
  }

  // ════════════════════════════════════════════════════════════
  // INTERRUPTION TRACKING
  // ════════════════════════════════════════════════════════════

  /// Log an interruption during a focus session.
  /// Types: "Left App", "Phone Call", "Someone Talked to Me", etc.
  void logInterruption(String type) {
    if (!_isSessionActive) return;

    // Haptic only for manual logs, not auto-detected
    if (type != 'Picked Up Phone (Auto-Detected)' && !_isAutoDetectedType(type)) {
      HapticUtils.lightTap();
    }

    if (type == 'Picked Up Phone (Auto-Detected)' || _isAutoDetectedType(type)) {
      _lastAutoInterruptionTime = DateTime.now();
    }

    final now = DateTime.now();
    final timeLabel =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    _interruptions.add({'type': type, 'time': timeLabel});
    notifyListeners();
  }

  /// App / phone lifecycle while a focus session is running (from [WidgetsBindingObserver]).
  void handleAppLifecycle(AppLifecycleState state) {
    if (!_isSessionActive || !_isRunning) return;

    switch (state) {
      case AppLifecycleState.inactive:
        _inactiveDebounce?.cancel();
        _inactiveDebounce = Timer(const Duration(milliseconds: 450), () {
          if (!_isSessionActive || !_isRunning) return;
          logInterruption(
            'App not focused (notifications, quick settings, or system)',
          );
        });
        break;
      case AppLifecycleState.paused:
        _inactiveDebounce?.cancel();
        _inactiveDebounce = null;
        if (_shouldLogSwitchedAwayFromApp()) {
          logInterruption('Switched away from app');
        }
        break;
      case AppLifecycleState.resumed:
        _inactiveDebounce?.cancel();
        _inactiveDebounce = null;
        break;
      default:
        break;
    }
  }

  void _onPhoneActivityEvent(String event) {
    if (!_isSessionActive || !_isRunning) return;

    switch (event) {
      case 'screen_off':
        _lastScreenOffAt = DateTime.now();
        _cancelInactiveDebounce();
        logInterruption('Screen turned off');
        break;
      case 'screen_on':
      case 'user_present':
        break;
    }
  }

  bool _shouldLogSwitchedAwayFromApp() {
    if (_lastScreenOffAt == null) return true;
    final dt = DateTime.now().difference(_lastScreenOffAt!);
    return dt >= const Duration(seconds: 2);
  }

  void _cancelInactiveDebounce() {
    _inactiveDebounce?.cancel();
    _inactiveDebounce = null;
  }

  bool _isAutoDetectedType(String type) {
    switch (type) {
      case 'Screen turned off':
      case 'Switched away from app':
      case 'App not focused (notifications, quick settings, or system)':
        return true;
      default:
        return false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cancelInactiveDebounce();
    _phoneActivity.stop();
    _orientationService.removeListener(_onOrientationChanged);
    _orientationService.dispose();
    super.dispose();
  }
}
