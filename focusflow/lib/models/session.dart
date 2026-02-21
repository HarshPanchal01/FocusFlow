class Session {
  final int? id;
  final int? taskId;
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

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'taskId': taskId,
      'startTime': startTime.toIso8601String(),
      'duration': duration,
      'isCompleted': isCompleted ? 1 : 0,
      'interruptionCount': interruptionCount, // No check needed, defaults to 0
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as int?,
      taskId: map['taskId'] as int?,
      startTime: DateTime.parse(map['startTime'] as String),
      duration: map['duration'] as int,
      isCompleted: (map['isCompleted'] as int) == 1,
      interruptionCount: map['interruptionCount'] as int? ?? 0,
    );
  }
}
