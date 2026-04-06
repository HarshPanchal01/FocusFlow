import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/session.dart';
import '../services/firestore_service.dart';
import '../services/ml_service.dart';
import '../services/notification_service.dart';

/// TimerProvider manages focus session state and lifecycle.
///
/// Session flow:
///   1. User selects a task → timer auto-sets to task duration
///   2. User starts timer → session becomes active
///   3. During session: pause/resume, log interruptions (manual + auto)
///   4. Session ends (completed or stopped early)
///   5. Rating dialog shown → user rates focus quality 1-5
///   6. Session saved to Firestore with rating
///   7. ML service extracts focus pattern and saves it
///
/// FIX from midterm: Now saves to Firestore (was incorrectly using SQLite
/// while everything else had migrated to Firestore)
class TimerProvider extends ChangeNotifier {
  final FirestoreService _dbService = FirestoreService();
  final MLService _mlService = MLService();

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

  void startTimer() {
    if (_totalSeconds <= 0) return;

    _isRunning = true;
    _isSessionActive = true;
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
    notifyListeners();
  }

  void resumeTimer() {
    if (!_isSessionActive || _secondsLeft <= 0) return;
    startTimer();
  }

  /// Stop session early — still saves data and asks for rating.
  void stopSession() {
    _endSession(completed: false);
  }

  /// Timer finished naturally.
  void _completeSession() {
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

    final now = DateTime.now();
    final timeLabel =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    _interruptions.add({'type': type, 'time': timeLabel});
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
