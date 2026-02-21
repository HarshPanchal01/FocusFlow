import 'package:flutter/foundation.dart';
import '../models/session.dart';
import '../services/database_service.dart';

class InsightsProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  // State
  Map<int, double> _dailyTotals = {}; // 1 (Mon) -> 7 (Sun) : Total Hours
  double _weeklyTotalHours = 0.0;
  bool _isLoading = false;

  // Getters
  Map<int, double> get dailyTotals => _dailyTotals;
  double get weeklyTotalHours => _weeklyTotalHours;
  bool get isLoading => _isLoading;

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

      debugPrint('Loading insights for range: $startOfWeek to $endOfWeek');

      final sessions = await _dbService.getSessionsForRange(startOfWeek, endOfWeek);
      debugPrint('Fetched ${sessions.length} sessions for this week.');

      // Reset totals
      _dailyTotals = {
        1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0, 6: 0.0, 7: 0.0
      };
      _weeklyTotalHours = 0.0;

      // Aggregate sessions
      for (final session in sessions) {
        // Only count completed sessions?
        // Let's count all sessions for now, or just completed ones based on requirements.
        // Usually, partial sessions count as "focus time" too.
        // But Issue #6 says "Total Focus Time", so partials should count.
        // Wait, Session model has `duration` which is what we tracked.
        
        final day = session.startTime.weekday; // 1=Mon, 7=Sun
        final hours = session.duration / 3600.0;
        
        _dailyTotals[day] = (_dailyTotals[day] ?? 0.0) + hours;
        _weeklyTotalHours += hours;
      }

      debugPrint('Daily Totals (Hours): $_dailyTotals');
      debugPrint('Weekly Total: $_weeklyTotalHours hours');

    } catch (e) {
      debugPrint('Error loading insights: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
