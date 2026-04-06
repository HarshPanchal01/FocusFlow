import 'package:cloud_firestore/cloud_firestore.dart';

/// FocusPattern represents extracted features from a focus session,
/// used as input for ML clustering to identify optimal focus windows.
///
/// Each completed session gets converted into a FocusPattern that captures:
/// - WHEN: hour of day, day of week
/// - HOW LONG: session duration in minutes
/// - HOW WELL: completion rate (0.0-1.0), interruption count, self-rating
/// - WHAT: task category, task priority
///
/// The ML service clusters these patterns to find recurring time blocks
/// where the user performs best (their "focus windows").
class FocusPattern {
  final String? id;
  final String? sessionId;   // links back to the original session
  final String? taskId;

  // ---- Time features ----
  final int hourOfDay;       // 0-23 (when the session started)
  final int dayOfWeek;       // 1=Mon, 7=Sun

  // ---- Performance features ----
  final double durationMinutes;   // how long the session lasted
  final double completionRate;    // 0.0 (abandoned immediately) to 1.0 (ran full timer)
  final int interruptionCount;
  final int? selfRating;          // 1-5, null if skipped

  // ---- Task context features ----
  final String category;          // task category (Work, Coursework, etc.)
  final int priority;             // 0=low, 1=medium, 2=high

  // ---- Computed focus score ----
  /// A 0.0-1.0 composite score used for clustering.
  /// Higher = better focus session.
  final double focusScore;

  final DateTime createdAt;

  FocusPattern({
    this.id,
    this.sessionId,
    this.taskId,
    required this.hourOfDay,
    required this.dayOfWeek,
    required this.durationMinutes,
    required this.completionRate,
    required this.interruptionCount,
    this.selfRating,
    required this.category,
    required this.priority,
    required this.focusScore,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // ---------------- Firestore WRITE ----------------

  Map<String, dynamic> toFirestore() {
    return {
      'sessionId': sessionId,
      'taskId': taskId,
      'hourOfDay': hourOfDay,
      'dayOfWeek': dayOfWeek,
      'durationMinutes': durationMinutes,
      'completionRate': completionRate,
      'interruptionCount': interruptionCount,
      'selfRating': selfRating,
      'category': category,
      'priority': priority,
      'focusScore': focusScore,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ---------------- Firestore READ ----------------

  factory FocusPattern.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return FocusPattern(
      id: doc.id,
      sessionId: data['sessionId'] as String?,
      taskId: data['taskId'] as String?,
      hourOfDay: data['hourOfDay'] as int? ?? 0,
      dayOfWeek: data['dayOfWeek'] as int? ?? 1,
      durationMinutes: (data['durationMinutes'] as num?)?.toDouble() ?? 0,
      completionRate: (data['completionRate'] as num?)?.toDouble() ?? 0,
      interruptionCount: data['interruptionCount'] as int? ?? 0,
      selfRating: data['selfRating'] as int?,
      category: data['category'] as String? ?? 'General',
      priority: data['priority'] as int? ?? 1,
      focusScore: (data['focusScore'] as num?)?.toDouble() ?? 0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // ---------------- Feature vector for clustering ----------------

  /// Returns the feature vector used by the ML clustering algorithm.
  /// All values are normalized to 0.0-1.0 range for distance calculation.
  List<double> toFeatureVector() {
    return [
      hourOfDay / 23.0,                          // normalize hour to 0-1
      (dayOfWeek - 1) / 6.0,                     // normalize day to 0-1
      (durationMinutes / 120.0).clamp(0.0, 1.0), // cap at 2 hours
      completionRate,                              // already 0-1
      (1.0 - (interruptionCount / 10.0)).clamp(0.0, 1.0), // fewer = better
      (selfRating != null ? (selfRating! - 1) / 4.0 : 0.5), // normalize 1-5 to 0-1
    ];
  }

  @override
  String toString() =>
      'FocusPattern(hour: $hourOfDay, day: $dayOfWeek, score: ${focusScore.toStringAsFixed(2)})';
}
