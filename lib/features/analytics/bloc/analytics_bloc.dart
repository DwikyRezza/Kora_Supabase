import 'package:flutter_bloc/flutter_bloc.dart';
import 'analytics_event.dart';
import 'analytics_state.dart';
import '../../../models/workout.dart';
import '../../../services/database_helper.dart';

class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  final DatabaseHelper _db = DatabaseHelper();

  AnalyticsBloc() : super(AnalyticsState(currentMonth: DateTime.now())) {
    on<AnalyticsLoadData>(_onLoadData);
    on<AnalyticsFilterChanged>(_onFilterChanged);
    on<AnalyticsMonthChanged>(_onMonthChanged);
  }

  Future<void> _onLoadData(
      AnalyticsLoadData event, Emitter<AnalyticsState> emit) async {
    emit(state.copyWith(isLoading: true));

    try {
      final globalWorkoutStreak = await _db.getCalculateWorkoutStreak();
      int currentStreak = globalWorkoutStreak['current'] ?? 0;
      int bestStreak = globalWorkoutStreak['best'] ?? 0;

      // Monthly total workouts
      final monthWorkouts = await _db.getWorkoutsByDateRange(
        start: DateTime(event.month.year, event.month.month, 1),
        end: DateTime(event.month.year, event.month.month + 1, 0, 23, 59, 59),
      );

      Set<int> workoutDays = {};
      for (var w in monthWorkouts) {
        workoutDays.add(w.date.day);
      }

      int totalWorkoutsMonth = workoutDays.length;
      int daysInMonth = DateTime(event.month.year, event.month.month + 1, 0).day;

      // Consistency Score
      double consistencyScore = 0.0;
      int passedDays = (event.month.month == DateTime.now().month &&
              event.month.year == DateTime.now().year)
          ? DateTime.now().day
          : daysInMonth;

      if (passedDays > 0) {
        consistencyScore = (totalWorkoutsMonth / passedDays).clamp(0.0, 1.0);
      }

      // Load specific filter workouts
      final weekWorkouts = await _loadChartWorkouts(event.filter);

      // AI Coach Logic
      String coachMessage = _generateCoachMessage(consistencyScore, totalWorkoutsMonth);
      String lottieAnimationUrl = _getLottieUrl(consistencyScore);

      emit(state.copyWith(
        isLoading: false,
        currentStreak: currentStreak,
        bestStreak: bestStreak,
        consistencyScore: consistencyScore,
        currentMonth: event.month,
        selectedFilter: event.filter,
        weekWorkouts: weekWorkouts,
        totalWorkoutsMonth: monthWorkouts.length,
        workoutDaysMonth: workoutDays,
        coachMessage: coachMessage,
        lottieAnimationUrl: lottieAnimationUrl,
      ));
    } catch (e) {
      // In case of error, just stop loading
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onFilterChanged(
      AnalyticsFilterChanged event, Emitter<AnalyticsState> emit) async {
    emit(state.copyWith(isLoading: true));
    final weekWorkouts = await _loadChartWorkouts(event.filter);
    emit(state.copyWith(
      isLoading: false,
      selectedFilter: event.filter,
      weekWorkouts: weekWorkouts,
    ));
  }

  Future<void> _onMonthChanged(
      AnalyticsMonthChanged event, Emitter<AnalyticsState> emit) async {
    add(AnalyticsLoadData(event.month, state.selectedFilter));
  }

  Future<Map<int, List<Workout>>> _loadChartWorkouts(String filter) async {
    final now = DateTime.now();
    // Usually we show the last 7 days or current week in the chart
    final startOfWeek = now.subtract(Duration(days: 6));
    
    final allWorkouts = await _db.getWorkoutsByDateRange(
      start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day, 0, 0, 0),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );

    Map<int, List<Workout>> weekData = {};
    for (int i = 0; i < 7; i++) {
      final d = startOfWeek.add(Duration(days: i));
      weekData[d.day] = [];
    }

    for (var w in allWorkouts) {
      if (filter == 'all' || w.type.toLowerCase() == filter.toLowerCase()) {
        if (weekData.containsKey(w.date.day)) {
          weekData[w.date.day]!.add(w);
        }
      }
    }
    return weekData;
  }

  String _generateCoachMessage(double consistency, int workouts) {
    if (workouts == 0) return 'Ayo mulai langkah pertamamu hari ini! ?????';
    if (consistency >= 0.8) return 'Luar biasa! Konsistensi kamu sangat solid! ??';
    if (consistency >= 0.5) return 'Bagus! Tetap pertahankan ritme latihanmu! ??';
    return 'Jangan menyerah! Setiap langkah kecil sangat berarti. ??';
  }

  String _getLottieUrl(double consistency) {
    if (consistency >= 0.8) return 'https://lottie.host/5a74e508-251c-42ef-a5bd-6916a031eeb4/BvL5wPtdyI.json';
    if (consistency >= 0.5) return 'https://lottie.host/81a96e62-c07a-4db0-bb65-9856cc1b9df5/lC71xK8O7i.json';
    return 'https://lottie.host/c438cebc-0d19-4cb3-bb1e-360d8a562915/6D3aFm8g0w.json'; // fallback animation
  }
}
