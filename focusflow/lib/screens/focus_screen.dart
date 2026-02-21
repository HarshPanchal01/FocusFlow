import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';
import '../providers/task_provider.dart';
import '../providers/timer_provider.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  // Local state for the picker, to avoid rebuilding the provider on every scroll tick
  int _pickerHours = 0;
  int _pickerMinutes = 25;
  int _pickerSeconds = 0;

  @override
  void initState() {
    super.initState();
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-select first task if none selected
    final timerProvider = context.read<TimerProvider>();
    final taskProvider = context.read<TaskProvider>();
    
    if (timerProvider.selectedTask == null && taskProvider.incompleteTasks.isNotEmpty) {
      // Defer to next frame to avoid setState during build
      Future.microtask(() {
        timerProvider.selectTask(taskProvider.incompleteTasks.first);
      });
    }
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
          color: Colors.white,
          child: Column(
            children: [
              Expanded(
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
    return Consumer<TimerProvider>(
      builder: (context, timer, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Focus Session',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
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
                      color: AppColors.surface,
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
                  
                  // Interruptions (Placeholder for now)
                  Text(
                    'Interruptions logged',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
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
                      child: Center(
                        child: Text(
                          'No interruptions logged yet.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
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
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        final tasks = taskProvider.incompleteTasks;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
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
                    ?.copyWith(color: AppColors.textSecondary),
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
                        }
                      },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timer.selectedTask?.title ?? 'No task selected',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: timer.isSessionActive 
                            ? AppColors.textSecondary 
                            : AppColors.textPrimary,
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
    return Column(
      children: [
        Text(
          'Set Timer',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textPrimary,
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
              border: Border.all(color: AppColors.primary, width: 2),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.background,
            ),
            child: Text(
              _formatTime(timer.totalSeconds),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
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
    return Column(
      children: [
        Text(
          _formatTime(timer.secondsLeft),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'of ${_formatTime(timer.totalSeconds)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        
        // Progress bar
        LinearProgressIndicator(
          value: timer.progress,
          backgroundColor: AppColors.divider,
          color: AppColors.primary,
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
                  backgroundColor: AppColors.secondary,
                  foregroundColor: AppColors.textPrimary,
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
