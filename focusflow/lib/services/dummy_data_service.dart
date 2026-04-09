import 'package:flutter/foundation.dart';
import '../models/session.dart';
import 'data_sync_service.dart';

/// Dev/test helpers: inserts completed sessions into SQLite (+ Firestore when online)
/// so Insights streaks and charts have data to display.
class DummyDataService {
  DummyDataService({DataSyncService? db}) : _db = db ?? DataSyncService();

  final DataSyncService _db;

  /// One completed session per day for [dayCount] consecutive calendar days ending **today**,
  /// at different hours so weekly bars differ. Good for verifying **week streak** and charts.
  Future<int> seedConsecutiveDayStreak({int dayCount = 7, String? taskId}) async {
    final today = _dateOnly(DateTime.now());
    var inserted = 0;
    for (var i = 0; i < dayCount; i++) {
      final day = today.subtract(Duration(days: i));
      final hour = 8 + (i % 8);
      final minute = (i * 7) % 60;
      final start = DateTime(day.year, day.month, day.day, hour, minute);
      final session = Session(
        taskId: taskId,
        startTime: start,
        duration: 1200 + i * 120,
        isCompleted: true,
        interruptionCount: i % 3,
        selfRating: 3 + (i % 3),
      );
      await _db.insertSession(session);
      inserted++;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    debugPrint('DummyDataService: inserted $inserted streak-friendly sessions');
    return inserted;
  }

  /// Extra sessions on **non-consecutive** older days + an extra slot on **today**
  /// so you see multiple bars and history-like data (suggestions / analytics).
  Future<int> seedScatterHistory({String? taskId}) async {
    final today = _dateOnly(DateTime.now());
    final offsets = <int>[10, 17, 24, 31, 45];
    var inserted = 0;
    for (var k = 0; k < offsets.length; k++) {
      final day = today.subtract(Duration(days: offsets[k]));
      final start = DateTime(day.year, day.month, day.day, 14 + k, 15);
      await _db.insertSession(
        Session(
          taskId: taskId,
          startTime: start,
          duration: 900 + k * 100,
          isCompleted: true,
          interruptionCount: 1,
          selfRating: 4,
        ),
      );
      inserted++;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await _db.insertSession(
      Session(
        taskId: taskId,
        startTime: DateTime(today.year, today.month, today.day, 18, 0),
        duration: 1800,
        isCompleted: true,
        interruptionCount: 0,
        selfRating: 5,
      ),
    );
    inserted++;
    debugPrint('DummyDataService: inserted $inserted scattered history sessions');
    return inserted;
  }

  /// Full pack: consecutive days for streak + scatter for “previous completed” variety.
  Future<int> seedStreakTestPack({int consecutiveDays = 7, String? taskId}) async {
    final a = await seedConsecutiveDayStreak(dayCount: consecutiveDays, taskId: taskId);
    final b = await seedScatterHistory(taskId: taskId);
    return a + b;
  }

  /// One completed session on **each** day of the **current ISO week** (Mon–Sun).
  ///
  /// Use this when you want **every bar** on the Insights weekly chart to show data.
  /// (A plain “7 days back from today” streak often puts Fri–Sun in the *previous* week,
  /// so this week’s Fri–Sun bars stay empty — that is expected for the streak seed.)
  Future<int> seedEveryDayOfCurrentIsoWeek({String? taskId}) async {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final monday = today.subtract(Duration(days: now.weekday - 1));
    var inserted = 0;
    for (var i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final hour = 9 + (i % 6);
      final start = DateTime(day.year, day.month, day.day, hour, 10 + i);
      await _db.insertSession(
        Session(
          taskId: taskId,
          startTime: start,
          duration: 900 + i * 60,
          isCompleted: true,
          interruptionCount: i % 2,
          selfRating: 4,
        ),
      );
      inserted++;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    debugPrint('DummyDataService: seeded all 7 days of current week ($inserted sessions)');
    return inserted;
  }

  static DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);
}
