import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/workout_screen.dart';
import 'screens/protein_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/body_stats_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'services/profile_service.dart';
import 'services/notification_service.dart';
import 'services/location_service.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // WAJIB: inisialisasi port komunikasi antara TaskHandler (background service)
  // dan Flutter UI. Harus dipanggil SEBELUM runApp().
  FlutterForegroundTask.initCommunicationPort();

  // Inisialisasi foreground task config sekali di awal
  LocationService.initialize();

  await initializeDateFormatting('id', null);
  await NotificationService().init();
  // Load persisted settings (dark mode, notifikasi, satuan, dll)
  await SettingsService.loadAll();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Check login and onboarding status
  bool isLoggedIn = AuthService.isLoggedIn;
  bool onboarded = await ProfileService.isOnboarded();

  runApp(AthleteSyncApp(isLoggedIn: isLoggedIn, isOnboarded: onboarded));
}

class AthleteSyncApp extends StatelessWidget {
  final bool isLoggedIn;
  final bool isOnboarded;
  AthleteSyncApp({super.key, required this.isLoggedIn, required this.isOnboarded});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'AthleteSync',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          themeMode: currentMode,
          home: _getHomeScreen(),
        );
      },
    );
  }

  Widget _getHomeScreen() {
    if (!isLoggedIn) {
      return const LoginScreen();
    }
    if (!isOnboarded) {
      return OnboardingScreen();
    }
    return MainNavigation();
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  // Callback yang diset oleh ProfileScreen agar MainNavigation bisa meminta izin pindah tab
  Future<bool> Function()? _profileLeaveGuard;

  void setProfileLeaveGuard(Future<bool> Function()? guard) {
    _profileLeaveGuard = guard;
  }

  /// Pindah tab dengan cek perubahan yang belum disimpan jika sedang di tab Profil
  Future<void> _goToTab(int index) async {
    if (_currentIndex == 4 && index != 4 && _profileLeaveGuard != null) {
      // Sedang di tab Profil, mau pindah — tanya dulu
      final canLeave = await _profileLeaveGuard!();
      if (!canLeave) return;
    }
    if (mounted) setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            onGoToWorkout: () => _goToTab(1),
            onGoToProtein: () => _goToTab(2),
            onGoToSchedule: () => _goToTab(3),
            onGoToBodyStats: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => BodyStatsScreen()),
              );
            },
          ),
          WorkoutScreen(),
          ProteinScreen(),
          ScheduleScreen(),
          ProfileScreen(
            onRegisterLeaveGuard: setProfileLeaveGuard,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    const items = [
      BottomNavigationBarItem(
        icon: Icon(Icons.home_rounded),
        activeIcon: Icon(Icons.home_rounded),
        label: 'Beranda',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.fitness_center_rounded),
        activeIcon: Icon(Icons.fitness_center_rounded),
        label: 'Latihan',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.restaurant_menu_rounded),
        activeIcon: Icon(Icons.restaurant_menu_rounded),
        label: 'Nutrisi',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.calendar_month_rounded),
        activeIcon: Icon(Icons.calendar_month_rounded),
        label: 'Jadwal',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_rounded),
        activeIcon: Icon(Icons.person_rounded),
        label: 'Profil',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.isDarkMode
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (index) {
              final isActive = _currentIndex == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _goToTab(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.neonGreen.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            isActive
                                ? (items[index].activeIcon as Icon).icon
                                : (items[index].icon as Icon).icon,
                            color: isActive
                                ? AppTheme.neonGreen
                                : AppTheme.textMuted,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[index].label!,
                          style: TextStyle(
                            color: isActive
                                ? AppTheme.neonGreen
                                : AppTheme.textMuted,
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
