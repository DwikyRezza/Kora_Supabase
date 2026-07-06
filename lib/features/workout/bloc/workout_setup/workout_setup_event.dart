import 'package:equatable/equatable.dart';

abstract class WorkoutSetupEvent extends Equatable {
  const WorkoutSetupEvent();

  @override
  List<Object?> get props => [];
}

class WorkoutSetupInit extends WorkoutSetupEvent {}

class WorkoutSetupModeSelected extends WorkoutSetupEvent {
  final String mode;
  const WorkoutSetupModeSelected(this.mode);

  @override
  List<Object?> get props => [mode];
}

class WorkoutSetupMuscleToggled extends WorkoutSetupEvent {
  final String muscle;
  const WorkoutSetupMuscleToggled(this.muscle);

  @override
  List<Object?> get props => [muscle];
}

class WorkoutSetupSearchQueryChanged extends WorkoutSetupEvent {
  final String query;
  const WorkoutSetupSearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class WorkoutSetupExerciseToggled extends WorkoutSetupEvent {
  final String exerciseId;
  const WorkoutSetupExerciseToggled(this.exerciseId);

  @override
  List<Object?> get props => [exerciseId];
}

class WorkoutSetupExerciseSetsChanged extends WorkoutSetupEvent {
  final String exerciseId;
  final int sets;
  const WorkoutSetupExerciseSetsChanged(this.exerciseId, this.sets);

  @override
  List<Object?> get props => [exerciseId, sets];
}

class WorkoutSetupExerciseReordered extends WorkoutSetupEvent {
  final int oldIndex;
  final int newIndex;
  const WorkoutSetupExerciseReordered(this.oldIndex, this.newIndex);

  @override
  List<Object?> get props => [oldIndex, newIndex];
}

class WorkoutSetupNextPageRequested extends WorkoutSetupEvent {}

class WorkoutSetupPrevPageRequested extends WorkoutSetupEvent {}

class WorkoutSetupPageChanged extends WorkoutSetupEvent {
  final int pageIndex;
  const WorkoutSetupPageChanged(this.pageIndex);

  @override
  List<Object?> get props => [pageIndex];
}
