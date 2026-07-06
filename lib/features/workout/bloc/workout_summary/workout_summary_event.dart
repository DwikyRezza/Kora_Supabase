import 'package:equatable/equatable.dart';
import '../../../../models/exercise_definition.dart';
import '../active_workout/active_workout_state.dart' show SetLog;

abstract class WorkoutSummaryEvent extends Equatable {
  const WorkoutSummaryEvent();

  @override
  List<Object?> get props => [];
}

class WorkoutSummarySaveRequested extends WorkoutSummaryEvent {
  final List<ExerciseDefinition> exercises;
  final List<List<SetLog>> allLogs;
  final int sessionSeconds;
  final double userWeight;
  final String notes;
  final double rpe;

  const WorkoutSummarySaveRequested({
    required this.exercises,
    required this.allLogs,
    required this.sessionSeconds,
    required this.userWeight,
    required this.notes,
    required this.rpe,
  });

  @override
  List<Object?> get props => [
        exercises,
        allLogs,
        sessionSeconds,
        userWeight,
        notes,
        rpe,
      ];
}
