import os
import re

# 1. Create directories
os.makedirs('lib/features/analytics/bloc', exist_ok=True)
os.makedirs('lib/features/analytics/presentation/screens', exist_ok=True)

# 2. Read the monolithic file
with open('lib/screens/weekly_report_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 3. Create AnalyticsEvent
event_code = '''import 'package:equatable/equatable.dart';

abstract class AnalyticsEvent extends Equatable {
  const AnalyticsEvent();

  @override
  List<Object?> get props => [];
}

class AnalyticsLoadData extends AnalyticsEvent {
  final DateTime month;
  final String filter;
  const AnalyticsLoadData(this.month, this.filter);
  
  @override
  List<Object?> get props => [month, filter];
}

class AnalyticsFilterChanged extends AnalyticsEvent {
  final String filter;
  const AnalyticsFilterChanged(this.filter);
  
  @override
  List<Object?> get props => [filter];
}

class AnalyticsMonthChanged extends AnalyticsEvent {
  final DateTime month;
  const AnalyticsMonthChanged(this.month);
  
  @override
  List<Object?> get props => [month];
}
'''
with open('lib/features/analytics/bloc/analytics_event.dart', 'w', encoding='utf-8') as f:
    f.write(event_code)

# 4. Create AnalyticsState
state_code = '''import 'package:equatable/equatable.dart';
import '../../../models/workout.dart';

class AnalyticsState extends Equatable {
  final bool isLoading;
  final int currentStreak;
  final int bestStreak;
  final double consistencyScore;
  final List<int> frozenDays;
  final double targetProtein;
  final DateTime currentMonth;
  final Map<int, Map<String, dynamic>> dailyStats;
  final String selectedFilter;
  final Map<int, List<Workout>> weekWorkouts;
  final int totalWorkoutsMonth;
  final Set<int> workoutDaysMonth;
  
  // AI Coach vars
  final String coachMessage;
  final String lottieAnimationUrl;

  const AnalyticsState({
    this.isLoading = true,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.consistencyScore = 0.0,
    this.frozenDays = const [],
    this.targetProtein = 150.0,
    required this.currentMonth,
    this.dailyStats = const {},
    this.selectedFilter = 'all',
    this.weekWorkouts = const {},
    this.totalWorkoutsMonth = 0,
    this.workoutDaysMonth = const {},
    this.coachMessage = '',
    this.lottieAnimationUrl = '',
  });

  AnalyticsState copyWith({
    bool? isLoading,
    int? currentStreak,
    int? bestStreak,
    double? consistencyScore,
    List<int>? frozenDays,
    double? targetProtein,
    DateTime? currentMonth,
    Map<int, Map<String, dynamic>>? dailyStats,
    String? selectedFilter,
    Map<int, List<Workout>>? weekWorkouts,
    int? totalWorkoutsMonth,
    Set<int>? workoutDaysMonth,
    String? coachMessage,
    String? lottieAnimationUrl,
  }) {
    return AnalyticsState(
      isLoading: isLoading ?? this.isLoading,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      consistencyScore: consistencyScore ?? this.consistencyScore,
      frozenDays: frozenDays ?? this.frozenDays,
      targetProtein: targetProtein ?? this.targetProtein,
      currentMonth: currentMonth ?? this.currentMonth,
      dailyStats: dailyStats ?? this.dailyStats,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      weekWorkouts: weekWorkouts ?? this.weekWorkouts,
      totalWorkoutsMonth: totalWorkoutsMonth ?? this.totalWorkoutsMonth,
      workoutDaysMonth: workoutDaysMonth ?? this.workoutDaysMonth,
      coachMessage: coachMessage ?? this.coachMessage,
      lottieAnimationUrl: lottieAnimationUrl ?? this.lottieAnimationUrl,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        currentStreak,
        bestStreak,
        consistencyScore,
        frozenDays,
        targetProtein,
        currentMonth,
        dailyStats,
        selectedFilter,
        weekWorkouts,
        totalWorkoutsMonth,
        workoutDaysMonth,
        coachMessage,
        lottieAnimationUrl,
      ];
}
'''
with open('lib/features/analytics/bloc/analytics_state.dart', 'w', encoding='utf-8') as f:
    f.write(state_code)

print("Created directories and base BLoC files successfully!")
