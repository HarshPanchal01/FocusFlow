import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../providers/task_provider.dart';
import '../screens/auth/login_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoggedIn = _auth.isLoggedIn;
    final userEmail = _auth.currentUserEmail ?? 'Guest';

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Section
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isLoggedIn ? 'Welcome Back' : 'Welcome, Guest',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLoggedIn ? userEmail : 'Sign in to sync your data',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  if (isLoggedIn)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: () {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Edit Profile not implemented yet')),
                         );
                      },
                      child: const Text('Edit profile'),
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: _openLogin,
                      child: const Text('Sign In / Sign Up'),
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
              child: Column(
                children: [
                  _buildCheckboxRow(
                    'Task reminders',
                    taskReminders,
                    (v) {
                      setState(() => taskReminders = v);
                      _savePreference('taskReminders', v);
                    },
                  ),
                  _buildCheckboxRow(
                    'Focus session alerts',
                    focusSessionAlerts,
                    (v) {
                      setState(() => focusSessionAlerts = v);
                      _savePreference('focusSessionAlerts', v);
                    },
                  ),
                  _buildCheckboxRow(
                    'Suggestion notifications',
                    suggestionNotifications,
                    (v) {
                      setState(() => suggestionNotifications = v);
                      _savePreference('suggestionNotifications', v);
                    },
                  ),
                  _buildCheckboxRow(
                    'Weekly Insight digest',
                    weeklyDigest,
                    (v) {
                      setState(() => weeklyDigest = v);
                      _savePreference('weeklyDigest', v);
                    },
                  ),
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
              child: Column(
                children: [
                  _buildRadioTile(
                    title: 'Deep Focus',
                    subtitle: 'No notifications',
                    value: 0,
                  ),
                  _buildRadioTile(
                    title: 'Balanced',
                    subtitle: 'Important notifications only',
                    value: 1,
                  ),
                  _buildRadioTile(
                    title: 'Light Mode',
                    subtitle: 'All notifications',
                    value: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Test Notification Section
            Text('Testing', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: () async {
                      await NotificationService().showNotification(
                        title: 'Test Notification',
                        body: 'If you see this, notifications are working! 🎉',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Test notification sent! Check your notification tray.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Test Notification'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: () async {
                      // Reschedule all task notifications
                      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
                      await taskProvider.loadTasks();
                      await NotificationService().rescheduleAllTaskReminders(taskProvider.tasks);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Rescheduled all task notifications. Check debug console for details.'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reschedule All Task Notifications'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to send a test notification to verify notifications are working',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Seed Data (Developer)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onPressed: () async {
                await DatabaseService().seedDummyData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Seeded dummy sessions for last 7 days')),
                  );
                }
              },
              icon: const Icon(Icons.science),
              label: const Text('Seed Dummy Data'),
            ),
            const SizedBox(height: 12),

            // Seed Tasks (Developer)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onPressed: () async {
                await DatabaseService().seedDummyTasks();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Seeded 5 dummy tasks')),
                  );
                }
              },
              icon: const Icon(Icons.list_alt),
              label: const Text('Seed Dummy Tasks'),
            ),
            const SizedBox(height: 12),

            // Sign Out Button (Only if logged in)
            if (isLoggedIn) ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  side: const BorderSide(color: AppColors.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: _handleSignOut,
                child: const Text('Sign Out'),
              ),
              const SizedBox(height: 12),
              
              // Delete Account Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.textOnPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: () {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Delete Account not implemented yet')),
                   );
                },
                child: const Text('Delete Account'),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Future<void> _openLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    // If login was successful (returned true), refresh state
    if (result == true) {
      setState(() {});
    }
  }
  
  Future<void> _handleSignOut() async {
    await _auth.signOut();
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out')),
      );
    }
  }

  Widget _buildCheckboxRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
        Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          activeColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required int value,
  }) {
    return RadioListTile<int>(
      value: value,
      groupValue: focusMode,
      onChanged: (v) {
        setState(() => focusMode = v ?? 1);
        _savePreference('focusMode', v ?? 1);
      },
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
    );
  }
}
