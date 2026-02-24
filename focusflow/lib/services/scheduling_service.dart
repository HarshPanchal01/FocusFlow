import '../models/task.dart';
import '../models/session.dart';
import '../models/suggestion.dart';
import 'database_service.dart';

/// Service that analyzes session patterns and generates adaptive scheduling suggestions.
/// 
/// Uses simple clustering/pattern detection to identify focus windows:
/// - Groups sessions by time of day and day of week
/// - Calculates completion rates and average interruptions per time slot
/// - Identifies high-focus periods (high completion, low interruptions)
/// - Generates suggestions based on task metadata and focus patterns
class SchedulingService {
  final DatabaseService _dbService = DatabaseService();

  /// Analyze sessions from the last N days to identify focus patterns
  Future<Map<String, FocusWindow>> analyzeFocusPatterns({int daysToAnalyze = 14}) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: daysToAnalyze));
    
    final sessions = await _dbService.getSessionsForRange(startDate, now);
    
    // Group sessions by hour of day (0-23) and day of week (1-7)
    final Map<String, List<Session>> groupedSessions = {};
    
    for (final session in sessions) {
      final hour = session.startTime.hour;
      final weekday = session.startTime.weekday;
      final key = '$weekday-$hour';
      
      groupedSessions.putIfAbsent(key, () => []).add(session);
    }
    
    // Calculate focus metrics for each time slot
    final Map<String, FocusWindow> focusWindows = {};
    
    for (final entry in groupedSessions.entries) {
      final sessions = entry.value;
      if (sessions.isEmpty) continue;
      
      final completedCount = sessions.where((s) => s.isCompleted).length;
      final completionRate = completedCount / sessions.length;
      
      final totalInterruptions = sessions.fold<int>(
        0,
        (sum, s) => sum + s.interruptionCount,
      );
      final avgInterruptions = totalInterruptions / sessions.length;
      
      final totalDuration = sessions.fold<int>(
        0,
        (sum, s) => sum + s.duration,
      );
      final avgDuration = totalDuration / sessions.length;
      
      // Calculate focus score (higher = better focus window)
      // Completion rate weighted 50%, low interruptions 30%, duration 20%
      final focusScore = (completionRate * 0.5) +
          ((1.0 - (avgInterruptions / 10.0).clamp(0.0, 1.0)) * 0.3) +
          ((avgDuration / 3600.0).clamp(0.0, 1.0) * 0.2);
      
      final parts = entry.key.split('-');
      final weekday = int.parse(parts[0]);
      final hour = int.parse(parts[1]);
      
      focusWindows[entry.key] = FocusWindow(
        weekday: weekday,
        hour: hour,
        completionRate: completionRate,
        avgInterruptions: avgInterruptions,
        avgDuration: avgDuration,
        focusScore: focusScore,
        sessionCount: sessions.length,
      );
    }
    
    return focusWindows;
  }

  /// Generate scheduling suggestions for incomplete tasks
  Future<List<Suggestion>> generateSuggestions({
    List<Task>? tasks,
    int daysAhead = 7,
  }) async {
    // Get incomplete tasks if not provided
    final incompleteTasks = tasks ?? 
        (await _dbService.getTasks(isCompleted: false));
    
    if (incompleteTasks.isEmpty) return [];
    
    // Analyze focus patterns
    final focusWindows = await analyzeFocusPatterns();
    
    // Get today's date
    final now = DateTime.now();
    final suggestions = <Suggestion>[];
    
    for (final task in incompleteTasks) {
      // Skip if task has no due date and is low priority
      if (task.dueDate == null && task.priority == Priority.low) {
        continue;
      }
      
      // Determine task type
      final isHeavyTask = task.priority == Priority.high || 
                         task.durationMinutes >= 60;
      final isUrgent = task.dueDate != null && 
                      task.dueDate!.difference(now).inDays <= 1;
      
      // Find best time slot for this task
      DateTime? bestStartTime;
      SuggestionType suggestionType;
      String reason;
      double confidence = 0.5;
      
      if (isUrgent) {
        // Urgent tasks: schedule as soon as possible
        bestStartTime = now.add(const Duration(hours: 1));
        suggestionType = SuggestionType.urgent;
        reason = 'Due date approaching';
        confidence = 0.9;
      } else if (isHeavyTask) {
        // Heavy tasks: find high-focus window
        bestStartTime = _findBestFocusWindow(
          focusWindows,
          task.durationMinutes,
          now,
          daysAhead,
          preferHighFocus: true,
        );
        suggestionType = SuggestionType.heavyTask;
        reason = 'High-focus window detected';
        confidence = bestStartTime != null ? 0.7 : 0.4;
      } else {
        // Light tasks: can schedule in lower-focus windows
        bestStartTime = _findBestFocusWindow(
          focusWindows,
          task.durationMinutes,
          now,
          daysAhead,
          preferHighFocus: false,
        );
        suggestionType = SuggestionType.lightTask;
        reason = 'Light task - flexible scheduling';
        confidence = 0.6;
      }
      
      // If no focus window found, use default scheduling
      if (bestStartTime == null) {
        bestStartTime = _getDefaultSuggestionTime(task, now);
        reason = 'Default scheduling (insufficient data)';
        confidence = 0.3;
      }
      
      final endTime = bestStartTime.add(Duration(minutes: task.durationMinutes));
      
      suggestions.add(Suggestion(
        task: task,
        suggestedStartTime: bestStartTime,
        suggestedEndTime: endTime,
        type: suggestionType,
        reason: reason,
        confidence: confidence,
      ));
    }
    
    // Sort by priority and due date
    suggestions.sort((a, b) {
      // Urgent first
      if (a.type == SuggestionType.urgent && 
          b.type != SuggestionType.urgent) return -1;
      if (b.type == SuggestionType.urgent && 
          a.type != SuggestionType.urgent) return 1;
      
      // Then by priority
      final priorityDiff = b.task.priority.index.compareTo(a.task.priority.index);
      if (priorityDiff != 0) return priorityDiff;
      
      // Then by due date
      if (a.task.dueDate != null && b.task.dueDate != null) {
        return a.task.dueDate!.compareTo(b.task.dueDate!);
      }
      if (a.task.dueDate != null) return -1;
      if (b.task.dueDate != null) return 1;
      
      return 0;
    });
    
    return suggestions;
  }

  /// Find the best focus window for a task
  DateTime? _findBestFocusWindow(
    Map<String, FocusWindow> focusWindows,
    int taskDurationMinutes,
    DateTime now,
    int daysAhead, {
    required bool preferHighFocus,
  }) {
    if (focusWindows.isEmpty) return null;
    
    // Filter windows by preference
    final candidateWindows = focusWindows.values.where((window) {
      if (preferHighFocus) {
        return window.focusScore >= 0.6 && window.completionRate >= 0.7;
      } else {
        return window.focusScore >= 0.3;
      }
    }).toList();
    
    if (candidateWindows.isEmpty) return null;
    
    // Sort by focus score
    candidateWindows.sort((a, b) => 
        preferHighFocus 
            ? b.focusScore.compareTo(a.focusScore)
            : a.focusScore.compareTo(b.focusScore));
    
    // Find the earliest available window in the next N days
    for (int dayOffset = 0; dayOffset < daysAhead; dayOffset++) {
      final candidateDate = now.add(Duration(days: dayOffset));
      
      for (final window in candidateWindows) {
        // Check if this window matches today's weekday
        if (candidateDate.weekday == window.weekday) {
          final candidateTime = DateTime(
            candidateDate.year,
            candidateDate.month,
            candidateDate.day,
            window.hour,
          );
          
          // Make sure it's in the future
          if (candidateTime.isAfter(now)) {
            return candidateTime;
          }
        }
      }
    }
    
    return null;
  }

  /// Get default suggestion time when no focus pattern is available
  DateTime _getDefaultSuggestionTime(Task task, DateTime now) {
    // Default: schedule high priority tasks in morning (9 AM)
    // Medium priority: afternoon (2 PM)
    // Low priority: evening (6 PM)
    int hour;
    switch (task.priority) {
      case Priority.high:
        hour = 9;
        break;
      case Priority.medium:
        hour = 14;
        break;
      case Priority.low:
        hour = 18;
        break;
    }
    
    // If due date is today, schedule for next hour
    if (task.dueDate != null && 
        task.dueDate!.day == now.day &&
        task.dueDate!.month == now.month &&
        task.dueDate!.year == now.year) {
      return now.add(const Duration(hours: 1));
    }
    
    // Otherwise, schedule for today at the preferred hour, or tomorrow if past that hour
    final suggestedDate = DateTime(now.year, now.month, now.day, hour);
    if (suggestedDate.isAfter(now)) {
      return suggestedDate;
    } else {
      return suggestedDate.add(const Duration(days: 1));
    }
  }
}

/// Represents a focus window (time slot with focus metrics)
class FocusWindow {
  final int weekday; // 1=Monday, 7=Sunday
  final int hour; // 0-23
  final double completionRate; // 0.0 to 1.0
  final double avgInterruptions;
  final double avgDuration; // in seconds
  final double focusScore; // 0.0 to 1.0 (higher = better)
  final int sessionCount;

  FocusWindow({
    required this.weekday,
    required this.hour,
    required this.completionRate,
    required this.avgInterruptions,
    required this.avgDuration,
    required this.focusScore,
    required this.sessionCount,
  });
}