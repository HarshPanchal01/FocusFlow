import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import 'add_task_screen.dart';

/// TODAY screen/the main hub.
/// Layout kinda mirrors the Figma mockup:
///   1. Daily Focus Time banner placeholder for Issue #3
///   2. "Tasks" header + "+ New task" row
///   3. Task list grouped by priority High → Medium → Low
///   4. Collapsible completed section
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  // Keep track of whether the completed section is expanded
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    // Load all tasks when the screen first appears
    Future.microtask(() => context.read<TaskProvider>().loadTasks());
  }

  // Go to the screen to create a new task
  void _openAddTask() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTaskScreen()),
    );
  }

  // Go to the screen to edit an existing task
  void _openEditTask(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTaskScreen(existingTask: task)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, provider, _) {
        // Show loading spinner while fetching tasks
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Get tasks grouped by priority level
        final tasksByPriority = provider.tasksByPriority;
        // Get all the completed tasks
        final completed = provider.completedTasks;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Daily focus time banner at the top
            _DailyFocusBanner(),
            const SizedBox(height: 20),

            // Tasks header and button to add new task
            Text(
              'Tasks',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _NewTaskButton(onTap: _openAddTask),
            const SizedBox(height: 12),

            // Show tasks separated by how urgent they are
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

            // Hint text if there are no tasks
            if (provider.tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'Tap "+ New task" above to get started',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ),
              ),

            // Show finished tasks can collapse or expand
            if (completed.isNotEmpty) ...[
              const Divider(height: 32),
              InkWell(
                onTap: () => setState(() => _showCompleted = !_showCompleted),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      // Show arrow that points down when expanded, right when collapsed
                      Icon(
                        _showCompleted
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        size: 20,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      // Show count of completed tasks
                      Text(
                        'Completed (${completed.length})',
                        style: Theme.of(
                          context,
                        ).textTheme.titleSmall?.copyWith(color: Colors.grey),
                      ),
                      const Spacer(),
                      // Only show the clear button when section is expanded
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

  // Show a popup to confirm deletion before removing
  Future<void> _confirmDelete(
    BuildContext context,
    TaskProvider provider,
    Task task,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        // Show which task is being deleted
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
      // Delete the task from the database
      await provider.deleteTask(task.id!);
      if (context.mounted) {
        // Show a message confirming the deletion
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('"${task.title}" deleted')));
      }
    }
  }

  // Show popup to confirm clearing all completed tasks
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
            // Red text to indicate this is a destructive action
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Remove all the completed tasks from the database
      await provider.clearCompleted();
    }
  }
}

// ══════════════════════════════════════════════════════════════
// Subwidgets — skeleton for UI to restyle later
// ══════════════════════════════════════════════════════════════

/// Shows the daily focus time banner at the top.
class _DailyFocusBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: Wire up actual focus time + progress bar from Issue #3
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Focus Time',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // Progress bar showing focus time
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 0.0, // TODO: replace with actual ratio
              minHeight: 10,
              backgroundColor: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Time remaining: 0 hrs  •  Target: 4 hrs',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Button to create a new task.
class _NewTaskButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NewTaskButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      // Styled container for the button
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Plus icon
            Icon(
              Icons.add,
              size: 20,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            const SizedBox(width: 8),
            // Label text
            Text(
              'New task',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows all tasks for one priority level (high, medium, or low).
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(
            children: [
              // Priority level label
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              // Show how many tasks are in this priority level
              Text(
                '${tasks.length} ${tasks.length == 1 ? "task" : "tasks"}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
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

/// One task row with checkbox, title, due date, and delete.
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
    final isOverdue =
        task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        !task.isCompleted;
    // Check if the task is late
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.background,
          border: Border.all(color: Theme.of(context).colorScheme.primary),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 0,
          ),
          leading: Checkbox(
            value: task.isCompleted,
            onChanged: (_) => onToggle(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted ? Colors.grey : null,
            ),
          ),
          subtitle: Row(
            children: [
              // Show the due date if it's set, as a pill badge
              if (task.dueDate != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOverdue ? Colors.red : Colors.grey.shade300,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _formatDueLabel(task.dueDate!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isOverdue ? Colors.red : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Show the category badge if it's not generic
              if (task.category != 'General') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    task.category,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.black),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          trailing: Text(
            '${task.durationMinutes} min',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  /// Format the due date as a friendly label like "Due today" or "Overdue".
  String _formatDueLabel(DateTime due) {
    final now = DateTime.now();
    // How much time until the due date
    final diff = due.difference(now);

    if (diff.isNegative) {
      // The due date has already passed
      return 'Overdue';
    } else if (diff.inHours < 1) {
      // Due very soon
      return 'Due in ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      // Due later today
      return 'Due in ${diff.inHours} hrs';
    } else if (diff.inDays == 0 ||
        (due.day == now.day &&
            due.month == now.month &&
            due.year == now.year)) {
      // It's today
      return 'Due today';
    } else if (diff.inDays == 1) {
      // Tomorrow
      return 'Tomorrow';
    } else {
      // Show the date
      return 'Due ${DateFormat.MMMd().format(due)}';
    }
  }
}
