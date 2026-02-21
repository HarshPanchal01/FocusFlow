/// Task model for FocusFlow.
///
/// Fields align with the proposal: title, description, priority,
/// due date, estimated duration, category, and completion status.
/// Includes toMap/fromMap for SQLite and toFirestore/fromFirestore
/// stubs so the Firebase sync (Issue #5) can plug in later.

enum Priority { low, medium, high }

class Task {
  final int? id; // SQLite auto-increment; null until inserted
  final String title;
  final String description;
  final Priority priority;
  final DateTime? dueDate;
  final int durationMinutes; // estimated time to complete
  final String category; // e.g. "Coursework", "Work", "Personal"
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    this.id,
    required this.title,
    this.description = '',
    this.priority = Priority.medium,
    this.dueDate,
    this.durationMinutes = 25,
    this.category = 'General',
    this.isCompleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // --------------- SQLite helpers ---------------

  Map<String, dynamic> toMap() {
    // Convert DateTime to ISO8601 string
    // For dueDate, ensure we preserve the local time by converting to UTC first
    // then back to local when reading (handled in fromMap)
    String? formatDate(DateTime? date) {
      if (date == null) return null;
      // Convert to UTC for storage to ensure consistency
      // When reading back, we'll convert to local
      return date.toUtc().toIso8601String();
    }
    
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'priority': priority.index, // 0=low, 1=medium, 2=high
      'dueDate': formatDate(dueDate),
      'durationMinutes': durationMinutes,
      'category': category,
      'isCompleted': isCompleted ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    DateTime? parseDueDate(String? dateString) {
      if (dateString == null) return null;
      
      final parsed = DateTime.tryParse(dateString);
      if (parsed == null) return null;
      
      // Dates are stored in UTC, so convert to local time when reading
      // This ensures the time displayed matches what the user selected
      return parsed.isUtc ? parsed.toLocal() : parsed;
    }
    
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      priority: Priority.values[map['priority'] as int? ?? 1],
      dueDate: parseDueDate(map['dueDate'] as String?),
      durationMinutes: map['durationMinutes'] as int? ?? 25,
      category: map['category'] as String? ?? 'General',
      isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  // --------------- Firestore stubs (Issue #5) ---------------

  Map<String, dynamic> toFirestore() {
    // TODO: implement when Firebase sync is added
    return toMap()..remove('id'); // Firestore uses doc IDs, not int IDs
  }

  factory Task.fromFirestore(Map<String, dynamic> map, String docId) {
    // TODO: map Firestore doc to Task
    return Task.fromMap(map);
  }

  // --------------- Copy helper for updates ---------------

  Task copyWith({
    int? id,
    String? title,
    String? description,
    Priority? priority,
    DateTime? dueDate,
    bool clearDueDate = false,
    int? durationMinutes,
    String? category,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      durationMinutes: durationMinutes ?? this.durationMinutes,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() => 'Task(id: $id, title: $title, priority: $priority)';
}
