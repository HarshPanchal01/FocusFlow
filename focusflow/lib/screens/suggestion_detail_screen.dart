import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/suggestion.dart';
import '../services/ml_service.dart';
import '../services/suggestion_analytics_service.dart';
import '../theme/app_theme.dart';

/// Detail view for a single suggestion: completion estimate, conflicts, ML context.
class SuggestionDetailScreen extends StatefulWidget {
  const SuggestionDetailScreen({
    super.key,
    required this.suggestion,
    required this.allSuggestions,
    required this.focusWindows,
    required this.mlSchedulingTip,
  });

  final Suggestion suggestion;
  final List<Suggestion> allSuggestions;
  final List<MLFocusWindow> focusWindows;
  final String mlSchedulingTip;

  @override
  State<SuggestionDetailScreen> createState() => _SuggestionDetailScreenState();
}

class _SuggestionDetailScreenState extends State<SuggestionDetailScreen> {
  SuggestionInsight? _insight;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final insight = await SuggestionAnalyticsService().analyze(
        suggestion: widget.suggestion,
        allSuggestions: widget.allSuggestions,
        focusWindows: widget.focusWindows,
        mlSchedulingTip: widget.mlSchedulingTip,
      );
      if (mounted) {
        setState(() {
          _insight = insight;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    final timeFmt = DateFormat('EEE, MMM d · h:mm a');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Suggestion details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              s.task.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
            if (s.task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                s.task.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            _metaRow(
              Icons.schedule,
              '${timeFmt.format(s.suggestedStartTime)} – ${DateFormat('h:mm a').format(s.suggestedEndTime)}',
            ),
            _metaRow(Icons.timer_outlined, '${s.task.durationMinutes} min blocked'),
            _metaRow(Icons.category_outlined, s.task.category),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(
                'Could not load analytics: $_error',
                style: const TextStyle(color: Colors.redAccent),
              )
            else if (_insight != null) ...[
              _buildCompletionCard(context, _insight!),
              const SizedBox(height: 16),
              _sectionTitle(context, 'Conflicts with other suggestions'),
              _buildConflicts(context, _insight!),
              const SizedBox(height: 16),
              _sectionTitle(context, 'More context'),
              _buildExtras(context, _insight!),
              const SizedBox(height: 16),
              _sectionTitle(context, 'Scheduling insight'),
              Card(
                elevation: 0,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.divider),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    _insight!.mlSchedulingTip,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
      ),
    );
  }

  Widget _buildCompletionCard(BuildContext context, SuggestionInsight i) {
    final pct = (i.completionProbability * 100).round();
    Color c = Colors.orange;
    if (pct >= 70) c = Colors.green.shade700;
    if (pct < 45) c = Colors.deepOrange;

    return Card(
      elevation: 0,
      color: AppColors.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: i.completionProbability.clamp(0.0, 1.0),
                        strokeWidth: 8,
                        backgroundColor: AppColors.divider,
                        color: AppColors.primary,
                      ),
                      Text(
                        '$pct%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated completion chance',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'How likely a focus block for this task finishes successfully, '
                        'from your history and schedule fit.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              i.completionSummary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c,
                    height: 1.35,
                  ),
            ),
            if (i.focusWindowNote != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    i.suggestedTimeMatchesFocusWindow
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      i.focusWindowNote!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConflicts(BuildContext context, SuggestionInsight i) {
    if (i.conflicts.isEmpty) {
      return Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.divider),
        ),
        child: const ListTile(
          leading: Icon(Icons.check_circle, color: Colors.green),
          title: Text('No time overlap'),
          subtitle: Text(
            'No other suggested tasks share this time window.',
          ),
        ),
      );
    }

    return Column(
      children: i.conflicts.map((c) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
          ),
          child: ListTile(
            leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            title: Text(
              c.otherTaskTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(c.detail),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExtras(BuildContext context, SuggestionInsight i) {
    final rows = <Widget>[];

    if (i.daysUntilDue != null) {
      final d = i.daysUntilDue!;
      final text = d < 0
          ? 'Due date has passed'
          : d == 0
              ? 'Due today'
              : d == 1
                  ? 'Due tomorrow'
                  : 'Due in $d days';
      rows.add(_infoTile(Icons.event, 'Due date', text));
    }

    rows.add(
      _infoTile(
        Icons.analytics_outlined,
        'Data used',
        '${i.taskSessionSampleSize} session${i.taskSessionSampleSize == 1 ? '' : 's'} '
            'for this task · ${i.categoryPatternSampleSize} pattern${i.categoryPatternSampleSize == 1 ? '' : 's'} '
            'in "${widget.suggestion.task.category}"',
      ),
    );

    if (i.avgInterruptionsWhenTaskUsed != null) {
      rows.add(
        _infoTile(
          Icons.do_not_disturb_on_outlined,
          'Avg interruptions (this task)',
          i.avgInterruptionsWhenTaskUsed!.toStringAsFixed(1),
        ),
      );
    }

    rows.add(
      _infoTile(
        Icons.psychology_outlined,
        'Suggestion confidence',
        '${(widget.suggestion.confidence * 100).round()}% · ${widget.suggestion.reason}',
      ),
    );

    return Column(children: rows);
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.divider),
        ),
        child: ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          subtitle: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
