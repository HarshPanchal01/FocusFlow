import '../models/session.dart';
import '../models/suggestion.dart';
import 'data_sync_service.dart';
import 'ml_service.dart';

/// Schedule overlap with another suggested task.
class ScheduleConflict {
  final String otherTaskTitle;
  final String detail;

  ScheduleConflict({required this.otherTaskTitle, required this.detail});
}

/// Aggregated analytics for a scheduling suggestion (completion estimate, conflicts, context).
class SuggestionInsight {
  /// Estimated probability [0,1] that a focus session for this task completes successfully.
  final double completionProbability;
  final String completionSummary;
  final List<ScheduleConflict> conflicts;
  final int taskSessionSampleSize;
  final int categoryPatternSampleSize;
  final double? avgInterruptionsWhenTaskUsed;
  final int? daysUntilDue;
  final bool suggestedTimeMatchesFocusWindow;
  final String? focusWindowNote;
  final String mlSchedulingTip;

  SuggestionInsight({
    required this.completionProbability,
    required this.completionSummary,
    required this.conflicts,
    required this.taskSessionSampleSize,
    required this.categoryPatternSampleSize,
    this.avgInterruptionsWhenTaskUsed,
    this.daysUntilDue,
    required this.suggestedTimeMatchesFocusWindow,
    this.focusWindowNote,
    required this.mlSchedulingTip,
  });
}

/// Builds completion estimates and conflict detection from sessions + ML windows.
class SuggestionAnalyticsService {
  SuggestionAnalyticsService({DataSyncService? db}) : _db = db ?? DataSyncService();

  final DataSyncService _db;

  static bool _rangesOverlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return aStart.isBefore(bEnd) && aEnd.isAfter(bStart);
  }

  List<ScheduleConflict> _findConflicts(
    Suggestion subject,
    List<Suggestion> all,
  ) {
    final out = <ScheduleConflict>[];
    final aId = subject.task.id;
    for (final other in all) {
      if (identical(other, subject)) continue;
      if (aId != null && other.task.id == aId) continue;
      if (aId == null && other.task.title == subject.task.title) continue;

      if (!_rangesOverlap(
        subject.suggestedStartTime,
        subject.suggestedEndTime,
        other.suggestedStartTime,
        other.suggestedEndTime,
      )) {
        continue;
      }

      final oStart = other.suggestedStartTime;
      final oEnd = other.suggestedEndTime;
      out.add(
        ScheduleConflict(
          otherTaskTitle: other.task.title,
          detail: 'Also scheduled ${_fmtShort(oStart)}–${_fmtShort(oEnd)} '
              '(${_typeLabel(other.type)})',
        ),
      );
    }
    return out;
  }

  static String _fmtShort(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final ap = t.hour >= 12 ? 'PM' : 'AM';
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m $ap';
  }

  static String _typeLabel(SuggestionType t) {
    switch (t) {
      case SuggestionType.heavyTask:
        return 'deep work';
      case SuggestionType.lightTask:
        return 'light task';
      case SuggestionType.collaboration:
        return 'collab';
      case SuggestionType.urgent:
        return 'urgent';
    }
  }

  /// How well the suggested slot aligns with ML focus windows (0–1).
  double _slotAlignmentScore(
    Suggestion suggestion,
    List<MLFocusWindow> windows,
  ) {
    if (windows.isEmpty) return 0.55;
    final start = suggestion.suggestedStartTime.toLocal();
    final hour = start.hour;
    final dow = start.weekday;

    MLFocusWindow? best;
    var bestScore = -1.0;
    for (final w in windows) {
      if (!w.peakDays.contains(dow)) continue;
      final hourDiff = (w.peakHour - hour).abs();
      final closeness = 1.0 - (hourDiff / 12.0).clamp(0.0, 1.0) * 0.5;
      var q = 0.5;
      if (w.quality == 'high') {
        q = 1.0;
      } else if (w.quality == 'medium') {
        q = 0.72;
      } else {
        q = 0.45;
      }
      final s = closeness * 0.35 + w.avgFocusScore * 0.45 + q * 0.2;
      if (s > bestScore) {
        bestScore = s;
        best = w;
      }
    }
    if (best == null) return 0.5;
    return bestScore.clamp(0.35, 0.95);
  }

  String? _focusWindowNote(
    Suggestion suggestion,
    List<MLFocusWindow> windows,
  ) {
    if (windows.isEmpty) return null;
    final start = suggestion.suggestedStartTime.toLocal();
    final hour = start.hour;
    final dow = start.weekday;
    for (final w in windows) {
      if (w.peakDays.contains(dow) && (w.peakHour - hour).abs() <= 1) {
        return '${w.quality == 'high' ? 'Strong' : w.quality == 'medium' ? 'Good' : 'OK'} '
            'alignment with your ${w.quality} focus pattern (~${w.peakHour % 12 == 0 ? 12 : w.peakHour % 12}:00).';
      }
    }
    return 'This time is outside your usual peak focus windows — still workable.';
  }

  Future<SuggestionInsight> analyze({
    required Suggestion suggestion,
    required List<Suggestion> allSuggestions,
    required List<MLFocusWindow> focusWindows,
    required String mlSchedulingTip,
  }) async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 120));
    final sessions = await _db.getSessionsForRange(start, now);
    final patterns = await _db.getFocusPatterns();

    final taskId = suggestion.task.id;
    List<Session> forTask = [];
    if (taskId != null) {
      forTask = sessions.where((s) => s.taskId == taskId).toList();
    }

    double taskCompletionRate = 0.65;
    if (forTask.isNotEmpty) {
      final done = forTask.where((s) => s.isCompleted).length;
      taskCompletionRate = done / forTask.length;
    }

    final cat = suggestion.task.category;
    final catPatterns =
        patterns.where((p) => p.category == cat).toList();
    double categoryScore = 0.65;
    if (catPatterns.isNotEmpty) {
      final avg = catPatterns.fold<double>(
            0,
            (sum, p) => sum + p.focusScore,
          ) /
          catPatterns.length;
      categoryScore = avg.clamp(0.2, 0.95);
    }

    final slotScore = _slotAlignmentScore(suggestion, focusWindows);
    final conf = suggestion.confidence.clamp(0.1, 0.95);

    double p;
    String summary;
    if (forTask.length >= 3) {
      p = taskCompletionRate * 0.55 + slotScore * 0.25 + conf * 0.20;
      summary =
          'Based on ${forTask.length} past sessions for this task '
          '(${(taskCompletionRate * 100).round()}% completed) and your focus patterns.';
    } else if (forTask.isNotEmpty) {
      p = taskCompletionRate * 0.40 +
          categoryScore * 0.30 +
          slotScore * 0.20 +
          conf * 0.10;
      summary = forTask.length == 1
          ? 'Limited history on this task — estimate blends that session, '
              '${catPatterns.length} similar category patterns, and schedule fit.'
          : 'Early data for this task — estimate uses your ${forTask.length} sessions, '
              'category trends, and suggested time quality.';
    } else {
      p = categoryScore * 0.35 + slotScore * 0.35 + conf * 0.30;
      summary = taskId == null
          ? 'No linked sessions yet — estimate uses category "${suggestion.task.category}", '
              'focus windows, and suggestion confidence.'
          : 'No past sessions linked to this task — estimate uses category patterns, '
              'your focus windows, and scheduling confidence.';
    }

    p = p.clamp(0.08, 0.97);

    double? avgIntr;
    if (forTask.isNotEmpty) {
      final n = forTask.fold<int>(0, (s, x) => s + x.interruptionCount);
      avgIntr = n / forTask.length;
    }

    int? daysDue;
    final due = suggestion.task.dueDate;
    if (due != null) {
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(due.year, due.month, due.day);
      daysDue = dueDay.difference(today).inDays;
    }

    final conflicts = _findConflicts(suggestion, allSuggestions);
    final startLocal = suggestion.suggestedStartTime.toLocal();
    final matches = focusWindows.any(
      (w) =>
          w.peakDays.contains(startLocal.weekday) &&
          (w.peakHour - startLocal.hour).abs() <= 2,
    );

    return SuggestionInsight(
      completionProbability: p,
      completionSummary: summary,
      conflicts: conflicts,
      taskSessionSampleSize: forTask.length,
      categoryPatternSampleSize: catPatterns.length,
      avgInterruptionsWhenTaskUsed: avgIntr,
      daysUntilDue: daysDue,
      suggestedTimeMatchesFocusWindow: matches,
      focusWindowNote: _focusWindowNote(suggestion, focusWindows),
      mlSchedulingTip: mlSchedulingTip,
    );
  }
}
