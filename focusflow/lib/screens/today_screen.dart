import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/timer_provider.dart';
import '../services/data_sync_service.dart';
import 'add_task_screen.dart';

/// TODAY screen/the main hub.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<TaskProvider>().loadTasks());
  }

  void _openAddTask() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTaskScreen()),
    );
  }

  void _openEditTask(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTaskScreen(existingTask: task)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<TaskProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasksByPriority = provider.tasksByPriority;
        final completed = provider.completedTasks;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _DailyFocusBanner(),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tasks',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                _NewTaskButton(onTap: _openAddTask),
              ],
            ),
            const SizedBox(height: 12),

            if (tasksByPriority[Priority.high]!.isNotEmpty)
              _PrioritySection(
                label: 'High Priority',
                color: Colors.red.shade700,
                tasks: tasksByPriority[Priority.high]!,
                onTap: _openEditTask,
                onToggle: (task) => provider.toggleCompletion(task),
                onDelete: (task) => _confirmDelete(context, provider, task),
              ),

            if (tasksByPriority[Priority.medium]!.isNotEmpty)
              _PrioritySection(
                label: 'Medium Priority',
                color: Colors.orange.shade700,
                tasks: tasksByPriority[Priority.medium]!,
                onTap: _openEditTask,
                onToggle: (task) => provider.toggleCompletion(task),
                onDelete: (task) => _confirmDelete(context, provider, task),
              ),

            if (tasksByPriority[Priority.low]!.isNotEmpty)
              _PrioritySection(
                label: 'Low Priority',
                color: Colors.green.shade700,
                tasks: tasksByPriority[Priority.low]!,
                onTap: _openEditTask,
                onToggle: (task) => provider.toggleCompletion(task),
                onDelete: (task) => _confirmDelete(context, provider, task),
              ),

            if (provider.tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'Tap "+ New task" above to get started',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ),
              ),

            if (completed.isNotEmpty) ...[
              const Divider(height: 32),
              InkWell(
                onTap: () => setState(() => _showCompleted = !_showCompleted),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _showCompleted
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        size: 20,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Completed (${completed.length})',
                        style: theme.textTheme.titleSmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                      const Spacer(),
                      if (_showCompleted)
                        TextButton(
                          onPressed: () =>
                              _confirmClearCompleted(context, provider),
                          child: const Text(
                            'Clear All',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_showCompleted)
                ...completed.map(
                  (task) => _TaskTile(
                    task: task,
                    onTap: () => _openEditTask(task),
                    onToggle: () => provider.toggleCompletion(task),
                    onDelete: () => _confirmDelete(context, provider, task),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TaskProvider provider,
    Task task,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${task.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteTask(task.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('"${task.title}" deleted')));
      }
    }
  }

  Future<void> _confirmClearCompleted(
    BuildContext context,
    TaskProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Completed'),
        content: const Text(
          'Remove all completed tasks? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.clearCompleted();
    }
  }
}

class _DailyFocusBanner extends StatefulWidget {
  @override
  State<_DailyFocusBanner> createState() => _DailyFocusBannerState();
}

class _DailyFocusBannerState extends State<_DailyFocusBanner> {
  double _todayMinutes = 0;
  static const double _targetMinutes = 240;

  @override
  void initState() {
    super.initState();
    _loadTodayFocusTime();
  }

  Future<void> _loadTodayFocusTime() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final sessions = await DataSyncService().getSessionsForRange(startOfDay, endOfDay);

      double totalMinutes = 0;
      for (final session in sessions) {
        totalMinutes += session.duration / 60.0;
      }

      if (mounted) {
        setState(() => _todayMinutes = totalMinutes);
      }
    } catch (e) {
      debugPrint('Error loading focus time: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hoursCompleted = (_todayMinutes / 60).toStringAsFixed(1);
    final targetHours = (_targetMinutes / 60).toStringAsFixed(0);
    final remaining = ((_targetMinutes - _todayMinutes) / 60).clamp(0, _targetMinutes / 60).toStringAsFixed(1);
    final progress = (_todayMinutes / _targetMinutes).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary,
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
          Text(
            'Daily Focus Time',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.3),
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$hoursCompleted hrs done  •  $remaining hrs remaining  •  Target: $targetHours hrs',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewTaskButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NewTaskButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            spreadRadius: 0.5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.add, color: colorScheme.onPrimary),
        label: Text(
          'New task',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onPrimary,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _PrioritySection extends StatelessWidget {
  final String label;
  final Color color;
  final List<Task> tasks;
  final ValueChanged<Task> onTap;
  final ValueChanged<Task> onToggle;
  final ValueChanged<Task> onDelete;

  const _PrioritySection({
    required this.label,
    required this.color,
    required this.tasks,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(
            children: [
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${tasks.length} ${tasks.length == 1 ? "task" : "tasks"}',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
        ...tasks.map(
          (task) => _TaskTile(
            task: task,
            onTap: () => onTap(task),
            onToggle: () => onToggle(task),
            onDelete: () => onDelete(task),
          ),
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskTile({
    required this.task,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOverdue =
        task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        !task.isCompleted;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: task.isCompleted ? Colors.grey : Colors.green,
        child: Icon(task.isCompleted ? Icons.undo : Icons.check, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          onDelete();
        } else if (direction == DismissDirection.startToEnd) {
          onToggle();
        }
        return false;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 8,
              spreadRadius: 0.5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 0,
          ),
          leading: Checkbox(
            value: task.isCompleted,
            onChanged: (_) => onToggle(),
            activeColor: colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted ? Colors.grey : colorScheme.onSurface,
            ),
          ),
          subtitle: Row(
            children: [
              if (task.dueDate != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOverdue ? Colors.red : colorScheme.onSurface.withValues(alpha: 0.12),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 8,
                        spreadRadius: 0.5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    _formatDueLabel(task.dueDate!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isOverdue ? Colors.red : colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (task.category != 'General') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.12)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 8,
                        spreadRadius: 0.5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    task.category,
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          trailing: Text(
            '${task.durationMinutes} min',
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          onTap: onTap,
          onLongPress: () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.timer),
                      title: const Text('Start Focus Session'),
                      onTap: () {
                        Navigator.pop(ctx);
                        final timerProvider = context.read<TimerProvider>();
                        timerProvider.selectTask(task);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Task "${task.title}" selected for Focus')),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit),
                      title: const Text('Edit Task'),
                      onTap: () {
                        Navigator.pop(ctx);
                        onTap();
                      },
                    ),
                    ListTile(
                      leading: Icon(task.isCompleted ? Icons.undo : Icons.check),
                      title: Text(task.isCompleted ? 'Mark as Incomplete' : 'Mark as Complete'),
                      onTap: () {
                        Navigator.pop(ctx);
                        onToggle();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: const Text('Delete Task', style: TextStyle(color: Colors.red)),
                      onTap: () {
                        Navigator.pop(ctx);
                        onDelete();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDueLabel(DateTime due) {
    final now = DateTime.now();
    final diff = due.difference(now);

    if (diff.isNegative) {
      return 'Overdue';
    } else if (diff.inHours < 1) {
      return 'Due in ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Due in ${diff.inHours} hrs';
    } else if (diff.inDays == 0 ||
        (due.day == now.day &&
            due.month == now.month &&
            due.year == now.year)) {
      return 'Due today';
    } else if (diff.inDays == 1) {
      return 'Tomorrow';
    } else {
      return 'Due ${DateFormat.MMMd().format(due)}';
    }
  }
}
