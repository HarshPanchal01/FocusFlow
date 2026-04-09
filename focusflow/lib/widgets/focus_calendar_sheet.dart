import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../providers/insights_provider.dart';
import '../theme/app_theme.dart';

String _localDayKey(DateTime t) {
  final d = t.toLocal();
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// Bottom sheet: month grid with days that had focus sessions highlighted.
Future<void> showFocusCalendarSheet(
  BuildContext context,
  InsightsProvider insights,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _FocusCalendarSheet(insights: insights),
  );
}

class _FocusCalendarSheet extends StatefulWidget {
  const _FocusCalendarSheet({required this.insights});

  final InsightsProvider insights;

  @override
  State<_FocusCalendarSheet> createState() => _FocusCalendarSheetState();
}

class _FocusCalendarSheetState extends State<_FocusCalendarSheet> {
  late DateTime _visibleMonth;
  Set<String> _activeDays = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _visibleMonth = DateTime(n.year, n.month);
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    setState(() => _loading = true);
    final keys = await widget.insights.fetchActiveDayKeysForMonth(
      _visibleMonth.year,
      _visibleMonth.month,
    );
    if (!mounted) return;
    setState(() {
      _activeDays = keys;
      _loading = false;
    });
  }

  void _prevMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
    _loadMonth();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    if (next.year > now.year ||
        (next.year == now.year && next.month > now.month)) {
      return;
    }
    setState(() => _visibleMonth = next);
    _loadMonth();
  }

  @override
  Widget build(BuildContext context) {
    final title = DateFormat.yMMMM().format(_visibleMonth);
    final now = DateTime.now();
    final canGoNext = _visibleMonth.year < now.year ||
        (_visibleMonth.year == now.year && _visibleMonth.month < now.month);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                onPressed: _prevMonth,
                icon: const Icon(Icons.chevron_left),
                color: AppColors.primary,
                tooltip: 'Previous month',
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              IconButton(
                onPressed: canGoNext ? _nextMonth : null,
                icon: const Icon(Icons.chevron_right),
                color: AppColors.primary,
                tooltip: 'Next month',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Days with at least one focus session',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            _MonthGrid(
              year: _visibleMonth.year,
              month: _visibleMonth.month,
              activeDays: _activeDays,
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.year,
    required this.month,
    required this.activeDays,
  });

  final int year;
  final int month;
  final Set<String> activeDays;

  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leading = first.weekday - 1;
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;

    return Column(
      children: [
        Row(
          children: _weekdayLabels
              .map(
                (l) => Expanded(
                  child: Text(
                    l,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.1,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            final dayNum = index - leading + 1;
            if (dayNum < 1 || dayNum > daysInMonth) {
              return const SizedBox.shrink();
            }
            final date = DateTime(year, month, dayNum);
            final key = _localDayKey(date);
            final hasFocus = activeDays.contains(key);
            final isToday = _isToday(date);

            return Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hasFocus
                    ? AppColors.primary.withValues(alpha: 0.85)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: isToday
                    ? Border.all(color: AppColors.secondary, width: 2)
                    : null,
              ),
              child: Text(
                '$dayNum',
                style: TextStyle(
                  fontWeight: hasFocus ? FontWeight.w600 : FontWeight.w500,
                  color: hasFocus ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
