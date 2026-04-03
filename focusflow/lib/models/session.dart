import 'package:cloud_firestore/cloud_firestore.dart';

/// Session model (focus sessions / pomodoro sessions)
///
/// Key changes:
/// - id is now Firestore doc ID (String)
/// - taskId is also String (references Task.id)
/// - startTime stored as Timestamp
class Session {
  final String? id;
  final String? taskId; // references Firestore task ID
  final DateTime startTime;
  final int duration; // in seconds
  final bool isCompleted;
  final int interruptionCount;

  Session({
    this.id,
    this.taskId,
    required this.startTime,
    required this.duration,
    this.isCompleted = false,
    this.interruptionCount = 0,
  });

  // ---------------- Firestore WRITE ----------------

  /// Convert Session → Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'taskId': taskId,
      'startTime': Timestamp.fromDate(startTime),
      'duration': duration,
      'isCompleted': isCompleted,
      'interruptionCount': interruptionCount,
    };
  }

  // ---------------- Firestore READ ----------------

  /// Convert Firestore document → Session
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
    );
  }

  // ---------------- Optional Map helpers ----------------
  // Useful if needed outside Firestore

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'startTime': startTime,
      'duration': duration,
      'isCompleted': isCompleted,
      'interruptionCount': interruptionCount,
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
    );
  }
}