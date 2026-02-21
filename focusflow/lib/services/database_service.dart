import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:math';
import '../models/task.dart';
import '../models/session.dart';

/// Local SQLite database service for task CRUD.
///
/// This is the offline-first data layer. Issue #5 (Data Sync) will
/// add a Firestore layer on top that calls these same methods and
/// syncs changes when connectivity is available.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  static const String _tableName = 'tasks';
  static const int _dbVersion = 3;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'focusflow.db');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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
    // If creating fresh (version 3), also create sessions table with all columns
    await _createSessionsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createSessionsTable(db);
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE sessions ADD COLUMN interruptionCount INTEGER DEFAULT 0');
      } catch (e) {
        print('Error adding column: $e');
      }
    }
  }

  Future<void> _createSessionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER,
        startTime TEXT NOT NULL,
        duration INTEGER NOT NULL,
        isCompleted INTEGER DEFAULT 0,
        interruptionCount INTEGER DEFAULT 0,
        FOREIGN KEY(taskId) REFERENCES tasks(id)
      )
    ''');
  }

  // --------------- CREATE ---------------

  Future<int> insertTask(Task task) async {
    final db = await database;
    return await db.insert(
      _tableName,
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --------------- READ ---------------

  /// Get all tasks, optionally filtered and sorted.
  Future<List<Task>> getTasks({
    bool? isCompleted,
    String? category,
    String orderBy = 'dueDate ASC',
  }) async {
    final db = await database;

    // Build WHERE clause dynamically
    final where = <String>[];
    final whereArgs = <dynamic>[];

    if (isCompleted != null) {
      where.add('isCompleted = ?');
      whereArgs.add(isCompleted ? 1 : 0);
    }
    if (category != null) {
      where.add('category = ?');
      whereArgs.add(category);
    }

    final maps = await db.query(
      _tableName,
      where: where.isNotEmpty ? where.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderBy,
    );

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  /// Get a single task by ID.
  Future<Task?> getTaskById(int id) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Task.fromMap(maps.first);
  }

  // --------------- UPDATE ---------------

  Future<int> updateTask(Task task) async {
    final db = await database;
    return await db.update(
      _tableName,
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  /// Quick toggle for completion status.
  Future<int> toggleTaskCompletion(int id, bool isCompleted) async {
    final db = await database;
    return await db.update(
      _tableName,
      {
        'isCompleted': isCompleted ? 1 : 0,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --------------- DELETE ---------------

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all completed tasks (useful for a "clear completed" action).
  Future<int> deleteCompletedTasks() async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'isCompleted = ?',
      whereArgs: [1],
    );
  }

  // --------------- UTILITIES ---------------

  Future<int> getTaskCount({bool? isCompleted}) async {
    final db = await database;
    final where =
        isCompleted != null ? 'WHERE isCompleted = ${isCompleted ? 1 : 0}' : '';
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName $where');
    return result.first['count'] as int;
  }

  // --------------- SESSIONS ---------------

  Future<int> insertSession(Session session) async {
    final db = await database;
    return await db.insert(
      'sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Session>> getSessions() async {
    final db = await database;
    final maps = await db.query('sessions', orderBy: 'startTime DESC');
    return maps.map((map) => Session.fromMap(map)).toList();
  }

  Future<List<Session>> getSessionsForRange(DateTime start, DateTime end) async {
    final db = await database;
    final maps = await db.query(
      'sessions',
      where: 'startTime >= ? AND startTime <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'startTime ASC',
    );
    return maps.map((map) => Session.fromMap(map)).toList();
  }

  Future<void> seedDummyData() async {
    final db = await database;
    final random = Random();
    final now = DateTime.now();
    
    // Generate sessions for the last 7 days
    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: i));
      // Random number of sessions per day (0 to 4)
      final sessionCount = random.nextInt(5);
      
      for (int j = 0; j < sessionCount; j++) {
        final duration = (random.nextInt(50) + 10) * 60; // 10 to 60 mins in seconds
        final startTime = day.subtract(Duration(hours: random.nextInt(12) + 8)); // Random time between 8am and 8pm
        
        final session = Session(
          startTime: startTime,
          duration: duration,
          isCompleted: true,
          interruptionCount: random.nextInt(3),
        );
        
        await insertSession(session);
      }
    }
    print('Seeded dummy data.');
  }

  Future<void> seedDummyTasks() async {
    final random = Random();
    final categories = ['Work', 'Personal', 'Health', 'Errands', 'Coursework'];
    final titles = [
      'Finish Project Report',
      'Grocery Shopping',
      'Workout (Leg Day)',
      'Call Mom',
      'Review Pull Requests',
      'Update Resume',
      'Clean Apartment',
      'Read Book',
    ];

    for (int i = 0; i < 5; i++) {
      final title = titles[random.nextInt(titles.length)];
      final category = categories[random.nextInt(categories.length)];
      final priority = Priority.values[random.nextInt(Priority.values.length)];
      
      final task = Task(
        title: '$title ${random.nextInt(100)}',
        description: 'Generated dummy task',
        priority: priority,
        durationMinutes: (random.nextInt(4) + 1) * 15, // 15, 30, 45, 60
        category: category,
        dueDate: DateTime.now().add(Duration(days: random.nextInt(7))),
      );
      
      await insertTask(task);
    }
    print('Seeded dummy tasks.');
  }

  /// Close the database (call on app dispose if needed).
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
