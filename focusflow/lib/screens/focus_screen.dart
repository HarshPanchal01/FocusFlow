import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';
import '../providers/task_provider.dart';
import '../providers/timer_provider.dart';
import '../models/task.dart';
import '../utils/haptic_utils.dart';
import '../widgets/pulsing_text.dart';
import '../widgets/celebration_overlay.dart';

bool _isAutoInterruption(String? type) {
  if (type == null) return false;
  switch (type) {
    case 'Picked Up Phone (Auto-Detected)':
    case 'Screen turned off':
    case 'Switched away from app':
    case 'App not focused (notifications, quick settings, or system)':
      return true;
    default:
      return false;
  }
}

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with WidgetsBindingObserver {
  // Local state for the picker
  int _pickerHours = 0;
  int _pickerMinutes = 25;
  int _pickerSeconds = 0;
  bool _isRatingDialogShown = false;

  @override
  void initState() {
    super.initState();
    // Listen for app lifecycle changes (to auto-log interruptions)
    WidgetsBinding.instance.addObserver(this);

    // Initialize picker values from provider if needed, or default
    final timerProvider = context.read<TimerProvider>();
    if (timerProvider.totalSeconds > 0) {
      final duration = Duration(seconds: timerProvider.totalSeconds);
      _pickerHours = duration.inHours;
      _pickerMinutes = duration.inMinutes % 60;
      _pickerSeconds = duration.inSeconds % 60;
    } else {
      // Default startup state
      timerProvider.setDuration(0, 25, 0);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Routes lifecycle to [TimerProvider] for: overlay / system UI, swipe away,
  /// home, recents, and (with Android) coordination with screen-off events.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    context.read<TimerProvider>().handleAppLifecycle(state);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _showTimerPicker() async {
    final timerProvider = context.read<TimerProvider>();
    // Current duration from provider
    final initialDuration = Duration(seconds: timerProvider.totalSeconds);
    
    Duration tempDuration = initialDuration;

    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 250,
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: Theme.of(context).brightness,
                  ),
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hms,
                    initialTimerDuration: initialDuration,
                    minuteInterval: 1,
                    secondInterval: 1,
                    onTimerDurationChanged: (Duration newDuration) {
                      tempDuration = newDuration;
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _pickerHours = tempDuration.inHours;
                      _pickerMinutes = tempDuration.inMinutes % 60;
                      _pickerSeconds = tempDuration.inSeconds % 60;
                    });
                    timerProvider.setDuration(
                      tempDuration.inHours,
                      tempDuration.inMinutes % 60,
                      tempDuration.inSeconds % 60,
                    );
                    Navigator.of(context).pop();
                  },
                  child: const Text('Set Timer'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRatingDialog(BuildContext context, TimerProvider timer) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        int? selectedRating;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('How focused were you?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rate your focus quality for this session.',
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 16),
                  // 5 emoji buttons in a row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (index) {
                      final rating = index + 1;
                      final labels = ['😵', '😕', '😐', '🙂', '🔥'];
                      final isSelected = selectedRating == rating;
                      return GestureDetector(
                        onTap: () {
                          HapticUtils.selectionTick();
                          setDialogState(() => selectedRating = rating);
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.12),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(labels[index], style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  // Labels under the emojis
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Distracted', style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withValues(alpha: 0.5))),
                      Text('Deep focus', style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    timer.skipRating();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Session saved'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Skip'),
                ),
                ElevatedButton(
                  onPressed: selectedRating != null
                      ? () {
                          Navigator.of(ctx).pop();
                          timer.submitRating(selectedRating);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Focus pattern recorded ✨'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showInterruptionPicker(TimerProvider timer) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'What interrupted you?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Phone Call'),
                onTap: () { timer.logInterruption('Phone Call'); Navigator.pop(context); },
              ),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Someone Talked to Me'),
                onTap: () { timer.logInterruption('Someone Talked to Me'); Navigator.pop(context); },
              ),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Notification / Social Media'),
                onTap: () { timer.logInterruption('Notification / Social Media'); Navigator.pop(context); },
              ),
              ListTile(
                leading: const Icon(Icons.more_horiz),
                title: const Text('Other'),
                onTap: () { timer.logInterruption('Other'); Navigator.pop(context); },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Watch TaskProvider so we rebuild when tasks change (edit/delete on other screens)
    final taskProvider = context.watch<TaskProvider>();

    return Consumer<TimerProvider>(
      builder: (context, timer, _) {
        // Validate selected task still exists in the task list
        if (!timer.isSessionActive && timer.selectedTask != null) {
          final stillExists = taskProvider.incompleteTasks.any(
            (t) => t.id == timer.selectedTask!.id,
          );
          if (!stillExists) {
            // Task was deleted or completed — clear selection
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (taskProvider.incompleteTasks.isNotEmpty) {
                timer.selectTask(taskProvider.incompleteTasks.first);
              } else {
                timer.selectTask(null);
              }
            });
          } else {
            // Task might have been edited (duration changed) — update timer
            final currentTask = taskProvider.incompleteTasks.firstWhere(
              (t) => t.id == timer.selectedTask!.id,
            );
            if (currentTask.durationMinutes != timer.selectedTask!.durationMinutes) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                timer.selectTask(currentTask);
              });
            }
          }
        }

        // Auto-select first task if nothing selected
        if (!timer.isSessionActive && timer.selectedTask == null &&
            taskProvider.incompleteTasks.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            timer.selectTask(taskProvider.incompleteTasks.first);
          });
        }

        // Show rating dialog when session just ended
        if (timer.isAwaitingRating && !_isRatingDialogShown) {
          _isRatingDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Show celebration particles
            CelebrationOverlay.show(context);
            // Then show rating dialog
            _showRatingDialog(context, timer);
          });
        }
        if (!timer.isAwaitingRating) {
          _isRatingDialogShown = false;
        }

        return Scaffold(
          backgroundColor: colorScheme.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Focus Session',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onBackground,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Task Selector
                  _buildTaskSelector(context, timer),
                  
                  const SizedBox(height: 16),
                  
                  // Timer Display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
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
                    child: timer.isSessionActive
                        ? _buildActiveTimer(context, timer)
                        : _buildSetupTimer(context, timer),
                  ),
                  
                  const SizedBox(height: 18),
                  
                  // Interruptions section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Interruptions${timer.interruptionCount > 0 ? ' (${timer.interruptionCount})' : ''}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Manual log button — only shown while a session is active
                      if (timer.isSessionActive)
                        TextButton.icon(
                          onPressed: () => _showInterruptionPicker(timer),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Log'),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 36),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 8,
                            spreadRadius: 0.5,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: timer.interruptions.isEmpty
                          ? Center(
                              child: Text(
                                timer.isSessionActive
                                    ? 'No interruptions yet — stay focused!'
                                    : 'No interruptions logged yet.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: timer.interruptions.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final interruption = timer.interruptions[index];
                                final isAuto = _isAutoInterruption(interruption['type']);
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    isAuto ? Icons.phone_android : Icons.front_hand,
                                    size: 20,
                                    color: isAuto ? Colors.orange : colorScheme.primary,
                                  ),
                                  title: Text(
                                    interruption['type'] ?? 'Unknown',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  trailing: Text(
                                    interruption['time'] ?? '',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskSelector(BuildContext context, TimerProvider timer) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        final tasks = taskProvider.incompleteTasks;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Focus Session Goal',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 4),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: timer.isSessionActive
                    ? null // Disable changing task while running
                    : () async {
                        final Task? picked = await showModalBottomSheet<Task>(
                          context: context,
                          builder: (context) {
                            return SafeArea(
                              child: ListView(
                                shrinkWrap: true,
                                children: tasks.map((task) => ListTile(
                                  title: Text(task.title),
                                  selected: timer.selectedTask?.id == task.id,
                                  onTap: () => Navigator.of(context).pop(task),
                                )).toList(),
                              ),
                            );
                          },
                        );
                        if (picked != null) {
                          timer.selectTask(picked);
                          // Sync the local picker values to match the task's duration
                          setState(() {
                            _pickerHours = picked.durationMinutes ~/ 60;
                            _pickerMinutes = picked.durationMinutes % 60;
                            _pickerSeconds = 0;
                          });
                        }
                      },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timer.selectedTask?.title ?? 'No task selected',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: timer.isSessionActive 
                            ? colorScheme.onSurface.withValues(alpha: 0.6)
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (!timer.isSessionActive)
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSetupTimer(BuildContext context, TimerProvider timer) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Text(
          'Set Timer',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _showTimerPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.primary, width: 2),
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.background,
            ),
            child: Text(
              _formatTime(timer.totalSeconds),
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: timer.totalSeconds > 0 ? timer.startTimer : null,
          child: const Text('Start Focus'),
        ),
      ],
    );
  }

  Widget _buildActiveTimer(BuildContext context, TimerProvider timer) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        PulsingText(
          text: _formatTime(timer.secondsLeft),
          isActive: timer.isRunning,
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'of ${_formatTime(timer.totalSeconds)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        
        // Progress bar
        LinearProgressIndicator(
          value: timer.progress,
          backgroundColor: theme.dividerColor,
          color: colorScheme.primary,
          minHeight: 10,
          borderRadius: BorderRadius.circular(4),
        ),
        
        const SizedBox(height: 18),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.secondary,
                  foregroundColor: colorScheme.onSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: timer.isRunning ? timer.pauseTimer : timer.resumeTimer,
                child: Text(timer.isRunning ? 'Pause' : 'Resume'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red.shade900,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: timer.stopSession,
                child: const Text('End Session'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
