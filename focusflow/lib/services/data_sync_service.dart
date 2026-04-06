import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';
import '../models/session.dart';
import '../models/focus_pattern.dart';
import 'database_service.dart';
import 'firestore_service.dart';
import 'connectivity_service.dart';

/// DataSyncService implements offline-first architecture:
///
///   WRITE: SQLite first (instant) → Firestore in background (when online)
///   READ:  SQLite (fast, always available)
///   SYNC:  On app launch, pull latest from Firestore → update SQLite
///
/// If there's no internet, everything still works via SQLite.
/// When connectivity returns, Firestore catches up automatically.
///
/// Architecture from proposal:
///   Mobile UI → SQLite (offline cache) → Firebase/Firestore (sync)
class DataSyncService {
  static final DataSyncService _instance = DataSyncService._internal();
  factory DataSyncService() => _instance;
  DataSyncService._internal();

  final DatabaseService _localDb = DatabaseService();
  final FirestoreService _cloudDb = FirestoreService();

  /// Whether the user is authenticated (needed for Firestore access)
  bool get _isAuthenticated => FirebaseAuth.instance.currentUser != null;

  /// Whether we should attempt cloud operations (online + authenticated)
  bool get _canReachCloud => _isAuthenticated && ConnectivityService().isOnline;

  // ════════════════════════════════════════════════════════════
  // SYNC ON STARTUP
  // ════════════════════════════════════════════════════════════

  /// Pull latest data from Firestore and update local SQLite cache.
  /// Called once on app startup after authentication.
  Future<void> syncFromCloud() async {
    if (!_isAuthenticated) {
      debugPrint('Sync: Skipping — no authenticated user');
      return;
    }

    try {
      debugPrint('Sync: Pulling data from Firestore...');

      // Sync tasks
      final cloudTasks = await _cloudDb.getTasks();
      await _localDb.replaceAllTasks(cloudTasks);
      debugPrint('Sync: ${cloudTasks.length} tasks synced to local');

      // Sync sessions
      final cloudSessions = await _cloudDb.getSessions();
      await _localDb.replaceAllSessions(cloudSessions);
      debugPrint('Sync: ${cloudSessions.length} sessions synced to local');

      // Sync focus patterns
      final cloudPatterns = await _cloudDb.getFocusPatterns();
      await _localDb.replaceAllPatterns(cloudPatterns);
      debugPrint('Sync: ${cloudPatterns.length} patterns synced to local');

      debugPrint('Sync: Complete');
    } catch (e) {
      debugPrint('Sync: Failed to pull from cloud (offline?) — $e');
      debugPrint('Sync: App will use local data');
    }
  }

  // ════════════════════════════════════════════════════════════
  // TASKS — write local first, then cloud
  // ════════════════════════════════════════════════════════════

  Future<Task> insertTask(Task task) async {
    Task savedTask;

    if (_canReachCloud) {
      try {
        savedTask = await _cloudDb.insertTask(task);
      } catch (e) {
        debugPrint('Sync: Cloud insert failed — $e');
        final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
        savedTask = task.copyWith(id: localId);
      }
    } else {
      // Offline — generate local ID, skip cloud entirely
      final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      savedTask = task.copyWith(id: localId);
      debugPrint('Sync: Offline — task saved locally as $localId');
    }

    await _localDb.insertTask(savedTask);
    return savedTask;
  }

  Future<List<Task>> getTasks() async {
    // Always read from local SQLite (fast, works offline)
    try {
      final localTasks = await _localDb.getTasks();
      if (localTasks.isNotEmpty) return localTasks;
    } catch (e) {
      debugPrint('Sync: Local read failed — $e');
    }

    // Fallback to cloud if local is empty and we're online (first launch)
    if (_canReachCloud) {
      try {
        return await _cloudDb.getTasks();
      } catch (e) {
        debugPrint('Sync: Cloud read also failed — $e');
      }
    }

    return [];
  }

  Future<void> updateTask(Task task) async {
    await _localDb.updateTask(task);
    if (_canReachCloud) {
      _tryCloud(() => _cloudDb.updateTask(task));
    }
  }

  Future<void> toggleTaskCompletion(String id, bool isCompleted) async {
    if (_canReachCloud) {
      _tryCloud(() => _cloudDb.toggleTaskCompletion(id, isCompleted));
    }
  }

  Future<void> deleteTask(String id) async {
    await _localDb.deleteTask(id);
    if (_canReachCloud) {
      _tryCloud(() => _cloudDb.deleteTask(id));
    }
  }

  Future<void> deleteCompletedTasks() async {
    await _localDb.deleteCompletedTasks();
    if (_canReachCloud) {
      _tryCloud(() => _cloudDb.deleteCompletedTasks());
    }
  }

  // ════════════════════════════════════════════════════════════
  // SESSIONS — write local first, then cloud
  // ════════════════════════════════════════════════════════════

  Future<Session> insertSession(Session session) async {
    Session savedSession;

    if (_canReachCloud) {
      try {
        savedSession = await _cloudDb.insertSession(session);
      } catch (e) {
        debugPrint('Sync: Cloud session insert failed — $e');
        final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
        savedSession = session.copyWith(id: localId);
      }
    } else {
      final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      savedSession = session.copyWith(id: localId);
      debugPrint('Sync: Offline — session saved locally');
    }

    await _localDb.insertSession(savedSession);
    return savedSession;
  }

  Future<List<Session>> getSessionsForRange(DateTime start, DateTime end) async {
    try {
      final local = await _localDb.getSessionsForRange(start, end);
      if (local.isNotEmpty) return local;
    } catch (e) {
      debugPrint('Sync: Local session read failed — $e');
    }

    if (_canReachCloud) {
      try {
        return await _cloudDb.getSessionsForRange(start, end);
      } catch (e) {
        debugPrint('Sync: Cloud session read also failed — $e');
      }
    }

    return [];
  }

  Future<List<Session>> getSessions() async {
    if (_canReachCloud) {
      try {
        return await _cloudDb.getSessions();
      } catch (e) {
        debugPrint('Sync: Cloud sessions read failed — $e');
      }
    }
    return [];
  }

  Future<void> updateSession(Session session) async {
    _tryCloud(() => _cloudDb.updateSession(session));
  }

  // ════════════════════════════════════════════════════════════
  // FOCUS PATTERNS — write local first, then cloud
  // ════════════════════════════════════════════════════════════

  Future<FocusPattern> insertFocusPattern(FocusPattern pattern) async {
    FocusPattern savedPattern;

    if (_canReachCloud) {
      try {
        savedPattern = await _cloudDb.insertFocusPattern(pattern);
      } catch (e) {
        debugPrint('Sync: Cloud pattern insert failed — $e');
        final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
        savedPattern = FocusPattern(
          id: localId,
          sessionId: pattern.sessionId,
          taskId: pattern.taskId,
          hourOfDay: pattern.hourOfDay,
          dayOfWeek: pattern.dayOfWeek,
          durationMinutes: pattern.durationMinutes,
          completionRate: pattern.completionRate,
          interruptionCount: pattern.interruptionCount,
          selfRating: pattern.selfRating,
          category: pattern.category,
          priority: pattern.priority,
          focusScore: pattern.focusScore,
        );
      }
    } else {
      final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      savedPattern = FocusPattern(
        id: localId,
        sessionId: pattern.sessionId,
        taskId: pattern.taskId,
        hourOfDay: pattern.hourOfDay,
        dayOfWeek: pattern.dayOfWeek,
        durationMinutes: pattern.durationMinutes,
        completionRate: pattern.completionRate,
        interruptionCount: pattern.interruptionCount,
        selfRating: pattern.selfRating,
        category: pattern.category,
        priority: pattern.priority,
        focusScore: pattern.focusScore,
      );
      debugPrint('Sync: Offline — pattern saved locally');
    }

    await _localDb.insertFocusPattern(savedPattern);
    return savedPattern;
  }

  Future<List<FocusPattern>> getFocusPatterns() async {
    try {
      final local = await _localDb.getFocusPatterns();
      if (local.isNotEmpty) return local;
    } catch (e) {
      debugPrint('Sync: Local pattern read failed — $e');
    }

    if (_canReachCloud) {
      try {
        return await _cloudDb.getFocusPatterns();
      } catch (e) {
        debugPrint('Sync: Cloud pattern read also failed — $e');
      }
    }

    return [];
  }

  Future<List<FocusPattern>> getRecentPatterns({int days = 30}) async {
    if (_canReachCloud) {
      try {
        return await _cloudDb.getRecentPatterns(days: days);
      } catch (e) {
        debugPrint('Sync: Cloud recent patterns failed — $e');
      }
    }
    return [];
  }

  Future<int> getTaskCount({bool? isCompleted}) async {
    if (_canReachCloud) {
      try {
        return await _cloudDb.getTaskCount(isCompleted: isCompleted);
      } catch (e) {
        debugPrint('Sync: Cloud task count failed — $e');
      }
    }
    return 0;
  }

  // ════════════════════════════════════════════════════════════
  // HELPER
  // ════════════════════════════════════════════════════════════

  /// Fire-and-forget cloud operation — doesn't block the UI.
  /// If it fails (offline), data is still safe in SQLite.
  void _tryCloud(Future<void> Function() operation) {
    if (!_canReachCloud) return;
    operation().catchError((e) {
      debugPrint('Sync: Background cloud operation failed — $e');
    });
  }
}
