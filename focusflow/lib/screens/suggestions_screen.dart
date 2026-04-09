import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/scheduling_provider.dart';
import '../providers/task_provider.dart';
import '../models/suggestion.dart';
import 'suggestion_detail_screen.dart';

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
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              children: [
                // ML Focus Windows section (shows when enough data exists)
                if (provider.hasMLData && provider.focusWindows.isNotEmpty)
                  _buildFocusWindowsCard(context, provider),

                // Data collection progress (shows when not enough data yet)
                if (!provider.hasMLData)
                  _buildDataCollectionCard(context, provider),

                // Existing suggestions list
                ...List.generate(provider.suggestions.length, (index) {
                  final suggestion = provider.suggestions[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildSuggestionCard(
                      context,
                      suggestion,
                      provider,
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFocusWindowsCard(BuildContext context, SchedulingProvider provider) {
    final dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.primary,
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
              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Your Focus Patterns',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${provider.totalPatterns} sessions analyzed',
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Show each focus window
          ...provider.focusWindows.map((window) {
            final daysStr = window.peakDays.map((d) => dayNames[d]).join(', ');
            final hourStr = _formatHour(window.peakHour);

            final icon = window.quality == 'high'
                ? Icons.bolt
                : window.quality == 'medium'
                    ? Icons.trending_flat
                    : Icons.trending_down;

            final qualityLabel = window.quality == 'high'
                ? 'Peak Focus'
                : window.quality == 'medium'
                    ? 'Moderate Focus'
                    : 'Light Work';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$qualityLabel — $hourStr',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '$daysStr • ${window.sessionCount} sessions • '
                            '${window.avgDurationMinutes.round()} min avg',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Score badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${(window.avgFocusScore * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDataCollectionCard(BuildContext context, SchedulingProvider provider) {
    final sessionsNeeded = 3 - provider.totalPatterns;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
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
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Learning Your Patterns',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete $sessionsNeeded more focus session${sessionsNeeded == 1 ? '' : 's'} '
                  'with a rating to unlock ML-powered scheduling.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: provider.totalPatterns / 3.0,
                    minHeight: 6,
                    backgroundColor: AppColors.divider,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour < 12) return '$hour:00 AM';
    if (hour == 12) return '12:00 PM';
    return '${hour - 12}:00 PM';
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (ctx) => SuggestionDetailScreen(
                      suggestion: suggestion,
                      allSuggestions: provider.suggestions,
                      focusWindows: provider.focusWindows,
                      mlSchedulingTip:
                          provider.getMLRecommendation(suggestion.task),
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            suggestion.task.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary.withValues(alpha: 0.8),
                          size: 22,
                        ),
                      ],
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
                    const SizedBox(height: 8),
                    Text(
                      'Tap for completion odds & conflicts',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
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
          ),
        ],
      ),
    );
  }
}
