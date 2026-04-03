import 'package:cloud_firestore/cloud_firestore.dart';

/// Task model for FocusFlow (Firestore version)
///
/// Key changes from SQLite:
/// - id is now a String (Firestore doc ID)
/// - booleans stay booleans (no more 0/1)
/// - dates use Firestore Timestamps
enum Priority { low, medium, high }

class Task {
  final String? id; // Firestore document ID
  final String title;
  final String description;
  final Priority priority;
  final DateTime? dueDate;
  final int durationMinutes;
  final String category;
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

  // ---------------- Firestore WRITE ----------------

  /// Convert Task → Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'priority': priority.index,
      'dueDate':
          dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'durationMinutes': durationMinutes,
      'category': category,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // ---------------- Firestore READ ----------------

  /// Convert Firestore document → Task
  factory Task.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return Task(
      id: doc.id, // Firestore doc ID
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      priority: Priority.values[(data['priority'] as int?) ?? 1],
      dueDate: data['dueDate'] != null
          ? (data['dueDate'] as Timestamp).toDate()
          : null,
      durationMinutes: data['durationMinutes'] as int? ?? 25,
      category: data['category'] as String? ?? 'General',
      isCompleted: data['isCompleted'] as bool? ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // ---------------- Generic Map (optional use) ----------------
  // Useful if you ever need non-Firebase mapping

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'priority': priority.index,
      'dueDate': dueDate,
      'durationMinutes': durationMinutes,
      'category': category,
      'isCompleted': isCompleted,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return Task(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      priority: Priority.values[(map['priority'] as int?) ?? 1],
      dueDate: parseDate(map['dueDate']),
      durationMinutes: map['durationMinutes'] as int? ?? 25,
      category: map['category'] as String? ?? 'General',
      isCompleted: map['isCompleted'] as bool? ?? false,
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  // ---------------- Copy helper ----------------
  // Used when updating tasks

  Task copyWith({
    String? id,
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
  String toString() => 'Task(id: $id, title: $title)';
}