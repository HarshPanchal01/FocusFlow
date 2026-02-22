import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';

/// Handles all Firestore interactions for tasks
/// Keeps database logic separate from state management
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'tasks';

  // Get all tasks from Firestore
  Future<List<Task>> getTasks() async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('priority', descending: true)
        .orderBy('dueDate')
        .get();

    return snapshot.docs
        .map((doc) => Task.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  // Add new task
  Future<String> addTask(Task task) async {
    final doc = await _firestore
        .collection(_collection)
        .add(task.toFirestore());

    return doc.id;
  }

  // Update task
  Future<void> updateTask(Task task) async {
    if (task.id == null) return;

    await _firestore
        .collection(_collection)
        .doc(task.id)
        .update(task.toFirestore());
  }

  // Delete task
  Future<void> deleteTask(String id) async {
    await _firestore
        .collection(_collection)
        .doc(id)
        .delete();
  }

  // Delete completed task
  Future<void> deleteCompletedTasks() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('isCompleted', isEqualTo: true)
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}