import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
import 'services/cloud_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

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

  runApp(Kora(isLoggedIn: isLoggedIn, isOnboarded: onboarded));
}

class Kora extends StatelessWidget {
  final bool isLoggedIn;
  final bool isOnboarded;
  const Kora(
      {super.key, required this.isLoggedIn, required this.isOnboarded});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Kora',
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

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin {
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
              ProfileScreen(), // Diubah dari SettingScreen() menjadi ProfileScreen()
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
        color: AppTheme.surface.withOpacity(0.95),
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
                color: const Color(0xFFFF5406), // ember-orange
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
