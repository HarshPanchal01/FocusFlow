import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/task_provider.dart';
import 'providers/timer_provider.dart';
import 'providers/insights_provider.dart';
import 'providers/scheduling_provider.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'services/data_sync_service.dart';
import 'services/connectivity_service.dart';
import 'services/sound_service.dart';
import 'widgets/connectivity_banner.dart';
import 'utils/haptic_utils.dart';
import 'providers/theme_provider.dart';
import 'screens/today_screen.dart';
import 'screens/focus_screen.dart';
import 'screens/suggestions_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint('Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized.');

    // Ensure the app always has a Firebase user before Firestore is used.
    debugPrint('Checking current user...');
    if (AuthService().currentUser == null) {
      debugPrint('No user found, signing in anonymously...');
      await AuthService().signInAnonymously();
      debugPrint('Anonymous sign-in successful.');
    } else {
      debugPrint('User already signed in: ${AuthService().currentUser?.uid}');
    }

    debugPrint('Initializing Notification Service...');
    await NotificationService().initialize();
    debugPrint('Notification Service initialized.');

    // Sync cloud data to local SQLite cache for offline-first behavior
    debugPrint('Syncing data from cloud...');
    await DataSyncService().syncFromCloud();

    // Start monitoring connectivity for offline/online banners
    debugPrint('Initializing connectivity monitoring...');
    await ConnectivityService().initialize();

    // Generate sound effects (droplet tone for splash)
    debugPrint('Initializing sound service...');
    await SoundService().initialize();
  } catch (e, stackTrace) {
    debugPrint('ERROR DURING INITIALIZATION: $e');
    debugPrint('STACKTRACE: $stackTrace');
  }

  runApp(const FocusFlowApp());
}

class FocusFlowApp extends StatelessWidget {
  const FocusFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) {
          final timerProvider = TimerProvider();
          NotificationService().setTimerProvider(timerProvider);
          return timerProvider;
        }),
        ChangeNotifierProvider(create: (_) => InsightsProvider()),
        ChangeNotifierProvider(create: (_) => SchedulingProvider()),
        ChangeNotifierProvider.value(value: ConnectivityService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Builder(
        builder: (context) {
          final themeProvider = context.watch<ThemeProvider>();
          return MaterialApp(
            title: 'FocusFlow',
            theme: themeProvider.getTheme(MediaQuery.of(context).platformBrightness),
            home: const SplashScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  late PageController _pageController;

  final List<Widget> _screens = const [
    TodayScreen(),
    FocusScreen(),
    SuggestionsScreen(),
    InsightsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    HapticUtils.lightTap();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('FocusFlow', style: TextStyle(color: Colors.white)),
        backgroundColor: colorScheme.primary,
      ),
      body: Column(
        children: [
          // Connectivity banner — only visible when offline or just reconnected
          const ConnectivityBanner(),
          // Main screen content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Today'),
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Focus'),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb_outline),
            label: 'Suggestions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: _onItemTapped,
      ),
    );
  }
}
