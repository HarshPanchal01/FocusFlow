import 'package:flutter/foundation.dart';
import '../models/session.dart';
import '../services/data_sync_service.dart';

class InsightsProvider extends ChangeNotifier {
  final DataSyncService _dbService = DataSyncService();

  // State
  Map<int, double> _dailyTotals = {}; // 1 (Mon) -> 7 (Sun) : Total Hours
  double _weeklyTotalHours = 0.0;
  int _currentStreakDays = 0;
  /// Consecutive calendar days in the **current year** (Jan 1 → today), same rules as [computeConsecutiveDayStreak] but stops before Jan 1.
  int _currentYearStreakDays = 0;
  /// Mon–Sun this week with any focus time (>0 h in [dailyTotals]).
  int _activeDaysThisWeek = 0;
  bool _isLoading = false;

  // Getters
  Map<int, double> get dailyTotals => _dailyTotals;
  double get weeklyTotalHours => _weeklyTotalHours;
  /// Consecutive **calendar days** (local) with ≥1 session—can span multiple weeks.
  int get currentStreakDays => _currentStreakDays;
  /// Consecutive days **in the current calendar year** only (resets across New Year).
  int get currentYearStreakDays => _currentYearStreakDays;
  int get activeDaysThisWeek => _activeDaysThisWeek;
  bool get isLoading => _isLoading;

  static String _dayKeyLocal(DateTime t) {
    final d = t.toLocal();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  static DateTime _dateOnlyLocal(DateTime t) {
    final l = t.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  static DateTime _previousCalendarDayLocal(DateTime dateOnlyLocal) {
    final p = dateOnlyLocal.subtract(const Duration(days: 1));
    return DateTime(p.year, p.month, p.day);
  }

  /// True if [startTime] falls on a calendar day between this week's Mon–Sun (local).
  static bool _sessionOccursOnWeekdayInRange(
    DateTime startTime,
    DateTime weekMonday,
  ) {
    final t = startTime.toLocal();
    final d = DateTime(t.year, t.month, t.day);
    final mon = DateTime(
      weekMonday.year,
      weekMonday.month,
      weekMonday.day,
    );
    final sun = mon.add(const Duration(days: 6));
    return !d.isBefore(mon) && !d.isAfter(sun);
  }

  /// Longest run of consecutive calendar days ending at the latest day ≤ today that has
  /// a session (not limited to Mon–Sun). [sessions] should already exclude future times.
  static int computeConsecutiveDayStreak(List<Session> sessions) {
    if (sessions.isEmpty) return 0;
    final days = <String>{};
    for (final s in sessions) {
      if (s.duration <= 0) continue;
      days.add(_dayKeyLocal(s.startTime));
    }
    if (days.isEmpty) return 0;

    final today = _dateOnlyLocal(DateTime.now());

    // Latest day ≤ today that has a session (start of the chain we measure backward).
    DateTime? anchor;
    var scan = today;
    for (var i = 0; i < 400; i++) {
      if (days.contains(_dayKeyLocal(scan))) {
        anchor = scan;
        break;
      }
      scan = _previousCalendarDayLocal(scan);
    }
    if (anchor == null) return 0;

    var streak = 0;
    var cursor = anchor;
    while (days.contains(_dayKeyLocal(cursor))) {
      streak++;
      cursor = _previousCalendarDayLocal(cursor);
    }
    return streak;
  }

  /// Like [computeConsecutiveDayStreak], but only counts days on or after Jan 1 of [calendarYear] (local).
  static int computeConsecutiveDayStreakWithinYear(
    List<Session> sessions,
    int calendarYear,
  ) {
    if (sessions.isEmpty) return 0;
    final days = <String>{};
    for (final s in sessions) {
      if (s.duration <= 0) continue;
      days.add(_dayKeyLocal(s.startTime));
    }
    if (days.isEmpty) return 0;

    final today = _dateOnlyLocal(DateTime.now());
    final yearStart = DateTime(calendarYear, 1, 1);

    DateTime? anchor;
    var scan = today;
    for (var i = 0; i < 400; i++) {
      if (scan.isBefore(yearStart)) break;
      if (days.contains(_dayKeyLocal(scan))) {
        anchor = scan;
        break;
      }
      scan = _previousCalendarDayLocal(scan);
    }
    if (anchor == null) return 0;

    var streak = 0;
    var cursor = anchor;
    while (true) {
      if (cursor.isBefore(yearStart)) break;
      if (!days.contains(_dayKeyLocal(cursor))) break;
      streak++;
      cursor = _previousCalendarDayLocal(cursor);
    }
    return streak;
  }

  // Load data for the current week
  Future<void> loadWeeklyInsights() async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      // Calculate start of week (Monday) at 00:00:00
      // subtract (weekday - 1) days
      final startOfWeek = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      
      // Calculate end of week (Sunday) at 23:59:59
      final endOfWeek = startOfWeek
          .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      final todayLocal = DateTime(now.year, now.month, now.day);
      final streakLookbackStart = todayLocal.subtract(const Duration(days: 400));
      // Must include end of **Sunday** — not just “end of today”. Otherwise sessions
      // seeded on Fri–Sun (same ISO week, but still in the future) never load.
      final fetchEnd = endOfWeek;

      debugPrint('Loading insights for range: $startOfWeek to $endOfWeek');

      final sessionsInFetchWindow =
          await _dbService.getSessionsForRange(streakLookbackStart, fetchEnd);

      // Streak only counts days that already happened (no future-dated sessions).
      final nowInstant = DateTime.now();
      final sessionsForStreak = sessionsInFetchWindow
          .where((s) => !s.startTime.isAfter(nowInstant))
          .toList();
      _currentStreakDays = computeConsecutiveDayStreak(sessionsForStreak);
      _currentYearStreakDays =
          computeConsecutiveDayStreakWithinYear(sessionsForStreak, now.year);

      // Weekly chart: every session in this ISO week, including future days in the same week.
      final sessions = sessionsInFetchWindow
          .where((s) => _sessionOccursOnWeekdayInRange(s.startTime, startOfWeek))
          .toList();
      debugPrint('Fetched ${sessions.length} sessions for this week.');

      // Reset totals
      _dailyTotals = {
        1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0, 6: 0.0, 7: 0.0
      };
      _weeklyTotalHours = 0.0;
      _activeDaysThisWeek = 0;

      // Aggregate sessions
      for (final session in sessions) {
        // Only count completed sessions?
        // Let's count all sessions for now, or just completed ones based on requirements.
        // Usually, partial sessions count as "focus time" too.
        // But Issue #6 says "Total Focus Time", so partials should count.
        // Wait, Session model has `duration` which is what we tracked.
        
        // Use local calendar so UTC-stored times bucket into the right weekday.
        final day = session.startTime.toLocal().weekday; // 1=Mon, 7=Sun
        final hours = session.duration / 3600.0;
        
        _dailyTotals[day] = (_dailyTotals[day] ?? 0.0) + hours;
        _weeklyTotalHours += hours;
      }

      _activeDaysThisWeek =
          _dailyTotals.values.where((h) => h > 0).length;

      debugPrint('Daily Totals (Hours): $_dailyTotals');
      debugPrint('Weekly Total: $_weeklyTotalHours hours');
      debugPrint(
        'Active days this week: $_activeDaysThisWeek, streak: $_currentStreakDays, year streak: $_currentYearStreakDays',
      );

    } catch (e) {
      debugPrint('Error loading insights: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Local `yyyy-MM-dd` keys for days in [year]/[month] that have ≥1 session with duration > 0.
  Future<Set<String>> fetchActiveDayKeysForMonth(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    final sessions = await _dbService.getSessionsForRange(start, end);
    final keys = <String>{};
    for (final s in sessions) {
      if (s.duration <= 0) continue;
      keys.add(_dayKeyLocal(s.startTime));
    }
    return keys;
  }
}
