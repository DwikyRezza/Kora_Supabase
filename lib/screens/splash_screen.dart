import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../main.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/fcm_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import 'landing_screen.dart';
import 'onboarding_screen.dart';
import '../services/database_helper.dart';
import '../services/social_service.dart';
import '../utils/prefetch_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  bool _isInitComplete = false;
  bool _isAnimationComplete = false;

  bool _isLoggedIn = false;
  bool _isOnboarded = false;

  @override
  void initState() {
    super.initState();

    // Total duration: 1500ms (Minimum splash time)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.1, 0.4, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
      ),
    );

    // Removed pulse and glow animations to keep it simple
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _isAnimationComplete = true;
        _checkAndNavigate();
      }
    });

    _initializeApp();
    _animController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      await dotenv.load(fileName: ".env");
      
      // Initialize Firebase
      await Firebase.initializeApp();
      await FCMService.init();

      // Configure Firestore
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Initialize Services
      LocationService.initialize();
      await initializeDateFormatting('id', null);
      await NotificationService().init();

      // Check Authentication
      _isLoggedIn = AuthService.isLoggedIn;
      _isOnboarded = await ProfileService.isOnboarded();

      if (_isLoggedIn && _isOnboarded) {
        // Run prefetch, but cap it at 3 seconds maximum (timeout)
        // If prefetch is slower than 3 seconds, Splash moves on, and prefetch continues in background
        await Future.any([
          _performPrefetch(),
          Future.delayed(const Duration(seconds: 3)),
        ]);
      }
    } catch (e) {
      debugPrint('[SplashScreen] Initialization Error: $e');
      // Lanjut navigasi meskipun gagal agar pengguna tidak stuck.
    } finally {
      if (mounted) {
        _isInitComplete = true;
        _checkAndNavigate();
      }
    }
  }

  Future<void> _performPrefetch() async {
    final pm = PrefetchManager.instance;
    final db = DatabaseHelper();
    final today = DateTime.now();
    
    await Future.wait([
      ProfileService.getProfile().then((v) => pm.userProfile = v).catchError((e) {
        debugPrint('[Prefetch Error] getUserProfile gagal: $e');
        return <String, dynamic>{};
      }),
      db.getTodayCaloriesConsumed().then((v) => pm.todayCaloriesConsumed = v).catchError((e) {
        debugPrint('[Prefetch Error] getTodayCaloriesConsumed gagal: $e');
        return 0;
      }),
      db.getTodayWorkoutMetrics().then((v) => pm.todayWorkoutMetrics = v).catchError((e) {
        debugPrint('[Prefetch Error] getTodayWorkoutMetrics gagal: $e');
        return <String, num>{};
      }),
      db.getCalculateWorkoutStreak().then((v) => pm.currentWorkoutStreak = v).catchError((e) {
        debugPrint('[Prefetch Error] getCalculateWorkoutStreak gagal: $e');
        return <String, int>{};
      }),
      NotificationService.getUnreadCount().then((v) => pm.unreadNotificationCount = v).catchError((e) {
        debugPrint('[Prefetch Error] getUnreadNotificationCount gagal: $e');
        return 0;
      }),
      SocialService.getFeedPosts(limit: 5).then((v) {
        pm.limitedActivityFeed = v['posts'] as List<Map<String, dynamic>>?;
      }).catchError((e) {
        debugPrint('[Prefetch Error] getActivityFeed gagal: $e');
        return <String, dynamic>{};
      }),
      db.getWorkoutsByDate(today).then((v) => pm.todayWorkouts = v).catchError((e) {
        debugPrint('[Prefetch Error] getWorkoutsByDate gagal: $e');
        return [];
      }),
      db.getProteinEntriesByDate(today).then((v) => pm.todayProtein = v).catchError((e) {
        debugPrint('[Prefetch Error] getProteinEntriesByDate gagal: $e');
        return [];
      }),
      db.getScheduleEventsByDate(today).then((v) => pm.upcomingEvents = v).catchError((e) {
        debugPrint('[Prefetch Error] getScheduleEventsByDate gagal: $e');
        return [];
      }),
    ]);
  }

  void _checkAndNavigate() {
    if (_isInitComplete && _isAnimationComplete && mounted) {
      Widget nextScreen;
      if (!_isLoggedIn) {
        nextScreen = const LandingScreen();
      } else if (!_isOnboarded) {
        nextScreen = const OnboardingScreen();
      } else {
        nextScreen = const MainNavigation();
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 250), // Phase 6 Fade out
          pageBuilder: (_, __, ___) => nextScreen,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine the theme
    final isDark = AppTheme.isDarkMode;
    final logoPath = isDark 
        ? 'assets/icons/logo_splash_screen_dark_mode.png'
        : 'assets/icons/logo_splash_screen.png';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            // Apply scale logic
            final currentScale = _scaleAnimation.value;
            
            return Transform.scale(
              scale: currentScale,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Image.asset(
                  logoPath,
                  width: 280, // Increased size for more focus
                  height: 280,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback in case assets are missing
                    return Icon(
                      Icons.sports_score_rounded,
                      size: 80,
                      color: AppTheme.accent,
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
