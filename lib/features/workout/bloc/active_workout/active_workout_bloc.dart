import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'active_workout_event.dart';
import 'active_workout_state.dart';

class ActiveWorkoutBloc extends Bloc<ActiveWorkoutEvent, ActiveWorkoutState> {
  Timer? _sessionTimer;
  Timer? _restTimer;

  ActiveWorkoutBloc() : super(const ActiveWorkoutState(exercises: [], exerciseSets: {})) {
    on<ActiveWorkoutInit>(_onInit);
    on<ActiveWorkoutTickSession>(_onTickSession);
    on<ActiveWorkoutTickRest>(_onTickRest);
    on<ActiveWorkoutLogSet>(_onLogSet);
    on<ActiveWorkoutSkipRest>(_onSkipRest);
    on<ActiveWorkoutNextExercise>(_onNextExercise);
    on<ActiveWorkoutFinish>(_onFinish);
  }

  void _onInit(ActiveWorkoutInit event, Emitter<ActiveWorkoutState> emit) {
    emit(state.copyWith(
      exercises: event.exercises,
      exerciseSets: event.exerciseSets,
      allLogs: List.generate(event.exercises.length, (_) => []),
      currentExerciseIndex: 0,
      currentSet: 1,
      sessionSeconds: 0,
      isResting: false,
    ));

    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(ActiveWorkoutTickSession());
    });
  }

  void _onTickSession(ActiveWorkoutTickSession event, Emitter<ActiveWorkoutState> emit) {
    if (!state.isFinished) {
      emit(state.copyWith(sessionSeconds: state.sessionSeconds + 1));
    }
  }

  void _onTickRest(ActiveWorkoutTickRest event, Emitter<ActiveWorkoutState> emit) {
    if (state.isResting && state.restRemaining > 0) {
      emit(state.copyWith(restRemaining: state.restRemaining - 1));
    } else if (state.isResting && state.restRemaining <= 0) {
      _restTimer?.cancel();
      emit(state.copyWith(isResting: false));
    }
  }

  void _onLogSet(ActiveWorkoutLogSet event, Emitter<ActiveWorkoutState> emit) {
    if (state.isResting) return;

    final newLog = SetLog(
      reps: event.reps,
      weightKg: event.weight,
      loggedAt: DateTime.now(),
    );

    final List<List<SetLog>> newAllLogs = List.from(state.allLogs);
    newAllLogs[state.currentExerciseIndex] = List.from(newAllLogs[state.currentExerciseIndex])..add(newLog);

    final bool isLastSet = state.currentSet >= state.totalSetsPerExercise;
    final bool isLastExercise = state.currentExerciseIndex >= state.exercises.length - 1;

    if (isLastSet && isLastExercise) {
      // Selesai semua
      emit(state.copyWith(
        allLogs: newAllLogs,
        reps: event.reps,
        weight: event.weight,
      ));
      add(ActiveWorkoutFinish());
    } else if (isLastSet) {
      // Pindah ke latihan berikutnya
      emit(state.copyWith(
        allLogs: newAllLogs,
        reps: event.reps,
        weight: event.weight,
        isResting: true,
        restRemaining: 60, // 60s antar latihan
      ));
      _startRestTimer();
    } else {
      // Lanjut set berikutnya, mulai rest
      emit(state.copyWith(
        allLogs: newAllLogs,
        currentSet: state.currentSet + 1,
        reps: event.reps,
        weight: event.weight,
        isResting: true,
        restRemaining: 45, // 45s antar set
      ));
      _startRestTimer();
    }
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(ActiveWorkoutTickRest());
    });
  }

  void _onSkipRest(ActiveWorkoutSkipRest event, Emitter<ActiveWorkoutState> emit) {
    _restTimer?.cancel();
    
    // Jika kita loncat latihan 
    if (state.currentSet >= state.totalSetsPerExercise && 
        state.currentExerciseIndex < state.exercises.length - 1) {
      emit(state.copyWith(
        isResting: false,
        currentExerciseIndex: state.currentExerciseIndex + 1,
        currentSet: 1,
      ));
    } else {
      emit(state.copyWith(isResting: false));
    }
  }

  void _onNextExercise(ActiveWorkoutNextExercise event, Emitter<ActiveWorkoutState> emit) {
    _restTimer?.cancel();
    emit(state.copyWith(
      isResting: false,
      currentExerciseIndex: state.currentExerciseIndex + 1,
      currentSet: 1,
    ));
  }

  void _onFinish(ActiveWorkoutFinish event, Emitter<ActiveWorkoutState> emit) {
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    emit(state.copyWith(isFinished: true, isResting: false));
  }

  @override
  Future<void> close() {
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    return super.close();
  }
}
