import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/workout.dart';
import '../../../models/schedule_event.dart';

enum HomeStatus { initial, loading, success, failure }

class HomeState extends Equatable {
  final HomeStatus status;
  final String userName;
  final String? userPhotoUrl;
  final double baseTargetProtein;
  final double targetCalories;
  final int unreadNotifs;
  
  final List<Workout> todayWorkouts;
  final List<ScheduleEvent> upcomingEvents;
  
  final int todayCaloriesConsumed;
  final double todayProtein;
  final int todayCaloriesBurned;
  final int todayWorkoutDuration;
  final double todayWorkoutDistance;
  final int currentWorkoutStreak;

  final List<Map<String, dynamic>> feedPosts;
  final DocumentSnapshot? lastFeedDoc;
  final bool isLoadingMore;
  final bool hasMoreData;

  final int dashboardTab;

  const HomeState({
    this.status = HomeStatus.initial,
    this.userName = '',
    this.userPhotoUrl,
    this.baseTargetProtein = 0.0,
    this.targetCalories = 2500.0,
    this.unreadNotifs = 0,
    this.todayWorkouts = const [],
        this.upcomingEvents = const [],
    this.todayCaloriesConsumed = 0,
    this.todayProtein = 0.0,
    this.todayCaloriesBurned = 0,
    this.todayWorkoutDuration = 0,
    this.todayWorkoutDistance = 0.0,
    this.currentWorkoutStreak = 0,
    this.feedPosts = const [],
    this.lastFeedDoc,
    this.isLoadingMore = false,
    this.hasMoreData = true,
    this.dashboardTab = 0,
  });

  double get totalProteinToday => todayProtein;
  double get totalProteinNeeded => baseTargetProtein;

  HomeState copyWith({
    HomeStatus? status,
    String? userName,
    String? userPhotoUrl,
    double? baseTargetProtein,
    double? targetCalories,
    int? unreadNotifs,
    List<Workout>? todayWorkouts,
    List<ScheduleEvent>? upcomingEvents,
    int? todayCaloriesConsumed,
    double? todayProtein,
    int? todayCaloriesBurned,
    int? todayWorkoutDuration,
    double? todayWorkoutDistance,
    int? currentWorkoutStreak,
    List<Map<String, dynamic>>? feedPosts,
    DocumentSnapshot? lastFeedDoc,
    bool? isLoadingMore,
    bool? hasMoreData,
    int? dashboardTab,
  }) {
    return HomeState(
      status: status ?? this.status,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      baseTargetProtein: baseTargetProtein ?? this.baseTargetProtein,
      targetCalories: targetCalories ?? this.targetCalories,
      unreadNotifs: unreadNotifs ?? this.unreadNotifs,
      todayWorkouts: todayWorkouts ?? this.todayWorkouts,
            upcomingEvents: upcomingEvents ?? this.upcomingEvents,
      todayCaloriesConsumed: todayCaloriesConsumed ?? this.todayCaloriesConsumed,
      todayProtein: todayProtein ?? this.todayProtein,
      todayCaloriesBurned: todayCaloriesBurned ?? this.todayCaloriesBurned,
      todayWorkoutDuration: todayWorkoutDuration ?? this.todayWorkoutDuration,
      todayWorkoutDistance: todayWorkoutDistance ?? this.todayWorkoutDistance,
      currentWorkoutStreak: currentWorkoutStreak ?? this.currentWorkoutStreak,
      feedPosts: feedPosts ?? this.feedPosts,
      lastFeedDoc: lastFeedDoc ?? this.lastFeedDoc,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreData: hasMoreData ?? this.hasMoreData,
      dashboardTab: dashboardTab ?? this.dashboardTab,
    );
  }

  @override
  List<Object?> get props => [
        status,
        userName,
        userPhotoUrl,
        baseTargetProtein,
        targetCalories,
        unreadNotifs,
        todayWorkouts,
                upcomingEvents,
        todayCaloriesConsumed,
        todayProtein,
        todayCaloriesBurned,
        todayWorkoutDuration,
        todayWorkoutDistance,
        currentWorkoutStreak,
        feedPosts,
        lastFeedDoc,
        isLoadingMore,
        hasMoreData,
        dashboardTab,
      ];
}
