import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'home_event.dart';
import 'home_state.dart';
import '../../../services/database_helper.dart';
import '../../../services/profile_service.dart';
import '../../../services/social_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/cloud_sync_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/prefetch_manager.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final DatabaseHelper _db = DatabaseHelper();

  HomeBloc() : super(const HomeState()) {
    on<HomeLoadData>(_onLoadData);
    on<HomeLoadMoreFeed>(_onLoadMoreFeed);
    on<HomeChangeTab>(_onChangeTab);
    on<HomeBackgroundSync>(_onBackgroundSync);
  }

  Future<void> _onLoadData(HomeLoadData event, Emitter<HomeState> emit) async {
    if (!event.isRefresh) {
      emit(state.copyWith(status: HomeStatus.loading));
    }
    
    try {
      if (event.isRefresh) {
        if (AuthService.isLoggedIn) {
          bool isEmpty = await CloudSyncService.isLocalDataEmpty();
          if (isEmpty) {
            await CloudSyncService.restoreAllFromCloud().timeout(const Duration(seconds: 5));
          } else {
            await CloudSyncService.syncWorkoutsToCloud();
            await CloudSyncService.syncNutritionToCloud();
          }
        }
      } else {
        // Try to load prefetch data first if available
        final pm = PrefetchManager.instance;
        if (pm.hasData) {
          _applyPrefetchedData(pm, emit);
          add(HomeBackgroundSync());
          return;
        }
      }

      await _db.checkLateSchedules();
      final today = DateTime.now();
      
      final workouts = await _db.getWorkoutsByDate(today);
      final events = await _db.getScheduleEventsByDate(today);
      final workoutStreak = await _db.getCalculateWorkoutStreak();
      final consumedCals = await _db.getTodayCaloriesConsumed();
      
      final proteinEntries = await _db.getProteinEntriesByDate(today);
      double todayProtein = 0.0;
      for (var entry in proteinEntries) {
        todayProtein += entry.proteinGrams;
      }
      
      final workoutMetrics = await _db.getTodayWorkoutMetrics();

      Map<String, dynamic> profile = {};
      try {
        profile = await ProfileService.getProfile().timeout(const Duration(seconds: 4));
      } catch (_) {}

      int unread = 0;
      try {
        unread = await NotificationService.getUnreadCount().timeout(const Duration(seconds: 3));
      } catch (_) {}

      List<Map<String, dynamic>> posts = state.feedPosts;
      DocumentSnapshot? lastDoc = state.lastFeedDoc;
      bool hasMore = state.hasMoreData;

      if (event.isRefresh || state.feedPosts.isEmpty) {
        try {
          final feedResult = await SocialService.getFeedPosts().timeout(const Duration(seconds: 5));
          posts = feedResult['posts'] as List<Map<String, dynamic>>;
          lastDoc = feedResult['lastDoc'] as DocumentSnapshot?;
          hasMore = posts.isNotEmpty;
        } catch (_) {}
      }

      String userName = state.userName;
      String? userPhotoUrl = state.userPhotoUrl;
      double baseTargetProtein = state.baseTargetProtein;
      double targetCalories = state.targetCalories;

      if (profile.isNotEmpty) {
        userName = profile[ProfileService.keyName] ?? '';
        userPhotoUrl = profile[ProfileService.keyPhotoUrl];
        baseTargetProtein = profile[ProfileService.keyTargetProtein] ?? 0.0;
        final goal = profile[ProfileService.keyGoal]?.toString() ?? 'Bulking';
        if (goal == 'Bulking' || goal == 'Weightlifter') {
          targetCalories = 3000.0;
        } else if (goal == 'Diet' || goal == 'Runner') {
          targetCalories = 2000.0;
        } else {
          targetCalories = 2500.0;
        }
      }

      emit(state.copyWith(
        status: HomeStatus.success,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        baseTargetProtein: baseTargetProtein,
        targetCalories: targetCalories,
        unreadNotifs: unread,
        todayWorkouts: workouts,
        upcomingEvents: events,
        todayCaloriesConsumed: consumedCals,
        todayProtein: todayProtein,
        todayCaloriesBurned: (workoutMetrics['caloriesBurned'] as num?)?.toInt() ?? 0,
        todayWorkoutDuration: (workoutMetrics['duration'] as num?)?.toInt() ?? 0,
        todayWorkoutDistance: (workoutMetrics['distance'] as num?)?.toDouble() ?? 0.0,
        currentWorkoutStreak: workoutStreak['current'] ?? 0,
        feedPosts: posts,
        lastFeedDoc: lastDoc,
        hasMoreData: hasMore,
      ));

    } catch (e) {
      debugPrint("Error loading home data: $e");
      emit(state.copyWith(status: HomeStatus.failure));
    }
  }

  void _applyPrefetchedData(PrefetchManager pm, Emitter<HomeState> emit) {
      String userName = state.userName;
      String? userPhotoUrl = state.userPhotoUrl;
      double baseTargetProtein = state.baseTargetProtein;
      double targetCalories = state.targetCalories;

      if (pm.userProfile != null) {
        userName = pm.userProfile!['name'] ?? '';
        userPhotoUrl = pm.userProfile!['photoUrl'];
        baseTargetProtein = (pm.userProfile!['targetProtein'] as num?)?.toDouble() ?? 0.0;
        final goal = pm.userProfile!['goal']?.toString() ?? 'Bulking';
        if (goal == 'Bulking' || goal == 'Weightlifter') {
          targetCalories = 3000.0;
        } else if (goal == 'Diet' || goal == 'Runner') {
          targetCalories = 2000.0;
        } else {
          targetCalories = 2500.0;
        }
      }

      emit(state.copyWith(
        status: HomeStatus.success,
        todayWorkouts: pm.todayWorkouts ?? [],
        upcomingEvents: pm.upcomingEvents ?? [],
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        baseTargetProtein: baseTargetProtein,
        targetCalories: targetCalories,
        unreadNotifs: pm.unreadNotificationCount ?? 0,
        todayCaloriesConsumed: pm.todayCaloriesConsumed ?? 0,
        todayCaloriesBurned: (pm.todayWorkoutMetrics?['caloriesBurned'] as num?)?.toInt() ?? 0,
        todayWorkoutDuration: (pm.todayWorkoutMetrics?['duration'] as num?)?.toInt() ?? 0,
        todayWorkoutDistance: (pm.todayWorkoutMetrics?['distance'] as num?)?.toDouble() ?? 0.0,
        currentWorkoutStreak: pm.currentWorkoutStreak?['current'] ?? 0,
        feedPosts: pm.limitedActivityFeed ?? [],
        hasMoreData: pm.limitedActivityFeed?.isNotEmpty ?? false,
      ));
  }

  Future<void> _onLoadMoreFeed(HomeLoadMoreFeed event, Emitter<HomeState> emit) async {
    if (state.isLoadingMore || !state.hasMoreData) return;
    emit(state.copyWith(isLoadingMore: true));

    try {
      final result = await SocialService.getFeedPosts(
        startAfter: state.lastFeedDoc,
        limit: 10,
      );
      final newPosts = result['posts'] as List<Map<String, dynamic>>;
      final newLastDoc = result['lastDoc'] as DocumentSnapshot?;

      final List<Map<String, dynamic>> updatedPosts = List.from(state.feedPosts);
      final existingIds = updatedPosts.map((p) => p['id'] ?? '').toSet();
      
      for (var post in newPosts) {
        if (!existingIds.contains(post['id'] ?? '')) {
          updatedPosts.add(post);
          existingIds.add(post['id'] ?? '');
        }
      }

      emit(state.copyWith(
        feedPosts: updatedPosts,
        lastFeedDoc: newLastDoc,
        hasMoreData: newPosts.length >= 10,
        isLoadingMore: false,
      ));
    } catch (_) {
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  void _onChangeTab(HomeChangeTab event, Emitter<HomeState> emit) {
    emit(state.copyWith(dashboardTab: event.tabIndex));
  }

  Future<void> _onBackgroundSync(HomeBackgroundSync event, Emitter<HomeState> emit) async {
    try {
      if (AuthService.isLoggedIn) {
        bool isEmpty = await CloudSyncService.isLocalDataEmpty();
        if (isEmpty) {
          await CloudSyncService.restoreAllFromCloud().timeout(const Duration(seconds: 5));
        } else {
          await CloudSyncService.syncWorkoutsToCloud().timeout(const Duration(seconds: 3));
          await CloudSyncService.syncNutritionToCloud().timeout(const Duration(seconds: 3));
        }
      }
    } catch (_) {}

    // Reload silently
    add(const HomeLoadData(isRefresh: true));
  }
}
