import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/data_sync_service.dart';
import '../services/notification_service.dart';
import '../utils/haptic_utils.dart';
import '../utils/input_sanitizer.dart';

/// TaskProvider = state manager for all task-related UI.
///
/// Screens DO NOT talk to Firestore directly.
/// They call this provider instead.
class TaskProvider extends ChangeNotifier {
  final DataSyncService _dbService = DataSyncService();

  List<Task> _tasks = [];
  bool _isLoading = false;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;

  /// Derived lists for UI
  List<Task> get incompleteTasks =>
      _tasks.where((t) => !t.isCompleted).toList();

  List<Task> get completedTasks =>
      _tasks.where((t) => t.isCompleted).toList();

  /// Group tasks by priority (used in UI sections)
  Map<Priority, List<Task>> get tasksByPriority {
    final map = <Priority, List<Task>>{
      Priority.high: [],
      Priority.medium: [],
      Priority.low: [],
    };

    for (final task in incompleteTasks) {
      map[task.priority]!.add(task);
    }

    return map;
  }

  /// Load all tasks from Firestore
  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _tasks = await _dbService.getTasks();

      // Schedule reminders for active tasks
      for (final task in _tasks) {
        if (task.dueDate != null && !task.isCompleted) {
          NotificationService()
              .scheduleTaskReminder(task)
              .catchError((e) {
            debugPrint('Error scheduling reminder for ${task.id}: $e');
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add new task
  Future<void> addTask(Task task) async {
    try {
      // Sanitize user inputs before saving
      final sanitizedTask = task.copyWith(
        title: InputSanitizer.sanitizeTitle(task.title),
        description: InputSanitizer.sanitizeDescription(task.description),
        category: InputSanitizer.sanitizeCategory(task.category),
      );

      final inserted = await _dbService.insertTask(sanitizedTask);

      _tasks.add(inserted);
      _sortTasks();
      notifyListeners();

      HapticUtils.successBuzz(); // Satisfying feedback on task creation

      // Schedule reminder if due date exists
      if (inserted.dueDate != null) {
        await NotificationService().scheduleTaskReminder(inserted);
      }
    } catch (e) {
      debugPrint('Error adding task: $e');
    }
  }

  /// Update existing task
  Future<void> updateTask(Task task) async {
    try {
      // Sanitize user inputs before saving
      final sanitizedTask = task.copyWith(
        title: InputSanitizer.sanitizeTitle(task.title),
        description: InputSanitizer.sanitizeDescription(task.description),
        category: InputSanitizer.sanitizeCategory(task.category),
      );

      await _dbService.updateTask(sanitizedTask);

      final index = _tasks.indexWhere((t) => t.id == sanitizedTask.id);
      if (index != -1) {
        _tasks[index] = sanitizedTask;
        _sortTasks();
        notifyListeners();

        // Re-schedule notification
        if (sanitizedTask.dueDate != null && sanitizedTask.id != null) {
          await NotificationService()
              .cancelNotification(sanitizedTask.id.hashCode);

          await NotificationService().scheduleTaskReminder(sanitizedTask);
        }
      }
    } catch (e) {
      debugPrint('Error updating task: $e');
    }
  }

  /// Toggle complete/incomplete
  Future<void> toggleCompletion(Task task) async {
    HapticUtils.lightTap(); // Satisfying tick on checkbox
    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
    );
    await updateTask(updated);
  }

  /// Delete task
  Future<void> deleteTask(String id) async {
    try {
      HapticUtils.heavyTap(); // Weighty feel for destructive action
      await _dbService.deleteTask(id);

      _tasks.removeWhere((t) => t.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }

  /// Remove all completed tasks
  Future<void> clearCompleted() async {
    try {
      await _dbService.deleteCompletedTasks();

      _tasks.removeWhere((t) => t.isCompleted);
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing completed: $e');
    }
  }

  /// Internal sorting logic for UI consistency
  void _sortTasks() {
    _tasks.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }

      final priorityCompare =
          b.priority.index.compareTo(a.priority.index);
      if (priorityCompare != 0) return priorityCompare;

      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;

      return a.dueDate!.compareTo(b.dueDate!);
    });
  }
}