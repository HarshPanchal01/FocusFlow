import 'package:flutter/foundation.dart';
import '../models/suggestion.dart';
import '../models/task.dart';
import '../services/scheduling_service.dart';
import '../services/ml_service.dart';

/// Provider for scheduling suggestions + ML focus window insights.
///
/// Combines two data sources:
///   1. Rule-based suggestions from SchedulingService (existing)
///   2. ML-clustered focus windows from MLService (new)
///
/// The ML windows show the user when they're historically most productive,
/// while the suggestions recommend specific tasks for specific time slots.
class SchedulingProvider extends ChangeNotifier {
  final SchedulingService _schedulingService = SchedulingService();
  final MLService _mlService = MLService();

  List<Suggestion> _suggestions = [];
  List<MLFocusWindow> _focusWindows = [];
  bool _isLoading = false;
  DateTime? _lastUpdated;
  int _totalPatterns = 0; // how many data points ML has to work with

  List<Suggestion> get suggestions => _suggestions;
  List<MLFocusWindow> get focusWindows => _focusWindows;
  bool get isLoading => _isLoading;
  DateTime? get lastUpdated => _lastUpdated;
  int get totalPatterns => _totalPatterns;

  /// Whether we have enough data for ML clustering (need at least 3 sessions)
  bool get hasMLData => _totalPatterns >= 3;

  /// Load both rule-based suggestions and ML focus windows
  Future<void> loadSuggestions({List<Task>? tasks}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load rule-based suggestions (existing logic)
      _suggestions = await _schedulingService.generateSuggestions(tasks: tasks);

      // Load ML focus windows (new)
      _focusWindows = await _mlService.identifyFocusWindows();
      _totalPatterns = await _mlService.getPatternCount();

      _lastUpdated = DateTime.now();
    } catch (e) {
      debugPrint('Error loading suggestions: $e');
      _suggestions = [];
      _focusWindows = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get ML recommendation for a specific task
  String getMLRecommendation(Task task) {
    return _mlService.getRecommendation(_focusWindows, task);
  }

  /// Accept a suggestion
  Future<void> acceptSuggestion(Suggestion suggestion) async {
    _suggestions.remove(suggestion);
    notifyListeners();
  }

  /// Dismiss a suggestion
  void dismissSuggestion(Suggestion suggestion) {
    _suggestions.remove(suggestion);
    notifyListeners();
  }

  /// Refresh everything
  Future<void> refreshSuggestions() async {
    await loadSuggestions();
  }
}
