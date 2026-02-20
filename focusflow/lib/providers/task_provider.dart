import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../services/database_service.dart';
// =============================================================
// TASK PROVIDER (State Management)
// =============================================================
// This is the "middleman" between the UI screens and the database.
//
// How it works:
//   1. Screens call methods here (like addTask, deleteTask, etc.)
//   2. This provider talks to DatabaseService to save/load data
//   3. It holds the task list in memory so screens can display it
//   4. When data changes, it calls notifyListeners() which tells
//      all screens listening via Consumer<TaskProvider> to rebuild
//
// Why not just call the database directly from screens?
//   - Keeps the UI code clean (screens only handle display logic)
//   - One place to manage the task list state
//   - Multiple screens can share the same data without conflicts
//   - Makes it easy to add Firebase sync later without changing screens
// =============================================================

/// Holds and manages all the tasks. Screens ask this for tasks
/// instead of talking to the database directly.
class TaskProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  List<Task> _tasks = [];
  bool _isLoading = false;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;

  // Quick ways to get tasks filtered the way we need them
  List<Task> get incompleteTasks =>
      _tasks.where((t) => !t.isCompleted).toList();
  List<Task> get completedTasks =>
      _tasks.where((t) => t.isCompleted).toList();

  // Split incomplete tasks into groups by high, medium, or low priority
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

  // Get all tasks from the database
  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _tasks = await _dbService.getTasks(orderBy: 'priority DESC, dueDate ASC');
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a new task and save it to the database
  Future<void> addTask(Task task) async {
    try {
      final id = await _dbService.insertTask(task);
      // Get the actual task back from the database so it has the right ID
      final inserted = await _dbService.getTaskById(id);
      if (inserted != null) {
        _tasks.add(inserted);
        _sortTasks();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error adding task: $e');
    }
  }

  // Update a task's info in the database
  Future<void> updateTask(Task task) async {
    try {
      await _dbService.updateTask(task);
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = task;
        _sortTasks();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating task: $e');
    }
  }

  // Mark a task done or not done
  Future<void> toggleCompletion(Task task) async {
    final updated = task.copyWith(isCompleted: !task.isCompleted);
    await updateTask(updated);
  }

  // Remove a task from the database
  Future<void> deleteTask(int id) async {
    try {
      await _dbService.deleteTask(id);
      _tasks.removeWhere((t) => t.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }

  // Clean up all the tasks that are already done
  Future<void> clearCompleted() async {
    try {
      await _dbService.deleteCompletedTasks();
      _tasks.removeWhere((t) => t.isCompleted);
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing completed tasks: $e');
    }
  }

  // Put tasks in a sensible order
  void _sortTasks() {
    _tasks.sort((a, b) {
      // Show incomplete tasks first, then by priority (high first), then by due date
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      final priorityCompare = b.priority.index.compareTo(a.priority.index);
      if (priorityCompare != 0) return priorityCompare;
      // Push tasks without a due date to the bottom
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });
  }
}
