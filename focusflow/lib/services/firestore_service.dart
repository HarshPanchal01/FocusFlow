import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';
import '../models/session.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// FirestoreService handles ALL database operations using Firebase.
///
/// Replaces SQLite DatabaseService.
/// Stores data under:
///   users/{uid}/tasks
///   users/{uid}/sessions
class FirestoreService {
  // Singleton pattern (same instance everywhere)
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// TEMP: hardcoded user until Firebase Auth is added
  /// Later replace with: FirebaseAuth.instance.currentUser!.uid (DONE)
  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found.');
    }
    return user.uid;
  }

  /// Reference to user's tasks collection
  CollectionReference<Map<String, dynamic>> get _tasksRef =>
      _firestore.collection('users').doc(_uid).collection('tasks');

  /// Reference to user's sessions collection
  CollectionReference<Map<String, dynamic>> get _sessionsRef =>
      _firestore.collection('users').doc(_uid).collection('sessions');

  // ---------------- TASKS ----------------

  /// Add a new task to Firestore
  Future<Task> insertTask(Task task) async {
    final docRef = await _tasksRef.add(task.toFirestore());

    // Fetch the created doc so we get the generated ID
    final doc = await docRef.get();
    return Task.fromFirestore(doc);
  }

  /// Get all tasks (then sort locally)
  Future<List<Task>> getTasks() async {
    final snapshot = await _tasksRef.get();

    final tasks =
        snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();

    // Sorting is done in Dart (Firestore queries are limited)
    tasks.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }

      final priorityCompare =
          b.priority.index.compareTo(a.priority.index);
      if (priorityCompare != 0) return priorityCompare;

      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });

    return tasks;
  }

  /// Get a single task by its Firestore document ID
  Future<Task?> getTaskById(String id) async {
    final doc = await _tasksRef.doc(id).get();
    if (!doc.exists) return null;
    return Task.fromFirestore(doc);
  }

  /// Update an existing task
  Future<void> updateTask(Task task) async {
    if (task.id == null) {
      throw Exception('Task ID is null. Cannot update.');
    }

    await _tasksRef.doc(task.id).update(task.toFirestore());
  }

  /// Toggle completion status (quick update)
  Future<void> toggleTaskCompletion(String id, bool isCompleted) async {
    await _tasksRef.doc(id).update({
      'isCompleted': isCompleted,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Delete a task
  Future<void> deleteTask(String id) async {
    await _tasksRef.doc(id).delete();
  }

  /// Delete all completed tasks using a batch
  Future<void> deleteCompletedTasks() async {
    final snapshot =
        await _tasksRef.where('isCompleted', isEqualTo: true).get();

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Count tasks (optionally filtered)
  Future<int> getTaskCount({bool? isCompleted}) async {
    Query<Map<String, dynamic>> query = _tasksRef;

    if (isCompleted != null) {
      query = query.where('isCompleted', isEqualTo: isCompleted);
    }

    final snapshot = await query.get();
    return snapshot.docs.length;
  }

  // ---------------- SESSIONS ----------------

  /// Add a session (focus session)
  Future<Session> insertSession(Session session) async {
    final docRef = await _sessionsRef.add(session.toFirestore());
    final doc = await docRef.get();
    return Session.fromFirestore(doc);
  }

  /// Get all sessions (latest first)
  Future<List<Session>> getSessions() async {
    final snapshot = await _sessionsRef
        .orderBy('startTime', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Session.fromFirestore(doc))
        .toList();
  }

  /// Get sessions within a time range
  Future<List<Session>> getSessionsForRange(
      DateTime start, DateTime end) async {
    final snapshot = await _sessionsRef
        .where(
          'startTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(
          'startTime',
          isLessThanOrEqualTo: Timestamp.fromDate(end),
        )
        .orderBy('startTime')
        .get();

    return snapshot.docs
        .map((doc) => Session.fromFirestore(doc))
        .toList();
  }
}