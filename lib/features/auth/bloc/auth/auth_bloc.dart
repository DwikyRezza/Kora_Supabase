import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../services/auth_service.dart';
import '../../../../services/profile_service.dart';
import '../../../../models/workout.dart';
import '../../../../models/schedule_event.dart';
import '../../../../services/fcm_service.dart';
import '../../../../services/location_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/database_helper.dart';
import '../../../../services/social_service.dart';
import '../../../../utils/prefetch_manager.dart';

import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(const AuthState()) {
    on<AppStarted>(_onAppStarted);
    on<AuthLoggedIn>(_onAuthLoggedIn);
    on<AuthLoggedOut>(_onAuthLoggedOut);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      debugPrint('[AuthBloc] Memulai dotenv.load()');
      await dotenv.load(fileName: ".env");

      debugPrint('[AuthBloc] Memulai Firebase.initializeApp()');
      await Firebase.initializeApp().timeout(const Duration(seconds: 5));
      
      final isLoggedIn = AuthService.isLoggedIn;
      debugPrint('[AuthBloc] Status Auth: $isLoggedIn');

      try {
        debugPrint('[AuthBloc] Memulai FCMService.init()');
        await FCMService.init().timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('[AuthBloc] FCM Timeout/Error: $e');
      }

      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      LocationService.initialize();
      await initializeDateFormatting('id', null);
      
      try {
        await NotificationService().init().timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('[AuthBloc] Notification Timeout: $e');
      }

      if (isLoggedIn) {
        bool isOnboarded = false;
        try {
          isOnboarded = await ProfileService.isOnboarded().timeout(const Duration(seconds: 3));
        } catch (e) {
          debugPrint('[AuthBloc] Onboard Check Error: $e');
          isOnboarded = true; 
        }

        if (isOnboarded) {
          debugPrint('[AuthBloc] Melakukan Prefetch');
          try {
            await _performPrefetch().timeout(const Duration(seconds: 3));
          } catch (e) {
            debugPrint('[AuthBloc] Prefetch Timeout: $e');
          }
          emit(state.copyWith(status: AuthStatus.authenticated));
        } else {
          emit(state.copyWith(status: AuthStatus.needsOnboarding));
        }
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } catch (e) {
      debugPrint('[AuthBloc] Initialization Fatal Error: $e');
      emit(state.copyWith(status: AuthStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _performPrefetch() async {
    final pm = PrefetchManager.instance;
    final db = DatabaseHelper();
    final today = DateTime.now();

    await Future.wait([
      ProfileService.getProfile()
          .then((v) => pm.userProfile = v)
          .catchError((e) {
        debugPrint('[Prefetch Error] getUserProfile gagal: $e');
        return <String, dynamic>{};
      }),
      db.getTodayCaloriesConsumed()
          .then((v) => pm.todayCaloriesConsumed = v)
          .catchError((e) {
        debugPrint('[Prefetch Error] getTodayCaloriesConsumed gagal: $e');
        return 0;
      }),
      db.getTodayWorkoutMetrics()
          .then((v) => pm.todayWorkoutMetrics = v)
          .catchError((e) {
        debugPrint('[Prefetch Error] getTodayWorkoutMetrics gagal: $e');
        return <String, num>{};
      }),
      db.getCalculateWorkoutStreak()
          .then((v) => pm.currentWorkoutStreak = v)
          .catchError((e) {
        debugPrint('[Prefetch Error] getCalculateWorkoutStreak gagal: $e');
        return <String, int>{};
      }),
      NotificationService.getUnreadCount()
          .then((v) => pm.unreadNotificationCount = v)
          .catchError((e) {
        debugPrint('[Prefetch Error] getUnreadNotificationCount gagal: $e');
        return 0;
      }),
      SocialService.getFeedPosts(limit: 5).then((v) {
        pm.limitedActivityFeed = v['posts'] as List<Map<String, dynamic>>?;
      }).catchError((e) {
        debugPrint('[Prefetch Error] getActivityFeed gagal: $e');
        return null;
      }),
      db.getWorkoutsByDate(today)
          .then((v) => pm.todayWorkouts = v)
          .catchError((e) {
        debugPrint('[Prefetch Error] getWorkoutsByDate gagal: $e');
        return <Workout>[];
      }),
      db.getScheduleEventsByDate(today)
          .then((v) => pm.upcomingEvents = v)
          .catchError((e) {
        debugPrint('[Prefetch Error] getScheduleEventsByDate gagal: $e');
        return <ScheduleEvent>[];
      }),
    ]);
  }

  Future<void> _onAuthLoggedIn(AuthLoggedIn event, Emitter<AuthState> emit) async {
    // Check onboarding again
    emit(state.copyWith(status: AuthStatus.loading));
    bool isOnboarded = false;
    try {
      isOnboarded = await ProfileService.isOnboarded().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[AuthBloc] Onboard Check Error: $e');
      isOnboarded = true; 
    }

    if (isOnboarded) {
      try {
        await _performPrefetch().timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('[AuthBloc] Prefetch Timeout: $e');
      }
      emit(state.copyWith(status: AuthStatus.authenticated));
    } else {
      emit(state.copyWith(status: AuthStatus.needsOnboarding));
    }
  }

  Future<void> _onAuthLoggedOut(AuthLoggedOut event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      await AuthService.signOut();
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.error, errorMessage: e.toString()));
    }
  }
}
