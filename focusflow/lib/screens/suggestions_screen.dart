import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/scheduling_provider.dart';
import '../providers/task_provider.dart';
import '../models/suggestion.dart';

class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  @override
  void initState() {
    super.initState();
    // Load suggestions when screen appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final schedulingProvider = context.read<SchedulingProvider>();
      final taskProvider = context.read<TaskProvider>();
      
      // Load tasks first if not loaded
      if (taskProvider.tasks.isEmpty) {
        taskProvider.loadTasks().then((_) {
          if (mounted) {
            schedulingProvider.loadSuggestions(tasks: taskProvider.incompleteTasks);
          }
        });
      } else {
        schedulingProvider.loadSuggestions(tasks: taskProvider.incompleteTasks);
      }
    });
  }

  String _formatSuggestionType(SuggestionType type) {
    switch (type) {
      case SuggestionType.heavyTask:
        return 'Heavy Task';
      case SuggestionType.lightTask:
        return 'Light Task';
      case SuggestionType.collaboration:
        return 'Collaboration';
      case SuggestionType.urgent:
        return 'Urgent';
    }
  }

  String _formatTimeRange(DateTime start, DateTime end) {
    final dateFormat = DateFormat('MMM d');
    final timeFormat = DateFormat('h:mm a');
    
    final now = DateTime.now();
    final isToday = start.day == now.day && 
                   start.month == now.month && 
                   start.year == now.year;
    
    final dateStr = isToday ? 'Today' : dateFormat.format(start);
    final timeStr = '${timeFormat.format(start)} - ${timeFormat.format(end)}';
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final durationStr = hours > 0 
        ? '$hours ${hours == 1 ? 'hr' : 'hrs'}'
        : '$minutes min';
    
    return '$durationStr · $dateStr $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        toolbarHeight: 0, // Hide the AppBar content
      ),
      body: Consumer<SchedulingProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.suggestions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No suggestions available',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete some focus sessions to get personalized scheduling suggestions',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => provider.refreshSuggestions(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.refreshSuggestions(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              itemCount: provider.suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final suggestion = provider.suggestions[index];
                return _buildSuggestionCard(context, suggestion, provider);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuggestionCard(
    BuildContext context,
    Suggestion suggestion,
    SchedulingProvider provider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            spreadRadius: 0.5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                child: Text(
                  _formatSuggestionType(suggestion.type),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Spacer(),
              // Confidence indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: suggestion.confidence > 0.7 
                      ? Colors.green.withValues(alpha: 0.2)
                      : suggestion.confidence > 0.4
                          ? Colors.orange.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(suggestion.confidence * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: suggestion.confidence > 0.7 
                        ? Colors.green.shade700
                        : suggestion.confidence > 0.4
                            ? Colors.orange.shade700
                            : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            suggestion.task.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTimeRange(
              suggestion.suggestedStartTime,
              suggestion.suggestedEndTime,
            ),
            style: const TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            suggestion.reason,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          if (suggestion.task.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              suggestion.task.description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    provider.acceptSuggestion(suggestion);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Accepted suggestion for "${suggestion.task.title}"'),
                      ),
                    );
                  },
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(
                      color: AppColors.secondary,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    provider.dismissSuggestion(suggestion);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Suggestion dismissed')),
                    );
                  },
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
