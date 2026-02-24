import 'package:flutter/foundation.dart';
import '../models/suggestion.dart';
import '../models/task.dart';
import '../services/scheduling_service.dart';

/// Provider for managing scheduling suggestions and adaptive scheduling state.
class SchedulingProvider extends ChangeNotifier {
  final SchedulingService _schedulingService = SchedulingService();

  List<Suggestion> _suggestions = [];
  bool _isLoading = false;
  DateTime? _lastUpdated;

  List<Suggestion> get suggestions => _suggestions;
  bool get isLoading => _isLoading;
  DateTime? get lastUpdated => _lastUpdated;

  /// Load and generate scheduling suggestions
  Future<void> loadSuggestions({List<Task>? tasks}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _suggestions = await _schedulingService.generateSuggestions(tasks: tasks);
      _lastUpdated = DateTime.now();
    } catch (e) {
      debugPrint('Error loading suggestions: $e');
      _suggestions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Accept a suggestion (update task with suggested time)
  Future<void> acceptSuggestion(Suggestion suggestion) async {
    // For now, we just mark it as accepted in the UI
    // In the future, this could update the task's scheduled time
    _suggestions.remove(suggestion);
    notifyListeners();
    
    // TODO: Could add a "scheduledTime" field to Task model
    // and update it here when accepting a suggestion
  }

  /// Override/dismiss a suggestion
  void dismissSuggestion(Suggestion suggestion) {
    _suggestions.remove(suggestion);
    notifyListeners();
  }

  /// Refresh suggestions (regenerate)
  Future<void> refreshSuggestions() async {
    await loadSuggestions();
  }
}