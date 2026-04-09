import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/insights_provider.dart';
import '../widgets/focus_calendar_sheet.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => context.read<InsightsProvider>().loadWeeklyInsights(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return RefreshIndicator(
              onRefresh: () =>
                  context.read<InsightsProvider>().loadWeeklyInsights(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              'Weekly Insights',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: () {
                              showFocusCalendarSheet(
                                context,
                                context.read<InsightsProvider>(),
                              );
                            },
                            icon: const Icon(Icons.calendar_month_rounded),
                            tooltip: 'Focus days this month',
                            style: IconButton.styleFrom(
                              foregroundColor: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pull down to refresh · data is read from local storage '
                        'and merged with cloud when online.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Consumer<InsightsProvider>(
                        builder: (context, provider, _) {
                          return _buildSummaryCard(context, provider);
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Daily Focus Activity',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 280,
                        child: Consumer<InsightsProvider>(
                          builder: (context, provider, _) {
                            if (provider.isLoading) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (provider.weeklyTotalHours == 0) {
                              return Center(
                                child: Text(
                                  'No focus data for this week yet.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              );
                            }
                            return _buildWeeklyChart(context, provider);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, InsightsProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final streak = provider.currentStreakDays;
    final yearStreak = provider.currentYearStreakDays;
    final weekDays = provider.activeDaysThisWeek;
    final streakCaption = _streakSubtitle(streak, weekDays);
    final year = DateTime.now().year;
    final yearCaption = _yearStreakSubtitle(yearStreak, year);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Focus Time',
                    style: TextStyle(
                      color: colorScheme.onPrimary.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${provider.weeklyTotalHours.toStringAsFixed(1)} hrs',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This Week',
                    style: TextStyle(
                      color: colorScheme.onPrimary.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: colorScheme.onPrimary.withValues(alpha: 0.3),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Day streak',
                    style: TextStyle(
                      color: colorScheme.onPrimary.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: streak > 0
                            ? Colors.amberAccent
                            : colorScheme.onPrimary.withValues(alpha: 0.5),
                        size: 28,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$streak',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    streakCaption,
                    style: TextStyle(
                      color: colorScheme.onPrimary.withValues(alpha: 0.85),
                      fontSize: 10,
                      height: 1.25,
                    ),
                    textAlign: TextAlign.end,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 1,
                    width: 96,
                    color: colorScheme.onPrimary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$year streak',
                    style: TextStyle(
                      color: colorScheme.onPrimary.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.date_range,
                        color: yearStreak > 0
                            ? Colors.amberAccent
                            : colorScheme.onPrimary.withValues(alpha: 0.5),
                        size: 24,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$yearStreak',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    yearCaption,
                    style: TextStyle(
                      color: colorScheme.onPrimary.withValues(alpha: 0.85),
                      fontSize: 10,
                      height: 1.25,
                    ),
                    textAlign: TextAlign.end,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _yearStreakSubtitle(int yearStreak, int year) {
    if (yearStreak == 0) {
      return 'Consecutive days in $year (Jan 1 → today)';
    }
    return '$yearStreak ${yearStreak == 1 ? 'day' : 'days'} in a row · Jan 1 → today';
  }

  String _streakSubtitle(int streak, int daysThisWeek) {
    if (streak == 0) {
      return 'Consecutive days with a session (not week-only)';
    }
    if (daysThisWeek > 0) {
      return '$streak ${streak == 1 ? 'day' : 'days'} in a row · '
          '$daysThisWeek with focus this week';
    }
    return '$streak consecutive ${streak == 1 ? 'day' : 'days'}';
  }

  Widget _buildWeeklyChart(BuildContext context, InsightsProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxVal = provider.dailyTotals.values.isEmpty
        ? 1.0
        : (provider.dailyTotals.values.reduce((a, b) => a > b ? a : b) * 1.2)
            .clamp(1.0, 24.0);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toStringAsFixed(1)} hrs',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final style = TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                );
                String text;
                switch (value.toInt()) {
                  case 1:
                    text = 'M';
                    break;
                  case 2:
                    text = 'T';
                    break;
                  case 3:
                    text = 'W';
                    break;
                  case 4:
                    text = 'T';
                    break;
                  case 5:
                    text = 'F';
                    break;
                  case 6:
                    text = 'S';
                    break;
                  case 7:
                    text = 'S';
                    break;
                  default:
                    text = '';
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Text(text, style: style),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (index) {
          final day = index + 1;
          final value = provider.dailyTotals[day] ?? 0.0;
          return BarChartGroupData(
            x: day,
            barRods: [
              BarChartRodData(
                toY: value,
                color: value > 0
                    ? colorScheme.secondary
                    : colorScheme.onSurface.withValues(alpha: 0.12),
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }
}
