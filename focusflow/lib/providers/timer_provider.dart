import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/session.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class TimerProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  // Timer state
  Timer? _timer;
  int _secondsLeft = 0;
  int _totalSeconds = 0;
  bool _isRunning = false;
  bool _isSessionActive = false;
  
  // Selected task for the session
  Task? _selectedTask;

  // Interruption tracking
  List<Map<String, String>> _interruptions = [];  // List of {type, time} maps
  int get interruptionCount => _interruptions.length;
  List<Map<String, String>> get interruptions => _interruptions;

  // Getters
  int get secondsLeft => _secondsLeft;
  int get totalSeconds => _totalSeconds;
  bool get isRunning => _isRunning;
  bool get isSessionActive => _isSessionActive;
  Task? get selectedTask => _selectedTask;
  
  // Progress (0.0 to 1.0)
  double get progress {
    if (_totalSeconds == 0) return 0.0;
    return 1.0 - (_secondsLeft / _totalSeconds);
  }

  // Set the task to focus on
  // Also auto-sets the timer to match the task's estimated duration
  void selectTask(Task? task) {
    if (_isSessionActive) return; // Can't change task while running
    _selectedTask = task;

    // Auto-set timer to the task's duration so the user doesn't have to
    if (task != null && task.durationMinutes > 0) {
      final hours = task.durationMinutes ~/ 60;
      final minutes = task.durationMinutes % 60;
      setDuration(hours, minutes, 0);
    }

    notifyListeners();
  }

  // Initialize timer with specific duration
  void setDuration(int hours, int minutes, int seconds) {
    if (_isSessionActive) return;
    _totalSeconds = (hours * 3600) + (minutes * 60) + seconds;
    _secondsLeft = _totalSeconds;
    notifyListeners();
  }

  // Start the timer
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

  // Pause the timer
  void pauseTimer() {
    _isRunning = false;
    _timer?.cancel();
    notifyListeners();
  }

  // Resume the timer
  void resumeTimer() {
    if (!_isSessionActive || _secondsLeft <= 0) return;
    startTimer();
  }

  // Stop the session early (abandon or finish early)
  void stopSession() {
    _saveSession(completed: false);
    _resetState();
  }

  // Log an interruption during a focus session (manual or automatic)
  // type can be: "Manual", "Left App", "Phone Call", etc.
  void logInterruption(String type) {
    if (!_isSessionActive) return;

    final now = DateTime.now();
    final timeLabel =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    _interruptions.add({'type': type, 'time': timeLabel});
    notifyListeners();
  }

  // Timer finished naturally
  void _completeSession() {
    _saveSession(completed: true);
    _resetState();
    
    // Show completion notification immediately
    // Don't await to avoid blocking, but ensure it's called
    NotificationService().scheduleFocusSessionComplete(DateTime.now()).catchError((e) {
      debugPrint('Error showing completion notification: $e');
    });
  }

  // Save session to DB
  Future<void> _saveSession({required bool completed}) async {
    final session = Session(
      taskId: _selectedTask?.id,
      startTime: DateTime.now().subtract(Duration(seconds: _totalSeconds - _secondsLeft)),
      duration: _totalSeconds - _secondsLeft,
      isCompleted: completed,
      interruptionCount: _interruptions.length,
    );
    
    try {
      await _dbService.insertSession(session);
      debugPrint('Saved session to DB: ${session.toMap()}');
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  void _resetState() {
    _timer?.cancel();
    _isRunning = false;
    _isSessionActive = false;
    _interruptions = [];  // Clear interruptions for next session
    _secondsLeft = _totalSeconds; // Reset to initial duration or 0?
    // Let's reset to initial duration so they can go again easily, 
    // or we could reset to 25 mins default.
    // For now, keep the last set duration.
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
