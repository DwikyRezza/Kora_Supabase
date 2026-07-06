import 'package:equatable/equatable.dart';
import '../../../../models/exercise_definition.dart';

class SetLog extends Equatable {
  final int reps;
  final double? weightKg;
  final DateTime loggedAt;

  const SetLog({required this.reps, this.weightKg, required this.loggedAt});

  @override
  List<Object?> get props => [reps, weightKg, loggedAt];
}

class ActiveWorkoutState extends Equatable {
  final List<ExerciseDefinition> exercises;
  final Map<String, int> exerciseSets;
  
  final int currentExerciseIndex;
  final int currentSet;
  final int reps;
  final double weight;
  
  final int sessionSeconds;
  final bool isResting;
  final int restRemaining;
  
  final List<List<SetLog>> allLogs;
  final bool isFinished;

  const ActiveWorkoutState({
    required this.exercises,
    required this.exerciseSets,
    this.currentExerciseIndex = 0,
    this.currentSet = 1,
    this.reps = 10,
    this.weight = 20.0,
    this.sessionSeconds = 0,
    this.isResting = false,
    this.restRemaining = 60,
    this.allLogs = const [],
    this.isFinished = false,
  });

  ExerciseDefinition? get currentExercise => 
      exercises.isNotEmpty && currentExerciseIndex < exercises.length 
          ? exercises[currentExerciseIndex] 
          : null;

  int get totalSetsPerExercise => 
      currentExercise != null ? (exerciseSets[currentExercise!.id] ?? 4) : 4;

  bool get isWeightlifting => currentExercise?.category == 'weighted';

  ActiveWorkoutState copyWith({
    List<ExerciseDefinition>? exercises,
    Map<String, int>? exerciseSets,
    int? currentExerciseIndex,
    int? currentSet,
    int? reps,
    double? weight,
    int? sessionSeconds,
    bool? isResting,
    int? restRemaining,
    List<List<SetLog>>? allLogs,
    bool? isFinished,
  }) {
    return ActiveWorkoutState(
      exercises: exercises ?? this.exercises,
      exerciseSets: exerciseSets ?? this.exerciseSets,
      currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
      currentSet: currentSet ?? this.currentSet,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      sessionSeconds: sessionSeconds ?? this.sessionSeconds,
      isResting: isResting ?? this.isResting,
      restRemaining: restRemaining ?? this.restRemaining,
      allLogs: allLogs ?? this.allLogs,
      isFinished: isFinished ?? this.isFinished,
    );
  }

  @override
  List<Object?> get props => [
        exercises,
        exerciseSets,
        currentExerciseIndex,
        currentSet,
        reps,
        weight,
        sessionSeconds,
        isResting,
        restRemaining,
        allLogs,
        isFinished,
      ];
}
