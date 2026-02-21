import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';

// =============================================================
// ADD / EDIT TASK SCREEN
// =============================================================
// This screen serves TWO purposes:
//
//   1. CREATE MODE — opened with no arguments from the "+ New task"
//      button on the Today screen. Shows an empty form.
//
//   2. EDIT MODE — opened with an existing Task from tapping a
//      task tile. Pre-fills the form with that task's data.
//
// The screen decides which mode it's in based on whether
// "existingTask" is null or not.
//
// When the user taps "Save", it either:
//   - Calls provider.addTask() for a new task, or
//   - Calls provider.updateTask() for an existing one
//   and then navigates back to the Today screen.
// =============================================================
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
  late TextEditingController _durationController;

  // What priority level the user picked
  Priority _priority = Priority.medium;
  // The date and time the task is due
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  // The category type (work, personal, etc.)
  String _category = 'General';

  // True if we're editing, false if creating new
  bool get _isEditing => widget.existingTask != null;

  // All the different category options
  static const List<String> _categories = [
    'General',
    'Coursework',
    'Work',
    'Personal',
    'Health',
    'Errands',
  ];

  @override
  void initState() {
    super.initState();
    // If editing, fill in all the existing values
    final task = widget.existingTask;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    _durationController = TextEditingController(
      text: (task?.durationMinutes ?? 25).toString(),
    );
    if (task != null) {
      _priority = task.priority;
      // Ensure we're working with local time
      if (task.dueDate != null) {
        final localDueDate = task.dueDate!.toLocal();
        _dueDate = localDueDate;
        _dueTime = TimeOfDay(
          hour: localDueDate.hour,
          minute: localDueDate.minute,
        );
        debugPrint('Loaded task due date: ${task.dueDate} -> Local: $localDueDate');
      } else {
        _dueDate = null;
        _dueTime = null;
      }
      _category = task.category;
    }
  }

  @override
  void dispose() {
    // Clean up the text controllers to avoid memory leaks
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // Let the user pick a date from a calendar
  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    // Only update if the user actually picked something
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  // Let the user pick a time
  Future<void> _pickDueTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    // Only update if the user actually picked something
    if (picked != null) {
      setState(() => _dueTime = picked);
    }
  }

  // Save the task to the database
  Future<void> _saveTask() async {
    // First, check if the form is valid
    if (!_formKey.currentState!.validate()) return;

    // Merge the date and time together into one DateTime
    DateTime? combinedDue;
    if (_dueDate != null) {
      // Use the user's time if they picked one, otherwise default to end of day
      final time = _dueTime ?? const TimeOfDay(hour: 23, minute: 59);
      
      // Create DateTime in local timezone with the selected date and time
      // This ensures the time is preserved correctly
      combinedDue = DateTime(
        _dueDate!.year,
        _dueDate!.month,
        _dueDate!.day,
        time.hour,
        time.minute,
        0, // seconds
        0, // milliseconds
      );
      
      // Debug: Log the created DateTime to verify it's correct
      debugPrint('📅 Created due date:');
      debugPrint('   Selected date: $_dueDate');
      debugPrint('   Selected time: $time');
      debugPrint('   Combined DateTime: $combinedDue');
      debugPrint('   Is UTC: ${combinedDue.isUtc}');
      debugPrint('   Local time: ${combinedDue.toLocal()}');
      debugPrint('   Will be saved as UTC: ${combinedDue.toUtc().toIso8601String()}');
      
      // Debug: Log the created DateTime to verify it's correct
      debugPrint('Created due date: $combinedDue');
      debugPrint('Due date ISO8601: ${combinedDue.toIso8601String()}');
      debugPrint('Due date local: ${combinedDue.toLocal()}');
    }

    // Parse the duration, or use 25 minutes as default
    final duration = int.tryParse(_durationController.text) ?? 25;

    // Get the provider to save the task
    final provider = context.read<TaskProvider>();

    // Either update an existing task or create a new one
    if (_isEditing) {
      // Update the existing task with new values
      final updated = widget.existingTask!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _priority,
        dueDate: combinedDue,
        clearDueDate: _dueDate == null,
        durationMinutes: duration,
        category: _category,
      );
      await provider.updateTask(updated);
    } else {
      // Create a brand new task
      final newTask = Task(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _priority,
        dueDate: combinedDue,
        durationMinutes: duration,
        category: _category,
      );
      await provider.addTask(newTask);
    }

    // Close the screen and go back
    if (mounted) Navigator.pop(context);
  }

  // Build the form UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Task' : 'New Task'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _saveTask,
            child: const Text('Save', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Task title input
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  hintText: 'e.g. Finish Lab Report',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  // Make sure they actually typed something
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Optional description field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Add details or notes...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // Choose how important this is
              Text('Priority', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<Priority>(
                segments: const [
                  ButtonSegment(
                    value: Priority.low,
                    label: Text('Low'),
                    icon: Icon(Icons.arrow_downward, size: 18),
                  ),
                  ButtonSegment(
                    value: Priority.medium,
                    label: Text('Medium'),
                    icon: Icon(Icons.remove, size: 18),
                  ),
                  ButtonSegment(
                    value: Priority.high,
                    label: Text('High'),
                    icon: Icon(Icons.arrow_upward, size: 18),
                  ),
                ],
                selected: {_priority},
                onSelectionChanged: (set) =>
                    setState(() => _priority = set.first),
              ),
              const SizedBox(height: 16),

              // Set when the task is due
              Text('Due Date', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _dueDate != null
                            ? DateFormat.yMMMd().format(_dueDate!)
                            : 'Pick Date',
                      ),
                      onPressed: _pickDueDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 18),
                      label: Text(
                        _dueTime != null
                            ? _dueTime!.format(context)
                            : 'Pick Time',
                      ),
                      onPressed: _pickDueTime,
                    ),
                  ),
                  if (_dueDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      tooltip: 'Clear due date',
                      onPressed: () => setState(() {
                        _dueDate = null;
                        _dueTime = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // How long it'll take
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Estimated Duration (minutes)',
                  border: OutlineInputBorder(),
                  suffixText: 'min',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  // Check if the duration is a valid positive number
                  final parsed = int.tryParse(value ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid number of minutes';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Pick what type of task this is
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 32),

              // Main save button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  icon: Icon(_isEditing ? Icons.check : Icons.add),
                  label: Text(_isEditing ? 'Update Task' : 'Create Task'),
                  onPressed: _saveTask,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
