import 'package:equatable/equatable.dart';
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
