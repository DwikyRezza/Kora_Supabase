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
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _glowAnimation;

  bool _isInitComplete = false;
  bool _isAnimationComplete = false;

  bool _isLoggedIn = false;
  bool _isOnboarded = false;

  @override
  void initState() {
    super.initState();

    // Total duration: 2000ms
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.1, 0.4, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.1, 0.7, curve: Curves.elasticOut),
      ),
    );

    // Pulse 1400 - 2000ms
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.7, 1.0),
      ),
    );

    // Soft Orange Glow (syncs with pulse)
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.4)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.4, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.7, 1.0),
      ),
    );

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
    final logoPath = 'assets/icons/logo_splash_screen.png';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            // Apply scale logic: multiply initial scale by pulse scale
            final currentScale = _scaleAnimation.value * _pulseAnimation.value;
            
            return Transform.scale(
              scale: currentScale,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: _glowAnimation.value > 0
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFF6B00).withValues(alpha: _glowAnimation.value),
                              blurRadius: 22,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: Image.asset(
                    logoPath,
                    width: 240, // Increased from 120
                    height: 240,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback in case assets are missing
                      return const Icon(
                        Icons.sports_score_rounded,
                        size: 80,
                        color: Color(0xFFFF5406),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
