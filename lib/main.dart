import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme/app_theme.dart';
import 'utils/responsive.dart';
import 'screens/landing_screen.dart';
import 'screens/home_screen.dart';
import 'screens/workout_screen.dart';
import 'screens/protein_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/body_stats_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/setting_screen.dart';
import 'services/profile_service.dart';
import 'services/notification_service.dart';
import 'services/location_service.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Load Settings (like ThemeMode)
  await SettingsService.loadAll();

  // ── Aktifkan Firestore Offline Persistence ────────────────────────────────
  // Firestore akan cache data lokal secara otomatis.
  // - Baca: dari cache jika offline, dari cloud jika online (selalu up-to-date)
  // - Tulis: antrian lokal, auto-sync ke cloud saat internet tersedia
  // - Source of truth tetap Firestore Cloud
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // WAJIB: inisialisasi port komunikasi antara TaskHandler (background service)
  // dan Flutter UI. Harus dipanggil SEBELUM runApp().
  FlutterForegroundTask.initCommunicationPort();

  // Inisialisasi foreground task config sekali di awal
  LocationService.initialize();

  await initializeDateFormatting('id', null);
  await NotificationService().init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Check login and onboarding status
  bool isLoggedIn = AuthService.isLoggedIn;
  bool onboarded = await ProfileService.isOnboarded();

  runApp(CorefitApp(isLoggedIn: isLoggedIn, isOnboarded: onboarded));
}

class CorefitApp extends StatelessWidget {
  final bool isLoggedIn;
  final bool isOnboarded;
  const CorefitApp(
      {super.key, required this.isLoggedIn, required this.isOnboarded});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Corefit',
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
      return const LandingScreen();
    }
    if (!isOnboarded) {
      return const OnboardingScreen();
    }
    return const MainNavigation();
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final GlobalKey<WorkoutScreenState> _workoutScreenKey = GlobalKey<WorkoutScreenState>();
  late AnimationController _pulseController;

  void _goToTab(int index) {
    setState(() => _currentIndex = index);
  }

  void _onFabTapped() {
    HapticFeedback.heavyImpact();
    if (_currentIndex != 2) {
      setState(() => _currentIndex = 2);
    }
    // Auto-trigger the modal after transition
    Future.delayed(const Duration(milliseconds: 100), () {
      _workoutScreenKey.currentState?.showWorkoutSelectionSheet(context);
    });
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          body: IndexedStack(
            index: _currentIndex,
            children: [
              HomeScreen(
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
              ProteinScreen(),
              WorkoutScreen(key: _workoutScreenKey),
              ScheduleScreen(),
              SettingScreen(),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButton: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (_currentIndex == 0) // only pulse when on Home
                      BoxShadow(
                        color: Colors.orangeAccent.withValues(alpha: 0.3 * _pulseController.value),
                        blurRadius: 20 * _pulseController.value,
                        spreadRadius: 10 * _pulseController.value,
                      ),
                  ],
                ),
                child: child,
              );
            },
            child: GestureDetector(
              onTap: _onFabTapped,
              child: Container(
                width: 72,
                height: 72,
                margin: const EdgeInsets.only(top: 30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.grey.shade300, Colors.white, Colors.grey.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                padding: const EdgeInsets.all(4), // ketebalan border metalik
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF5722), Color(0xFFD84315)], // Oranye-Merah menyala
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.fitness_center_rounded, color: Colors.white, size: 32),
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      color: AppTheme.surface,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 65,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_rounded, 'Beranda'),
            _buildNavItem(1, Icons.restaurant_menu_rounded, 'Nutrisi'),
            // Ruang kosong untuk Notch FAB
            SizedBox(
              width: 72,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('LATIHAN', style: TextStyle(color: AppTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            _buildNavItem(3, Icons.calendar_month_rounded, 'Jadwal'),
            _buildNavItem(4, Icons.settings_rounded, 'Pengaturan'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    final color = isActive ? AppTheme.neonGreen : AppTheme.textMuted;
    return Expanded(
      child: GestureDetector(
        onTap: () => _goToTab(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
