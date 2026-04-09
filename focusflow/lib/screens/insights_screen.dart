import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/insights_provider.dart';
import '../theme/app_theme.dart';
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
    // Load insights when the screen is first shown
    Future.microtask(() => context.read<InsightsProvider>().loadWeeklyInsights());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return RefreshIndicator(
              onRefresh: () =>
                  context.read<InsightsProvider>().loadWeeklyInsights(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: AppColors.textPrimary,
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
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pull down to refresh · data is read from local storage and merged with cloud when online.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.textPrimary,
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
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
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
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
                  const Text(
                    'Total Focus Time',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${provider.weeklyTotalHours.toStringAsFixed(1)} hrs',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'This Week',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: Colors.white24,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Day streak',
                    style: TextStyle(
                      color: Colors.white70,
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
                        color: streak > 0 ? Colors.amberAccent : Colors.white54,
                        size: 28,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$streak',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    streakCaption,
                    style: const TextStyle(
                      color: Colors.white70,
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
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$year streak',
                    style: const TextStyle(
                      color: Colors.white70,
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
                        color: yearStreak > 0 ? Colors.amberAccent : Colors.white54,
                        size: 24,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$yearStreak',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    yearCaption,
                    style: const TextStyle(
                      color: Colors.white70,
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

  /// Consecutive days in [year] from Jan 1 through today (same session rules as day streak).
  String _yearStreakSubtitle(int yearStreak, int year) {
    if (yearStreak == 0) {
      return 'Consecutive days in $year (Jan 1 → today)';
    }
    return '$yearStreak ${yearStreak == 1 ? 'day' : 'days'} in a row · Jan 1 → today';
  }

  /// Streak = consecutive calendar days (can span weeks); [daysThisWeek] is separate.
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
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (provider.dailyTotals.values.reduce((a, b) => a > b ? a : b) * 1.2).clamp(1.0, 24.0),
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
                const style = TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                );
                String text;
                switch (value.toInt()) {
                  case 1: text = 'M'; break;
                  case 2: text = 'T'; break;
                  case 3: text = 'W'; break;
                  case 4: text = 'T'; break;
                  case 5: text = 'F'; break;
                  case 6: text = 'S'; break;
                  case 7: text = 'S'; break;
                  default: text = '';
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Text(text, style: style),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (index) {
          final day = index + 1;
          final value = provider.dailyTotals[day] ?? 0.0;
          return BarChartGroupData(
            x: day,
            barRods: [
              BarChartRodData(
                toY: value,
                color: value > 0 ? AppColors.secondary : Colors.grey.shade300,
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
