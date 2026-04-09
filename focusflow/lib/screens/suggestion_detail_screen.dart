import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/suggestion.dart';
import '../services/ml_service.dart';
import '../services/suggestion_analytics_service.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Suggestion details'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
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
                    color: colorScheme.onSurface,
                  ),
            ),
            if (s.task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                s.task.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
              ),
            ],
            const SizedBox(height: 16),
            _metaRow(
              context,
              Icons.schedule,
              '${timeFmt.format(s.suggestedStartTime)} – ${DateFormat('h:mm a').format(s.suggestedEndTime)}',
            ),
            _metaRow(context, Icons.timer_outlined, '${s.task.durationMinutes} min blocked'),
            _metaRow(context, Icons.category_outlined, s.task.category),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(
                'Could not load analytics: $_error',
                style: TextStyle(color: colorScheme.error),
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
                color: colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    _insight!.mlSchedulingTip,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.8),
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

  Widget _metaRow(BuildContext context, IconData icon, String text) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
      ),
    );
  }

  Widget _buildCompletionCard(BuildContext context, SuggestionInsight i) {
    final colorScheme = Theme.of(context).colorScheme;
    final pct = (i.completionProbability * 100).round();
    Color c = Colors.orange.shade400;
    if (pct >= 70) c = Colors.green.shade400;
    if (pct < 45) c = Colors.deepOrange.shade300;

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.35)),
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
                        backgroundColor: colorScheme.surfaceContainerHigh,
                        color: colorScheme.primary,
                      ),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
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
                              color: colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'How likely a focus block for this task finishes successfully, '
                        'from your history and schedule fit.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.75),
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
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      i.focusWindowNote!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.75),
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
    final cs = Theme.of(context).colorScheme;
    if (i.conflicts.isEmpty) {
      return Card(
        elevation: 0,
        color: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: ListTile(
          leading: Icon(Icons.check_circle, color: Colors.green.shade400),
          title: Text('No time overlap', style: TextStyle(color: cs.onSurface)),
          subtitle: Text(
            'No other suggested tasks share this time window.',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
          ),
        ),
      );
    }

    return Column(
      children: i.conflicts.map((c) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: cs.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.orange.withValues(alpha: 0.55)),
          ),
          child: ListTile(
            leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            title: Text(
              c.otherTaskTitle,
              style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
            ),
            subtitle: Text(
              c.detail,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8)),
            ),
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
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            elevation: 0,
            color: cs.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: ListTile(
              leading: Icon(icon, color: cs.primary),
              title: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.65),
                ),
              ),
              subtitle: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
