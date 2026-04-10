import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../providers/theme_provider.dart';
import '../providers/task_provider.dart';
import '../providers/insights_provider.dart';
import '../providers/scheduling_provider.dart';
import '../services/data_sync_service.dart';
import '../services/dummy_data_service.dart';
import 'auth/login_screen.dart';
import '../services/firestore_service.dart';
import '../models/task.dart';
import '../models/session.dart';
import 'dart:math';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Notification toggles
  bool taskReminders = true;
  bool focusSessionAlerts = true;
  bool suggestionNotifications = true;
  bool weeklyDigest = false;

  // Focus mode selection
  int focusMode = 1; // 0: Deep, 1: Balanced, 2: Light (default: Balanced)
  
  // Auth state
  final AuthService _auth = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      taskReminders = prefs.getBool('taskReminders') ?? true;
      focusSessionAlerts = prefs.getBool('focusSessionAlerts') ?? true;
      suggestionNotifications = prefs.getBool('suggestionNotifications') ?? true;
      weeklyDigest = prefs.getBool('weeklyDigest') ?? false;
      focusMode = prefs.getInt('focusMode') ?? 1;
      _isLoading = false;
    });
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }
  }

  void _showColorPicker(ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a Custom Theme Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: themeProvider.customSeedColor,
            onColorChanged: (color) {
              themeProvider.setCustomColor(color);
            },
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ
  // DUMMY DATA SEEDING
  // ΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉΓòÉ

  Future<void> _seedDummyTasks() async {
    final tasks = [
      Task(
        title: 'Finish project report',
        description: 'Complete the final Firebase migration write-up',
        priority: Priority.high,
        durationMinutes: 60,
        category: 'Coursework',
        dueDate: DateTime.now().add(const Duration(days: 1)),
      ),
      Task(
        title: 'Review lecture notes',
        description: 'Go over mobile dev slides',
        priority: Priority.medium,
        durationMinutes: 45,
        category: 'Coursework',
        dueDate: DateTime.now().add(const Duration(days: 2)),
      ),
      Task(
        title: 'Workout',
        description: '30-minute session',
        priority: Priority.low,
        durationMinutes: 30,
        category: 'Health',
        dueDate: DateTime.now().add(const Duration(days: 1)),
      ),
      Task(
        title: 'Buy groceries',
        description: 'Milk, eggs, bread, fruit',
        priority: Priority.medium,
        durationMinutes: 20,
        category: 'Personal',
        dueDate: DateTime.now().add(const Duration(days: 3)),
      ),
      Task(
        title: 'Prepare presentation',
        description: 'Practice demo for FocusFlow',
        priority: Priority.high,
        durationMinutes: 90,
        category: 'Coursework',
        dueDate: DateTime.now().add(const Duration(hours: 12)),
      ),
    ];

    for (final task in tasks) {
      await _firestoreService.insertTask(task);
    }

    if (mounted) {
      await Provider.of<TaskProvider>(context, listen: false).loadTasks();
      setState(() {});
    }
  }

  Future<void> _seedDummySessions() async {
    final random = Random();
    final now = DateTime.now();

    for (int i = 0; i < 7; i++) {
      final sessionDate = now.subtract(Duration(days: i));
      final session = Session(
        startTime: DateTime(sessionDate.year, sessionDate.month, sessionDate.day, 10 + i, 0),
        duration: 1500 + random.nextInt(3600), 
        isCompleted: true,
        interruptionCount: random.nextInt(3),
        selfRating: random.nextInt(3) + 3, // Rating between 3-5
      );

      await _firestoreService.insertSession(session);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Section
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Builder(
                    builder: (context) {
                      final hasPermanentAccount = _auth.currentUser != null &&
                          !_auth.currentUser!.isAnonymous;
                      final isAnonymousUser =
                          _auth.currentUser != null && _auth.currentUser!.isAnonymous;
                      final userEmail = _auth.currentUser?.email ?? 'Guest';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            hasPermanentAccount ? 'Welcome Back' : 'Welcome, Guest',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasPermanentAccount ? userEmail : 'Sign in to sync your data permanently',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          if (!hasPermanentAccount)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                              ),
                              onPressed: _openLogin,
                              child: Text(
                                isAnonymousUser ? 'Create Account / Sign In' : 'Sign In / Sign Up',
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Appearance Section (Themes)
            Text('Appearance', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                children: [
                  _buildThemeOption(
                    'System Default',
                    Icons.brightness_auto,
                    ThemePreference.system,
                    themeProvider,
                  ),
                  _buildThemeOption(
                    'Light Mode',
                    Icons.light_mode,
                    ThemePreference.light,
                    themeProvider,
                  ),
                  _buildThemeOption(
                    'Dark Mode',
                    Icons.dark_mode,
                    ThemePreference.dark,
                    themeProvider,
                  ),
                  _buildThemeOption(
                    'Custom Theme',
                    Icons.palette,
                    ThemePreference.custom,
                    themeProvider,
                    trailing: GestureDetector(
                      onTap: () => _showColorPicker(themeProvider),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: themeProvider.customSeedColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.dividerColor),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Notifications Section
            Text('Notifications', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                children: [
                  _buildCheckboxRow('Task reminders', taskReminders, (v) {
                    setState(() => taskReminders = v);
                    _savePreference('taskReminders', v);
                  }),
                  _buildCheckboxRow('Focus session alerts', focusSessionAlerts, (v) {
                    setState(() => focusSessionAlerts = v);
                    _savePreference('focusSessionAlerts', v);
                  }),
                  _buildCheckboxRow('Suggestion notifications', suggestionNotifications, (v) {
                    setState(() => suggestionNotifications = v);
                    _savePreference('suggestionNotifications', v);
                  }),
                  _buildCheckboxRow('Weekly Insight digest', weeklyDigest, (v) {
                    setState(() => weeklyDigest = v);
                    _savePreference('weeklyDigest', v);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Focus Modes Section
            Text('Focus Modes', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
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
              child: Column(
                children: [
                  _buildRadioTile(title: 'Deep Focus', subtitle: 'No notifications', value: 0),
                  _buildRadioTile(title: 'Balanced', subtitle: 'Important notifications only', value: 1),
                  _buildRadioTile(title: 'Light Mode', subtitle: 'All notifications', value: 2),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Testing Section
            Text('Data & Seeding', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    onPressed: () async {
                      await _seedDummyTasks();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Seeded 5 dummy tasks')),
                        );
                      }
                    },
                    icon: const Icon(Icons.add_task),
                    label: const Text('Seed Dummy Tasks'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.secondary,
                      foregroundColor: colorScheme.onSecondary,
                    ),
                    onPressed: () async {
                      await _seedDummySessions();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Seeded dummy session history')),
                        );
                      }
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('Seed Dummy Sessions'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    onPressed: _seedAllDemoData,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Seed all demo data'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adds sample tasks, rolling sessions, this week chart data, and streak pack. '
                    'Refreshes insights and suggestions.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const Divider(height: 32),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                    ),
                    onPressed: () async {
                      await NotificationService().showNotification(
                        title: 'Test Notification',
                        body: 'If you see this, notifications are working!',
                      );
                    },
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Test Notification'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Data reset', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error),
              ),
              onPressed: _confirmAndClearAllData,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Clear all app data'),
            ),
            const SizedBox(height: 8),
            Text(
              'Removes tasks, sessions, and focus patterns locally and in the cloud when online.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),

            // Sign Out Button
            if (_auth.currentUser != null && !_auth.currentUser!.isAnonymous) ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.onSurface,
                  side: BorderSide(color: theme.dividerColor),
                ),
                onPressed: _handleSignOut,
                child: const Text('Sign Out'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(String label, IconData icon, ThemePreference pref, ThemeProvider provider, {Widget? trailing}) {
    final isSelected = provider.preference == pref;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : null),
      title: Text(label),
      trailing: trailing ?? (isSelected ? const Icon(Icons.check, color: Colors.green) : null),
      onTap: () => provider.setPreference(pref),
    );
  }

  Future<void> _openLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (result == true) setState(() {});
  }

  Future<void> _handleSignOut() async {
    await _auth.signOut();
    setState(() {});
  }

  Future<void> _confirmAndClearAllData() async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all app data?'),
        content: const Text(
          'This deletes every task, focus session, and saved focus pattern '
          'from this device and from your cloud backup (when online). '
          'Notification reminders tied to tasks will be cancelled.\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Clear everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final insightsProvider = Provider.of<InsightsProvider>(context, listen: false);
    final schedulingProvider = Provider.of<SchedulingProvider>(context, listen: false);

    try {
      await DataSyncService().clearAllData();
      await NotificationService().cancelAllNotifications();
      if (!mounted) return;
      await taskProvider.loadTasks();
      await insightsProvider.loadWeeklyInsights();
      await schedulingProvider.loadSuggestions(tasks: taskProvider.incompleteTasks);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All tasks, sessions, and patterns have been removed.'),
        ),
      );
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not clear all data: $e')),
        );
      }
    }
  }

  Future<void> _seedAllDemoData() async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final insightsProvider = Provider.of<InsightsProvider>(context, listen: false);
    final schedulingProvider = Provider.of<SchedulingProvider>(context, listen: false);

    await _seedDummyTasks();
    if (!mounted) return;

    final taskId =
        taskProvider.tasks.isNotEmpty ? taskProvider.tasks.first.id : null;
    final dummy = DummyDataService();

    final nRolling = await dummy.seedConsecutiveDayStreak(
      dayCount: 7,
      taskId: taskId,
    );
    final nWeek = await dummy.seedEveryDayOfCurrentIsoWeek(taskId: taskId);
    final nPack = await dummy.seedStreakTestPack(
      consecutiveDays: 7,
      taskId: taskId,
    );

    if (!mounted) return;
    await insightsProvider.loadWeeklyInsights();
    await schedulingProvider.loadSuggestions(tasks: taskProvider.incompleteTasks);
    if (!mounted) return;

    final totalSessions = nRolling + nWeek + nPack;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Demo data ready: 5 tasks + $totalSessions sessions '
          '($nRolling rolling · $nWeek this week · $nPack streak pack).',
        ),
        duration: const Duration(seconds: 6),
      ),
    );
    setState(() {});
  }

  Widget _buildCheckboxRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
        Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          activeColor: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildRadioTile({required String title, required String subtitle, required int value}) {
    return RadioListTile<int>(
      value: value,
      groupValue: focusMode,
      onChanged: (v) {
        setState(() => focusMode = v ?? 1);
        _savePreference('focusMode', v ?? 1);
      },
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      activeColor: Theme.of(context).colorScheme.primary,
      contentPadding: EdgeInsets.zero,
    );
  }
}
