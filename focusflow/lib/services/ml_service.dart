import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/session.dart';
import '../models/task.dart';
import '../models/focus_pattern.dart';
import '../services/firestore_service.dart';

/// MLService handles focus pattern extraction and K-means clustering
/// to identify the user's optimal focus windows.
///
/// Architecture:
///   Sessions (raw data)
///     → FocusPatterns (extracted features)
///       → K-means clustering (group similar patterns)
///         → FocusWindows (identified productive time blocks)
///
/// The clustering uses these features:
///   - Hour of day (when)
///   - Day of week (when)
///   - Duration (how long)
///   - Completion rate (how well)
///   - Interruption count (how distracted)
///   - Self-rating (subjective quality)
class MLService {
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  final FirestoreService _firestoreService = FirestoreService();

  // ════════════════════════════════════════════════════════════
  // FEATURE EXTRACTION
  // ════════════════════════════════════════════════════════════

  /// Extracts a FocusPattern from a completed session + its associated task.
  /// This is called after every session ends and the user submits a rating.
  FocusPattern extractPattern({
    required Session session,
    required Task? task,
    required int totalPlannedSeconds,
  }) {
    // Calculate completion rate: actual duration / planned duration
    final completionRate = totalPlannedSeconds > 0
        ? (session.duration / totalPlannedSeconds).clamp(0.0, 1.0)
        : 0.0;

    // Calculate composite focus score (0.0 - 1.0)
    final focusScore = _calculateFocusScore(
      completionRate: completionRate,
      interruptionCount: session.interruptionCount,
      selfRating: session.selfRating,
      durationSeconds: session.duration,
    );

    return FocusPattern(
      sessionId: session.id,
      taskId: session.taskId,
      hourOfDay: session.startTime.hour,
      dayOfWeek: session.startTime.weekday,
      durationMinutes: session.duration / 60.0,
      completionRate: completionRate,
      interruptionCount: session.interruptionCount,
      selfRating: session.selfRating,
      category: task?.category ?? 'General',
      priority: task?.priority.index ?? 1,
      focusScore: focusScore,
    );
  }

  /// Composite focus score combining all quality signals.
  /// Weights reflect proposal priorities:
  ///   - Completion rate (30%): did they finish?
  ///   - Self-rating (30%): how did they feel?
  ///   - Interruptions (20%): were they disturbed?
  ///   - Duration (20%): did they sustain focus?
  double _calculateFocusScore({
    required double completionRate,
    required int interruptionCount,
    required int? selfRating,
    required int durationSeconds,
  }) {
    // Completion component (0-1)
    final completionComponent = completionRate;

    // Rating component (0-1), default 0.5 if not rated
    final ratingComponent = selfRating != null
        ? (selfRating - 1) / 4.0
        : 0.5;

    // Interruption component (0-1), fewer interruptions = higher score
    final interruptionComponent = (1.0 - (interruptionCount / 10.0)).clamp(0.0, 1.0);

    // Duration component (0-1), longer sustained sessions score higher
    // Caps at 60 minutes (anything longer gets full marks)
    final durationMinutes = durationSeconds / 60.0;
    final durationComponent = (durationMinutes / 60.0).clamp(0.0, 1.0);

    // Weighted composite
    return (completionComponent * 0.30) +
           (ratingComponent * 0.30) +
           (interruptionComponent * 0.20) +
           (durationComponent * 0.20);
  }

  // ════════════════════════════════════════════════════════════
  // SAVE PATTERN TO FIRESTORE
  // ════════════════════════════════════════════════════════════

  /// Returns the total number of stored focus patterns.
  Future<int> getPatternCount() async {
    final patterns = await _firestoreService.getFocusPatterns();
    return patterns.length;
  }

  /// Saves an extracted focus pattern to the user's Firestore collection.
  /// Called after feature extraction completes.
  Future<void> savePattern(FocusPattern pattern) async {
    try {
      await _firestoreService.insertFocusPattern(pattern);
      debugPrint('ML: Saved focus pattern — hour=${pattern.hourOfDay}, '
          'day=${pattern.dayOfWeek}, score=${pattern.focusScore.toStringAsFixed(2)}');
    } catch (e) {
      debugPrint('ML: Error saving pattern: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  // K-MEANS CLUSTERING
  // ════════════════════════════════════════════════════════════

  /// Runs K-means clustering on stored focus patterns to identify
  /// groups of similar sessions. Returns cluster assignments.
  ///
  /// k = number of clusters (default 3: "high focus", "medium", "low focus")
  /// maxIterations = convergence limit
  Future<List<MLFocusWindow>> identifyFocusWindows({
    int k = 3,
    int maxIterations = 50,
  }) async {
    try {
      // Fetch all stored patterns
      final patterns = await _firestoreService.getFocusPatterns();

      if (patterns.length < k) {
        debugPrint('ML: Not enough data for clustering '
            '(${patterns.length} patterns, need at least $k)');
        return [];
      }

      // Extract feature vectors
      final vectors = patterns.map((p) => p.toFeatureVector()).toList();

      // Run K-means
      final assignments = _kMeans(vectors, k, maxIterations);

      // Group patterns by cluster
      final clusters = <int, List<FocusPattern>>{};
      for (int i = 0; i < patterns.length; i++) {
        final cluster = assignments[i];
        clusters.putIfAbsent(cluster, () => []);
        clusters[cluster]!.add(patterns[i]);
      }

      // Convert clusters to FocusWindows
      final windows = <MLFocusWindow>[];
      for (final entry in clusters.entries) {
        final clusterPatterns = entry.value;

        // Calculate average focus score for this cluster
        final avgScore = clusterPatterns
            .map((p) => p.focusScore)
            .reduce((a, b) => a + b) / clusterPatterns.length;

        // Find the most common hour and day in this cluster
        final hourCounts = <int, int>{};
        final dayCounts = <int, int>{};
        for (final p in clusterPatterns) {
          hourCounts[p.hourOfDay] = (hourCounts[p.hourOfDay] ?? 0) + 1;
          dayCounts[p.dayOfWeek] = (dayCounts[p.dayOfWeek] ?? 0) + 1;
        }

        // Peak hour = hour with the most sessions in this cluster
        final peakHour = hourCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b).key;

        // Peak days = all days that appear in this cluster
        final peakDays = dayCounts.keys.toList()..sort();

        // Determine quality label based on average focus score
        final String quality;
        if (avgScore >= 0.7) {
          quality = 'high';
        } else if (avgScore >= 0.4) {
          quality = 'medium';
        } else {
          quality = 'low';
        }

        windows.add(MLFocusWindow(
          clusterId: entry.key,
          quality: quality,
          avgFocusScore: avgScore,
          peakHour: peakHour,
          peakDays: peakDays,
          sessionCount: clusterPatterns.length,
          avgDurationMinutes: clusterPatterns
              .map((p) => p.durationMinutes)
              .reduce((a, b) => a + b) / clusterPatterns.length,
          avgInterruptions: clusterPatterns
              .map((p) => p.interruptionCount.toDouble())
              .reduce((a, b) => a + b) / clusterPatterns.length,
        ));
      }

      // Sort by focus score (best windows first)
      windows.sort((a, b) => b.avgFocusScore.compareTo(a.avgFocusScore));

      debugPrint('ML: Identified ${windows.length} focus windows');
      for (final w in windows) {
        debugPrint('  ${w.quality} focus: ${w.peakHour}:00 on days ${w.peakDays} '
            '(score: ${w.avgFocusScore.toStringAsFixed(2)}, '
            '${w.sessionCount} sessions)');
      }

      return windows;
    } catch (e) {
      debugPrint('ML: Error during clustering: $e');
      return [];
    }
  }

  /// Standard K-means clustering algorithm.
  /// Returns a list of cluster assignments (one per input vector).
  List<int> _kMeans(List<List<double>> vectors, int k, int maxIterations) {
    final random = Random(42); // fixed seed for reproducibility
    final n = vectors.length;
    final dims = vectors[0].length;

    // Initialize centroids using random data points (K-means++ would be better
    // but this is simpler and fine for our data sizes)
    final centroidIndices = <int>{};
    while (centroidIndices.length < k) {
      centroidIndices.add(random.nextInt(n));
    }
    final centroids = centroidIndices.map((i) => List<double>.from(vectors[i])).toList();

    var assignments = List<int>.filled(n, 0);

    for (int iter = 0; iter < maxIterations; iter++) {
      // ASSIGN: each point to nearest centroid
      final newAssignments = List<int>.filled(n, 0);
      for (int i = 0; i < n; i++) {
        double minDist = double.infinity;
        int bestCluster = 0;
        for (int c = 0; c < k; c++) {
          final dist = _euclideanDistance(vectors[i], centroids[c]);
          if (dist < minDist) {
            minDist = dist;
            bestCluster = c;
          }
        }
        newAssignments[i] = bestCluster;
      }

      // CHECK: convergence (no assignments changed)
      bool converged = true;
      for (int i = 0; i < n; i++) {
        if (newAssignments[i] != assignments[i]) {
          converged = false;
          break;
        }
      }
      assignments = newAssignments;

      if (converged) {
        debugPrint('ML: K-means converged after ${iter + 1} iterations');
        break;
      }

      // UPDATE: recalculate centroids
      for (int c = 0; c < k; c++) {
        final members = <List<double>>[];
        for (int i = 0; i < n; i++) {
          if (assignments[i] == c) members.add(vectors[i]);
        }
        if (members.isNotEmpty) {
          for (int d = 0; d < dims; d++) {
            centroids[c][d] = members
                .map((v) => v[d])
                .reduce((a, b) => a + b) / members.length;
          }
        }
      }
    }

    return assignments;
  }

  /// Euclidean distance between two vectors.
  double _euclideanDistance(List<double> a, List<double> b) {
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      final diff = a[i] - b[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  // ════════════════════════════════════════════════════════════
  // SCHEDULING RECOMMENDATIONS
  // ════════════════════════════════════════════════════════════

  /// Given identified focus windows, recommends when to schedule a task
  /// based on its priority and the user's best focus times.
  ///
  /// High priority tasks → scheduled in "high" focus windows
  /// Low priority tasks → scheduled in "low" focus windows (save peak time)
  String getRecommendation(List<MLFocusWindow> windows, Task task) {
    if (windows.isEmpty) {
      return 'Keep logging sessions — we need more data to learn your patterns.';
    }

    // Find the best window for this task's priority
    MLFocusWindow? targetWindow;

    if (task.priority == Priority.high) {
      // High priority → best focus window
      targetWindow = windows.first; // already sorted by score desc
    } else if (task.priority == Priority.low) {
      // Low priority → worst focus window (save good times for hard tasks)
      targetWindow = windows.last;
    } else {
      // Medium → middle window if available, otherwise best
      targetWindow = windows.length > 1
          ? windows[windows.length ~/ 2]
          : windows.first;
    }

    final dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final daysStr = targetWindow.peakDays.map((d) => dayNames[d]).join(', ');
    final hourStr = _formatHour(targetWindow.peakHour);

    return 'Best time for "${task.title}": around $hourStr on $daysStr '
        '(${targetWindow.quality} focus window, '
        '${targetWindow.avgDurationMinutes.round()} min avg sessions)';
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour < 12) return '$hour:00 AM';
    if (hour == 12) return '12:00 PM';
    return '${hour - 12}:00 PM';
  }
}


/// Represents an identified focus window from ML clustering.
/// A focus window is a recurring time block where the user
/// tends to have consistent focus quality (high, medium, or low).
class MLFocusWindow {
  final int clusterId;
  final String quality;          // "high", "medium", "low"
  final double avgFocusScore;    // 0.0 - 1.0
  final int peakHour;            // most common start hour in this cluster
  final List<int> peakDays;      // days of week this pattern occurs
  final int sessionCount;        // how many sessions in this cluster
  final double avgDurationMinutes;
  final double avgInterruptions;

  MLFocusWindow({
    required this.clusterId,
    required this.quality,
    required this.avgFocusScore,
    required this.peakHour,
    required this.peakDays,
    required this.sessionCount,
    required this.avgDurationMinutes,
    required this.avgInterruptions,
  });

  @override
  String toString() =>
      'MLFocusWindow($quality @ ${peakHour}:00, score=${avgFocusScore.toStringAsFixed(2)}, '
      'sessions=$sessionCount)';
}
