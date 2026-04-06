import 'package:cloud_firestore/cloud_firestore.dart';

/// Session model (focus sessions)
///
/// Tracks everything needed for ML clustering:
/// - duration, completion, interruptions (existing)
/// - selfRating (NEW) — user rates their focus quality 1-5 after each session
///
/// selfRating values:
///   1 = Very distracted
///   2 = Mostly distracted
///   3 = Neutral
///   4 = Mostly focused
///   5 = Deep focus (flow state)
///   null = Not yet rated (session ended early or user skipped)
class Session {
  final String? id;
  final String? taskId;
  final DateTime startTime;
  final int duration; // in seconds
  final bool isCompleted;
  final int interruptionCount;
  final int? selfRating; // 1-5 focus quality rating, null if skipped

  Session({
    this.id,
    this.taskId,
    required this.startTime,
    required this.duration,
    this.isCompleted = false,
    this.interruptionCount = 0,
    this.selfRating,
  });

  // ---------------- Firestore WRITE ----------------

  Map<String, dynamic> toFirestore() {
    return {
      'taskId': taskId,
      'startTime': Timestamp.fromDate(startTime),
      'duration': duration,
      'isCompleted': isCompleted,
      'interruptionCount': interruptionCount,
      'selfRating': selfRating,
    };
  }

  // ---------------- Firestore READ ----------------

  factory Session.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return Session(
      id: doc.id,
      taskId: data['taskId'] as String?,
      startTime: (data['startTime'] as Timestamp).toDate(),
      duration: data['duration'] as int? ?? 0,
      isCompleted: data['isCompleted'] as bool? ?? false,
      interruptionCount: data['interruptionCount'] as int? ?? 0,
      selfRating: data['selfRating'] as int?,
    );
  }

  // ---------------- Generic Map helpers ----------------

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'startTime': startTime,
      'duration': duration,
      'isCompleted': isCompleted,
      'interruptionCount': interruptionCount,
      'selfRating': selfRating,
    };
  }

  factory Session.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }

    return Session(
      id: id,
      taskId: map['taskId'] as String?,
      startTime: parseDate(map['startTime']),
      duration: map['duration'] as int? ?? 0,
      isCompleted: map['isCompleted'] as bool? ?? false,
      interruptionCount: map['interruptionCount'] as int? ?? 0,
      selfRating: map['selfRating'] as int?,
    );
  }

  // ---------------- Copy helper ----------------

  Session copyWith({
    String? id,
    String? taskId,
    DateTime? startTime,
    int? duration,
    bool? isCompleted,
    int? interruptionCount,
    int? selfRating,
  }) {
    return Session(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      isCompleted: isCompleted ?? this.isCompleted,
      interruptionCount: interruptionCount ?? this.interruptionCount,
      selfRating: selfRating ?? this.selfRating,
    );
  }
}
