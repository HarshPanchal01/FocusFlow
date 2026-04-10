import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../utils/haptic_utils.dart';

/// Redesigned Add/Edit Task screen.
///
/// Improvements over the original:
///   - Duration presets (chips) instead of typing raw minutes
///   - Quick due date presets (Today, Tomorrow, Next Week)
///   - Auto-category detection from title keywords
///   - Sectioned layout with icons for scannability
///   - Custom duration option with hours + minutes
class AddTaskScreen extends StatefulWidget {
  final Task? existingTask;

  const AddTaskScreen({super.key, this.existingTask});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  Priority _priority = Priority.medium;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  String _category = 'General';
  int _durationMinutes = 25;
  bool _showCustomDuration = false;

  bool get _isEditing => widget.existingTask != null;

  // Duration presets shown as chips
  static const List<_DurationOption> _durationPresets = [
    _DurationOption(15, '15m'),
    _DurationOption(25, '25m'),
    _DurationOption(30, '30m'),
    _DurationOption(45, '45m'),
    _DurationOption(60, '1h'),
    _DurationOption(90, '1.5h'),
    _DurationOption(120, '2h'),
  ];

  // Category options with icons
  static const List<_CategoryOption> _categoryOptions = [
    _CategoryOption('General', Icons.inbox_outlined),
    _CategoryOption('Coursework', Icons.school_outlined),
    _CategoryOption('Work', Icons.work_outline),
    _CategoryOption('Personal', Icons.person_outline),
    _CategoryOption('Health', Icons.favorite_outline),
    _CategoryOption('Errands', Icons.shopping_cart_outlined),
  ];

  // Keywords that auto-suggest categories from the title
  static const Map<String, String> _categoryKeywords = {
    'assignment': 'Coursework', 'homework': 'Coursework', 'lab': 'Coursework',
    'exam': 'Coursework', 'study': 'Coursework', 'lecture': 'Coursework',
    'quiz': 'Coursework', 'essay': 'Coursework', 'report': 'Coursework',
    'project': 'Coursework', 'class': 'Coursework', 'course': 'Coursework',
    'meeting': 'Work', 'email': 'Work', 'client': 'Work', 'deadline': 'Work',
    'presentation': 'Work', 'review': 'Work', 'standup': 'Work',
    'gym': 'Health', 'workout': 'Health', 'run': 'Health', 'exercise': 'Health',
    'hockey': 'Health', 'yoga': 'Health', 'walk': 'Health', 'swim': 'Health',
    'grocery': 'Errands', 'shopping': 'Errands', 'buy': 'Errands',
    'pick up': 'Errands', 'clean': 'Errands', 'laundry': 'Errands',
    'cook': 'Errands', 'dinner': 'Errands',
    'call': 'Personal', 'friend': 'Personal', 'family': 'Personal',
    'game': 'Personal', 'play': 'Personal', 'movie': 'Personal',
    'read': 'Personal', 'relax': 'Personal',
  };

  @override
  void initState() {
    super.initState();
    final task = widget.existingTask;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(text: task?.description ?? '');

    if (task != null) {
      _priority = task.priority;
      _durationMinutes = task.durationMinutes;
      _category = task.category;
      if (task.dueDate != null) {
        final localDueDate = task.dueDate!.toLocal();
        _dueDate = localDueDate;
        _dueTime = TimeOfDay(hour: localDueDate.hour, minute: localDueDate.minute);
      }
    }

    // Check if duration matches a preset
    _showCustomDuration = !_durationPresets.any((p) => p.minutes == _durationMinutes);

    // Listen for title changes to auto-suggest category
    _titleController.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Auto-detect category from title keywords (only if user hasn't manually picked one)
  bool _userPickedCategory = false;

  void _onTitleChanged() {
    if (_userPickedCategory || _isEditing) return;

    final title = _titleController.text.toLowerCase();
    for (final entry in _categoryKeywords.entries) {
      if (title.contains(entry.key)) {
        if (_category != entry.value) {
          setState(() => _category = entry.value);
        }
        return;
      }
    }
    // Reset to General if no keywords match
    if (_category != 'General') {
      setState(() => _category = 'General');
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      HapticUtils.selectionTick();
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickDueTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      HapticUtils.selectionTick();
      setState(() => _dueTime = picked);
    }
  }

  void _setQuickDate(DateTime date) {
    HapticUtils.selectionTick();
    setState(() {
      _dueDate = date;
      if (_dueTime == null) {
        _dueTime = const TimeOfDay(hour: 23, minute: 59);
      }
    });
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    DateTime? combinedDue;
    if (_dueDate != null) {
      final time = _dueTime ?? const TimeOfDay(hour: 23, minute: 59);
      combinedDue = DateTime(
        _dueDate!.year, _dueDate!.month, _dueDate!.day,
        time.hour, time.minute,
      );
    }

    final provider = context.read<TaskProvider>();

    if (_isEditing) {
      final updated = widget.existingTask!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _priority,
        dueDate: combinedDue,
        clearDueDate: _dueDate == null,
        durationMinutes: _durationMinutes,
        category: _category,
      );
      await provider.updateTask(updated);
    } else {
      final newTask = Task(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _priority,
        dueDate: combinedDue,
        durationMinutes: _durationMinutes,
        category: _category,
      );
      await provider.addTask(newTask);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Task' : 'New Task'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saveTask,
            child: Text('Save', style: TextStyle(
              fontSize: 16, color: colorScheme.primary, fontWeight: FontWeight.w600,
            )),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title & Description ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'What do you need to do?',
                    hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Add notes...',
                    hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.3)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),

              const Divider(height: 1),

              // ── Priority ──
              _SectionHeader(icon: Icons.flag_outlined, label: 'Priority'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _PriorityChip(
                      label: 'Low',
                      color: Colors.green,
                      icon: Icons.arrow_downward,
                      selected: _priority == Priority.low,
                      onTap: () {
                        HapticUtils.selectionTick();
                        setState(() => _priority = Priority.low);
                      },
                    ),
                    const SizedBox(width: 8),
                    _PriorityChip(
                      label: 'Medium',
                      color: Colors.orange,
                      icon: Icons.remove,
                      selected: _priority == Priority.medium,
                      onTap: () {
                        HapticUtils.selectionTick();
                        setState(() => _priority = Priority.medium);
                      },
                    ),
                    const SizedBox(width: 8),
                    _PriorityChip(
                      label: 'High',
                      color: Colors.red,
                      icon: Icons.arrow_upward,
                      selected: _priority == Priority.high,
                      onTap: () {
                        HapticUtils.selectionTick();
                        setState(() => _priority = Priority.high);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),

              // ── Due Date ──
              _SectionHeader(icon: Icons.calendar_today_outlined, label: 'Due Date'),
              // Quick presets
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _QuickDateChip(
                      label: 'Today',
                      selected: _isDueToday(),
                      onTap: () => _setQuickDate(DateTime.now()),
                    ),
                    _QuickDateChip(
                      label: 'Tomorrow',
                      selected: _isDueTomorrow(),
                      onTap: () => _setQuickDate(
                        DateTime.now().add(const Duration(days: 1)),
                      ),
                    ),
                    _QuickDateChip(
                      label: 'Next Week',
                      selected: _isDueNextWeek(),
                      onTap: () => _setQuickDate(
                        DateTime.now().add(const Duration(days: 7)),
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.edit_calendar, size: 16),
                      label: Text(_dueDate != null && !_isDueToday() && !_isDueTomorrow() && !_isDueNextWeek()
                          ? DateFormat.MMMd().format(_dueDate!)
                          : 'Pick Date'),
                      onPressed: _pickDueDate,
                    ),
                    if (_dueDate != null)
                      ActionChip(
                        avatar: const Icon(Icons.access_time, size: 16),
                        label: Text(_dueTime != null
                            ? _dueTime!.format(context)
                            : 'Set Time'),
                        onPressed: _pickDueTime,
                      ),
                    if (_dueDate != null)
                      IconButton(
                        icon: Icon(Icons.close, size: 18, color: colorScheme.onSurface.withOpacity(0.5)),
                        onPressed: () => setState(() {
                          _dueDate = null;
                          _dueTime = null;
                        }),
                        tooltip: 'Clear date',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),

              // ── Duration ──
              _SectionHeader(icon: Icons.timer_outlined, label: 'How long will this take?'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._durationPresets.map((preset) => ChoiceChip(
                      label: Text(preset.label),
                      selected: _durationMinutes == preset.minutes && !_showCustomDuration,
                      onSelected: (_) {
                        HapticUtils.selectionTick();
                        setState(() {
                          _durationMinutes = preset.minutes;
                          _showCustomDuration = false;
                        });
                      },
                    )),
                    ChoiceChip(
                      label: Text(_showCustomDuration
                          ? _formatDuration(_durationMinutes)
                          : 'Custom'),
                      selected: _showCustomDuration,
                      onSelected: (_) {
                        HapticUtils.selectionTick();
                        setState(() => _showCustomDuration = true);
                        _showCustomDurationPicker();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),

              // ── Category ──
              _SectionHeader(icon: Icons.category_outlined, label: 'Category'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categoryOptions.map((cat) => ChoiceChip(
                    avatar: Icon(cat.icon, size: 16),
                    label: Text(cat.name),
                    selected: _category == cat.name,
                    onSelected: (_) {
                      HapticUtils.selectionTick();
                      setState(() {
                        _category = cat.name;
                        _userPickedCategory = true;
                      });
                    },
                  )).toList(),
                ),
              ),

              // ── Save Button ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    icon: Icon(_isEditing ? Icons.check : Icons.add),
                    label: Text(
                      _isEditing ? 'Update Task' : 'Create Task',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    onPressed: _saveTask,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  // ── Helpers ──

  bool _isDueToday() {
    if (_dueDate == null) return false;
    final now = DateTime.now();
    return _dueDate!.year == now.year && _dueDate!.month == now.month && _dueDate!.day == now.day;
  }

  bool _isDueTomorrow() {
    if (_dueDate == null) return false;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return _dueDate!.year == tomorrow.year && _dueDate!.month == tomorrow.month && _dueDate!.day == tomorrow.day;
  }

  bool _isDueNextWeek() {
    if (_dueDate == null) return false;
    final nextWeek = DateTime.now().add(const Duration(days: 7));
    return _dueDate!.year == nextWeek.year && _dueDate!.month == nextWeek.month && _dueDate!.day == nextWeek.day;
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  void _showCustomDurationPicker() {
    int hours = _durationMinutes ~/ 60;
    int mins = _durationMinutes % 60;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Custom Duration',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Hours
                      Column(
                        children: [
                          Text('Hours', style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                onPressed: hours > 0 ? () => setSheetState(() => hours--) : null,
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('$hours', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                              IconButton(
                                onPressed: hours < 8 ? () => setSheetState(() => hours++) : null,
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      ),
                      // Minutes
                      Column(
                        children: [
                          Text('Minutes', style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                onPressed: mins > 0 ? () => setSheetState(() => mins -= 5) : null,
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('${mins.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                              IconButton(
                                onPressed: mins < 55 ? () => setSheetState(() => mins += 5) : null,
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final total = (hours * 60) + mins;
                        if (total > 0) {
                          setState(() {
                            _durationMinutes = total;
                            _showCustomDuration = true;
                          });
                        }
                        Navigator.pop(ctx);
                      },
                      child: Text('Set ${_formatDuration((hours * 60) + mins)}'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Subwidgets ──

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.w600,
          )),
        ],
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Theme.of(context).dividerColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? color : Colors.grey),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              color: selected ? color : Colors.grey,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            )),
          ],
        ),
      ),
    );
  }
}

class _QuickDateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickDateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _DurationOption {
  final int minutes;
  final String label;
  const _DurationOption(this.minutes, this.label);
}

class _CategoryOption {
  final String name;
  final IconData icon;
  const _CategoryOption(this.name, this.icon);
}
