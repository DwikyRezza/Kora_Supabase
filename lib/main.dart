import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:quick_actions/quick_actions.dart';
import 'theme/app_theme.dart';
import 'utils/tab_visibility.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/home/bloc/home_bloc.dart';
import 'features/workout/presentation/screens/workout_screen.dart';
import 'features/ainutrition/presentation/screens/ai_nutrition_screen.dart';
import 'features/running/presentation/screens/running_screen.dart';
import 'features/workout/presentation/screens/workout_setup_screen.dart';
import 'services/profile_service.dart';
import 'features/nutrition/presentation/screens/protein_screen.dart';
import 'features/schedule/presentation/screens/schedule_screen.dart';
import 'screens/body_stats_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'repositories/workout_repository.dart';
import 'repositories/schedule_repository.dart';

import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // WAJIB: inisialisasi port komunikasi antara TaskHandler (background service)
  // dan Flutter UI. Harus dipanggil SEBELUM runApp().
  FlutterForegroundTask.initCommunicationPort();

  // Load Settings (like ThemeMode) sebelum UI dirender
  await SettingsService.loadAll();

  // Update status bar brightness saat tema berubah
  AppTheme.themeNotifier.addListener(() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: AppTheme.isDarkMode ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ));
  });

  // Terapkan initial status bar style
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: AppTheme.isDarkMode ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
  ));

  runApp(const KoraApp());
}

class KoraApp extends StatelessWidget {
  const KoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<WorkoutRepository>(
          create: (context) => WorkoutRepository(),
        ),
        RepositoryProvider<ScheduleRepository>(
          create: (context) => ScheduleRepository(),
        ),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: AppTheme.themeNotifier,
        builder: (context, currentMode, _) {
          return MaterialApp(
            title: 'Kora',
            debugShowCheckedModeBanner: false,
            scrollBehavior: const _GlowScrollBehavior(),
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: currentMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _pulseController;

  void _goToTab(int index) {
    setState(() => _currentIndex = index);
    TabVisibility.instance.setActiveTab(index);
  }

  void _onFabTapped() {
    HapticFeedback.heavyImpact();
    if (_currentIndex != 2) {
      setState(() => _currentIndex = 2);
      TabVisibility.instance.setActiveTab(2);
    }
    // Auto-trigger the modal after transition
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _showWorkoutSelectionSheet(context);
      }
    });
  }

  void _showWorkoutSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 32, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 32),
              Text('Mulai Latihan', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              
              _buildBoldGatewayCard(
                context,
                title: 'Lari / Jalan (GPS)',
                subtitle: 'Lacak rute & pace',
                icon: Icons.directions_run_rounded,
                accentColor: AppTheme.accent,
                onTap: () async {
                  Navigator.pop(context);
                  final profile = await ProfileService.getProfile();
                  final weight = profile[ProfileService.keyWeight] ?? 70.0;
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => RunningTrackerScreen(userWeight: weight)));
                },
              ),
              const SizedBox(height: 16),
              
              _buildBoldGatewayCard(
                context,
                title: 'Workout',
                subtitle: 'Gym log',
                icon: Icons.fitness_center_rounded,
                accentColor: AppTheme.accent,
                onTap: () async {
                  Navigator.pop(context);
                  final profile = await ProfileService.getProfile();
                  final weight = profile[ProfileService.keyWeight] ?? 70.0;
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkoutSetupScreen(userWeight: weight)));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBoldGatewayCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
              ),
              child: Center(child: Icon(icon, color: accentColor, size: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    NotificationService.startListening();

    const QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      if (shortcutType == 'catat_telur') {
        _goToTab(1); // Nutrisi
      } else if (shortcutType == 'mulai_lari') {
        _goToTab(2); // Latihan
      } else if (shortcutType == 'lihat_jadwal') {
        _goToTab(3); // Jadwal
      }
    });

    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(type: 'catat_telur', localizedTitle: 'Catat Telur', icon: 'icon_egg'),
      const ShortcutItem(type: 'mulai_lari', localizedTitle: 'Mulai Lari', icon: 'icon_run'),
      const ShortcutItem(type: 'lihat_jadwal', localizedTitle: 'Lihat Jadwal', icon: 'icon_calendar'),
    ]);
  }

  @override
  void dispose() {
    NotificationService.stopListening();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: AppTheme.background,
          body: IndexedStack(
            index: _currentIndex,
            children: [
              BlocProvider<HomeBloc>(
                create: (context) => HomeBloc(),
                child: HomeScreen(
                  onGoToWorkout: () => _goToTab(2),
                  onGoToProtein: () => _goToTab(1),
                  onGoToSchedule: () => _goToTab(3),
                  onGoToBodyStats: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const BodyStatsScreen()),
                    );
                  },
                ),
              ),
              const ProteinScreen(),
              const WorkoutScreen(),
              const ScheduleScreen(),
              const ProfileScreen(), // Diubah dari SettingScreen() menjadi ProfileScreen()
            ],
          ),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            _buildNavItem(0, Icons.home_rounded, 'Home'),
            _buildNavItem(1, Icons.restaurant_menu_rounded, 'Meal'),
            
            // Center Training Button
            Expanded(
              child: GestureDetector(
                onTap: _onFabTapped,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.textPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add_rounded, color: AppTheme.background, size: 22),
                    ),
                    Text(
                      'TRAINING',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            _buildNavItem(3, Icons.calendar_month_rounded, 'Plan'),
            _buildNavItem(4, Icons.person_rounded, 'Profil'),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    
    if (isActive) {
      return Expanded(
        child: GestureDetector(
          onTap: () => _goToTab(index),
          child: Align(
            alignment: Alignment.center,
            heightFactor: 1.0,
            child: Container(
              constraints: const BoxConstraints(minWidth: 60),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accent, // ember-orange
                borderRadius: BorderRadius.circular(26), // rounded-athlete
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => _goToTab(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.textMuted, size: 24),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowScrollBehavior extends ScrollBehavior {
  const _GlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: AppTheme.accent.withValues(alpha: 0.3),
      child: child,
    );
  }
}
