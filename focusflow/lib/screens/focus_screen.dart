import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  Task? _selectedTask;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tasks = Provider.of<TaskProvider>(context).incompleteTasks;
    if (_selectedTask == null && tasks.isNotEmpty) {
      setState(() {
        _selectedTask = tasks.first;
      });
    }
  }

  int? totalSeconds;
  int secondsLeft = 0;
  bool isRunning = false;
  bool timerStarted = false;
  Timer? _timer;
  int _selectedHours = 0;
  int _selectedMinutes = 25;
  int _selectedSeconds = 0;

  void _startTimer() {
    int total =
        _selectedHours * 3600 + _selectedMinutes * 60 + _selectedSeconds;
    if (total <= 0) return;
    setState(() {
      totalSeconds = total;
      secondsLeft = totalSeconds!;
      isRunning = true;
      timerStarted = true;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isRunning) return;
      if (secondsLeft > 0) {
        setState(() {
          secondsLeft--;
        });
      } else {
        setState(() {
          isRunning = false;
        });
        _timer?.cancel();
      }
    });
  }

  void _pauseOrResume() {
    setState(() {
      isRunning = !isRunning;
    });
    if (isRunning && (_timer == null || !_timer!.isActive)) {
      _startTimer();
    }
  }

  void _endSession() {
    setState(() {
      timerStarted = false;
      isRunning = false;
      totalSeconds = null;
      secondsLeft = 0;
      _selectedHours = 0;
      _selectedMinutes = 25;
      _selectedSeconds = 0;
    });
    _timer?.cancel();
  }

  void _showTimerPicker() async {
    Duration initial = Duration(
      hours: _selectedHours,
      minutes: _selectedMinutes,
      seconds: _selectedSeconds,
    );
    Duration tempDuration = initial;
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
                  initialTimerDuration: initial,
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
                      _selectedHours = tempDuration.inHours;
                      _selectedMinutes = tempDuration.inMinutes % 60;
                      _selectedSeconds = tempDuration.inSeconds % 60;
                    });
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
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double progress = totalSeconds != null && totalSeconds! > 0
        ? 1 - (secondsLeft / totalSeconds!)
        : 0;
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
              // Current Focus Session Goal with dropdown
              Consumer<TaskProvider>(
                builder: (context, taskProvider, _) {
                  final tasks = taskProvider.incompleteTasks;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
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
                          onTap: () async {
                            final Task? picked =
                                await showModalBottomSheet<Task>(
                                  context: context,
                                  builder: (context) {
                                    return SafeArea(
                                      child: ListView(
                                        shrinkWrap: true,
                                        children: tasks
                                            .map(
                                              (task) => ListTile(
                                                title: Text(task.title),
                                                selected: _selectedTask == task,
                                                onTap: () => Navigator.of(
                                                  context,
                                                ).pop(task),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    );
                                  },
                                );
                            if (picked != null) {
                              setState(() {
                                _selectedTask = picked;
                              });
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedTask?.title ?? 'No task selected',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Timer Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: !timerStarted
                    ? Column(
                        children: [
                          Text(
                            'Set Timer',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _showTimerPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 32,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: AppColors.background,
                              ),
                              child: Text(
                                '${_selectedHours.toString().padLeft(2, '0')}:${_selectedMinutes.toString().padLeft(2, '0')}:${_selectedSeconds.toString().padLeft(2, '0')}',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
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
                            onPressed: _startTimer,
                            child: const Text('Start'),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Text(
                            _formatTime(secondsLeft),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            totalSeconds != null
                                ? 'of ${(totalSeconds! ~/ 60)} mins'
                                : '',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                          ),
                          const SizedBox(height: 12),
                          // Progress bar
                          LinearProgressIndicator(
                            value: totalSeconds != null && totalSeconds! > 0
                                ? 1 - (secondsLeft / totalSeconds!)
                                : 0,
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
                                  onPressed: _pauseOrResume,
                                  child: Text(isRunning ? 'Pause' : 'Resume'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.textOnPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _endSession,
                                  child: const Text('End Session'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 18),
              // Interruptions logged
              Text(
                'Interruptions logged',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              // Always show the white box, even if empty
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
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
  }
}

class _InterruptionTile extends StatelessWidget {
  final String title;
  final String timeAgo;

  const _InterruptionTile({required this.title, required this.timeAgo});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            timeAgo,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
