import 'package:equatable/equatable.dart';
import '../../../../models/exercise_definition.dart';

abstract class ActiveWorkoutEvent extends Equatable {
  const ActiveWorkoutEvent();

  @override
  List<Object?> get props => [];
}

class ActiveWorkoutInit extends ActiveWorkoutEvent {
  final List<ExerciseDefinition> exercises;
  final Map<String, int> exerciseSets;

  const ActiveWorkoutInit(this.exercises, this.exerciseSets);

  @override
  List<Object?> get props => [exercises, exerciseSets];
}

class ActiveWorkoutTickSession extends ActiveWorkoutEvent {}

class ActiveWorkoutTickRest extends ActiveWorkoutEvent {}

class ActiveWorkoutLogSet extends ActiveWorkoutEvent {
  final int reps;
  final double weight;

  const ActiveWorkoutLogSet(this.reps, this.weight);

  @override
  List<Object?> get props => [reps, weight];
}

class ActiveWorkoutSkipRest extends ActiveWorkoutEvent {}

class ActiveWorkoutNextExercise extends ActiveWorkoutEvent {}

class ActiveWorkoutFinish extends ActiveWorkoutEvent {}
