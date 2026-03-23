import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

/// TaskProvider = state manager for all task-related UI.
///
/// Screens DO NOT talk to Firestore directly.
/// They call this provider instead.
class TaskProvider extends ChangeNotifier {
  final FirestoreService _dbService = FirestoreService();

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
      final inserted = await _dbService.insertTask(task);

      _tasks.add(inserted);
      _sortTasks();
      notifyListeners();

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
      await _dbService.updateTask(task);

      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = task;
        _sortTasks();
        notifyListeners();

        // Re-schedule notification
        if (task.dueDate != null && task.id != null) {
          await NotificationService()
              .cancelNotification(task.id.hashCode);

          await NotificationService().scheduleTaskReminder(task);
        }
      }
    } catch (e) {
      debugPrint('Error updating task: $e');
    }
  }

  /// Toggle complete/incomplete
  Future<void> toggleCompletion(Task task) async {
    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
    );
    await updateTask(updated);
  }

  /// Delete task
  Future<void> deleteTask(String id) async {
    try {
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