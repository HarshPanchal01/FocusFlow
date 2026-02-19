import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/task_provider.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // This week's completion
            const Text(
              "This week's completion",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _WeeklyCompletionCard(),
            const SizedBox(height: 24),
            // Interruptions Pattern
            const Text(
              'Interruptions Pattern',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _InterruptionsCard(),
            const SizedBox(height: 24),
            // Most Productive Hours
            const Text(
              'Most Productive Hours',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _ProductiveHoursCard(),
          ],
        ),
      ),
    );
  }
}

/// Card that shows this week's completion progress based on tasks created and completed this week.
class _WeeklyCompletionCard extends StatelessWidget {
  const _WeeklyCompletionCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, provider, _) {
        // Get current week's start and end
        final now = DateTime.now();
        final weekStart = DateTime(
          now.year,
          now.month,
          now.day - (now.weekday - 1),
        );
        final weekEnd = weekStart.add(const Duration(days: 7));

        // Filter tasks created this week
        final tasksThisWeek = provider.tasks
            .where(
              (task) =>
                  task.createdAt.isAfter(
                    weekStart.subtract(const Duration(seconds: 1)),
                  ) &&
                  task.createdAt.isBefore(weekEnd),
            )
            .toList();
        final totalTasks = tasksThisWeek.length;
        final completedTasks = tasksThisWeek.where((t) => t.isCompleted).length;
        final completionPercent = totalTasks == 0
            ? 0.0
            : completedTasks / totalTasks;

        // TODO: Calculate percentChange vs last week if needed
        final int percentChange = 0; // Placeholder

        return Card(
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(completionPercent * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      percentChange >= 0
                          ? '+$percentChange% vs. last week'
                          : '$percentChange% vs. last week',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: completionPercent,
                    backgroundColor: Colors.grey[400],
                    color: AppColors.primary,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$completedTasks of $totalTasks tasks completed',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InterruptionsCard extends StatelessWidget {
  const _InterruptionsCard();

  @override
  Widget build(BuildContext context) {
    // TODO: Fetch real interruptions data from provider/service
    // TODO: Replace hardcoded interruptions with actual notification/chat/phone call counts for the week
    final int notifications = 14; // placeholder
    final int chatMessages = 8; // placeholder
    final int phoneCalls = 3; // placeholder
    return Card(
      color: AppColors.surface, // Match SettingsScreen card background
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InterruptionRow('Notifications', notifications),
            _InterruptionRow('Chat Messages', chatMessages),
            _InterruptionRow('Phone Calls', phoneCalls),
          ],
        ),
      ),
    );
  }
}

class _InterruptionRow extends StatelessWidget {
  final String label;
  final int count;
  const _InterruptionRow(this.label, this.count);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(count.toString(), style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

class _ProductiveHoursCard extends StatelessWidget {
  const _ProductiveHoursCard();

  @override
  Widget build(BuildContext context) {
    // TODO: Fetch real productive hours data from provider/service
    // TODO: Replace hardcoded productive hours with actual calculation based on task completion timestamps
    final List<Map<String, dynamic>> productiveHours = [
      {'time': '9:00 AM - 12:00 PM', 'tasks': 10},
      {'time': '2:00 PM - 4:00 PM', 'tasks': 4},
      {'time': '4:00 PM - 6:00 PM', 'tasks': 3},
    ];
    return Card(
      color: AppColors.surface, // Match SettingsScreen card background
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(''),
                Text(
                  'Tasks Completed',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...productiveHours.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final hour = entry.value['time'];
              final tasks = entry.value['tasks'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$idx. $hour', style: const TextStyle(fontSize: 16)),
                    Text('$tasks', style: const TextStyle(fontSize: 16)),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
