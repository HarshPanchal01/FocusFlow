import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/session.dart';
import '../models/focus_pattern.dart';

/// Local SQLite database service — the offline-first data layer.
///
/// Schema uses TEXT IDs that match Firestore document IDs so data
/// can sync seamlessly between local and cloud storage.
///
/// When offline: reads/writes go here and work instantly.
/// When online: DataSyncService pushes changes to Firestore.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;
  static const int _dbVersion = 5;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'focusflow_v2.db');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tasks table — ID is TEXT to match Firestore doc IDs
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT DEFAULT '',
        priority INTEGER DEFAULT 1,
        dueDate TEXT,
        durationMinutes INTEGER DEFAULT 25,
        category TEXT DEFAULT 'General',
        isCompleted INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Sessions table — matches updated Session model with selfRating
    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        taskId TEXT,
        startTime TEXT NOT NULL,
        duration INTEGER NOT NULL,
        isCompleted INTEGER DEFAULT 0,
        interruptionCount INTEGER DEFAULT 0,
        selfRating INTEGER
      )
    ''');

    // Focus patterns table — ML feature data
    await db.execute('''
      CREATE TABLE focus_patterns (
        id TEXT PRIMARY KEY,
        sessionId TEXT,
        taskId TEXT,
        hourOfDay INTEGER NOT NULL,
        dayOfWeek INTEGER NOT NULL,
        durationMinutes REAL NOT NULL,
        completionRate REAL NOT NULL,
        interruptionCount INTEGER DEFAULT 0,
        selfRating INTEGER,
        category TEXT DEFAULT 'General',
        priority INTEGER DEFAULT 1,
        focusScore REAL NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  // ════════════════════════════════════════════════════════════
  // TASKS
  // ════════════════════════════════════════════════════════════

  Future<void> insertTask(Task task) async {
    final db = await database;
    await db.insert(
      'tasks',
      {
        'id': task.id,
        'title': task.title,
        'description': task.description,
        'priority': task.priority.index,
        'dueDate': task.dueDate?.toIso8601String(),
        'durationMinutes': task.durationMinutes,
        'category': task.category,
        'isCompleted': task.isCompleted ? 1 : 0,
        'createdAt': task.createdAt.toIso8601String(),
        'updatedAt': task.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Task>> getTasks() async {
    final db = await database;
    final maps = await db.query('tasks', orderBy: 'priority DESC, dueDate ASC');
    return maps.map((map) {
      // SQLite stores booleans as 0/1, so convert before passing to fromMap
      final fixedMap = Map<String, dynamic>.from(map);
      if (fixedMap['isCompleted'] is int) {
        fixedMap['isCompleted'] = (fixedMap['isCompleted'] as int) == 1;
      }
      return Task.fromMap(fixedMap, id: map['id'] as String?);
    }).toList();
  }

  Future<void> updateTask(Task task) async {
    final db = await database;
    await db.update(
      'tasks',
      {
        'title': task.title,
        'description': task.description,
        'priority': task.priority.index,
        'dueDate': task.dueDate?.toIso8601String(),
        'durationMinutes': task.durationMinutes,
        'category': task.category,
        'isCompleted': task.isCompleted ? 1 : 0,
        'updatedAt': task.updatedAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCompletedTasks() async {
    final db = await database;
    await db.delete('tasks', where: 'isCompleted = ?', whereArgs: [1]);
  }

  /// Replace all local tasks with data from Firestore (used during sync)
  Future<void> replaceAllTasks(List<Task> tasks) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('tasks');
      for (final task in tasks) {
        await txn.insert('tasks', {
          'id': task.id,
          'title': task.title,
          'description': task.description,
          'priority': task.priority.index,
          'dueDate': task.dueDate?.toIso8601String(),
          'durationMinutes': task.durationMinutes,
          'category': task.category,
          'isCompleted': task.isCompleted ? 1 : 0,
          'createdAt': task.createdAt.toIso8601String(),
          'updatedAt': task.updatedAt.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ════════════════════════════════════════════════════════════
  // SESSIONS
  // ════════════════════════════════════════════════════════════

  Future<void> insertSession(Session session) async {
    final db = await database;
    await db.insert(
      'sessions',
      {
        'id': session.id,
        'taskId': session.taskId,
        'startTime': session.startTime.toIso8601String(),
        'duration': session.duration,
        'isCompleted': session.isCompleted ? 1 : 0,
        'interruptionCount': session.interruptionCount,
        'selfRating': session.selfRating,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Session>> getSessionsForRange(DateTime start, DateTime end) async {
    final db = await database;
    final maps = await db.query(
      'sessions',
      where: 'startTime >= ? AND startTime <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'startTime ASC',
    );
    return maps.map((map) {
      final fixedMap = Map<String, dynamic>.from(map);
      if (fixedMap['isCompleted'] is int) {
        fixedMap['isCompleted'] = (fixedMap['isCompleted'] as int) == 1;
      }
      return Session.fromMap(fixedMap, id: map['id'] as String?);
    }).toList();
  }

  /// Replace all local sessions with Firestore data (sync)
  Future<void> replaceAllSessions(List<Session> sessions) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sessions');
      for (final session in sessions) {
        await txn.insert('sessions', {
          'id': session.id,
          'taskId': session.taskId,
          'startTime': session.startTime.toIso8601String(),
          'duration': session.duration,
          'isCompleted': session.isCompleted ? 1 : 0,
          'interruptionCount': session.interruptionCount,
          'selfRating': session.selfRating,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ════════════════════════════════════════════════════════════
  // FOCUS PATTERNS
  // ════════════════════════════════════════════════════════════

  Future<void> insertFocusPattern(FocusPattern pattern) async {
    final db = await database;
    await db.insert(
      'focus_patterns',
      {
        'id': pattern.id,
        'sessionId': pattern.sessionId,
        'taskId': pattern.taskId,
        'hourOfDay': pattern.hourOfDay,
        'dayOfWeek': pattern.dayOfWeek,
        'durationMinutes': pattern.durationMinutes,
        'completionRate': pattern.completionRate,
        'interruptionCount': pattern.interruptionCount,
        'selfRating': pattern.selfRating,
        'category': pattern.category,
        'priority': pattern.priority,
        'focusScore': pattern.focusScore,
        'createdAt': pattern.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<FocusPattern>> getFocusPatterns() async {
    final db = await database;
    final maps = await db.query('focus_patterns', orderBy: 'createdAt DESC');
    return maps.map((map) {
      return FocusPattern(
        id: map['id'] as String?,
        sessionId: map['sessionId'] as String?,
        taskId: map['taskId'] as String?,
        hourOfDay: map['hourOfDay'] as int,
        dayOfWeek: map['dayOfWeek'] as int,
        durationMinutes: (map['durationMinutes'] as num).toDouble(),
        completionRate: (map['completionRate'] as num).toDouble(),
        interruptionCount: map['interruptionCount'] as int? ?? 0,
        selfRating: map['selfRating'] as int?,
        category: map['category'] as String? ?? 'General',
        priority: map['priority'] as int? ?? 1,
        focusScore: (map['focusScore'] as num).toDouble(),
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
    }).toList();
  }

  /// Replace all local patterns with Firestore data (sync)
  Future<void> replaceAllPatterns(List<FocusPattern> patterns) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('focus_patterns');
      for (final p in patterns) {
        await txn.insert('focus_patterns', {
          'id': p.id,
          'sessionId': p.sessionId,
          'taskId': p.taskId,
          'hourOfDay': p.hourOfDay,
          'dayOfWeek': p.dayOfWeek,
          'durationMinutes': p.durationMinutes,
          'completionRate': p.completionRate,
          'interruptionCount': p.interruptionCount,
          'selfRating': p.selfRating,
          'category': p.category,
          'priority': p.priority,
          'focusScore': p.focusScore,
          'createdAt': p.createdAt.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
