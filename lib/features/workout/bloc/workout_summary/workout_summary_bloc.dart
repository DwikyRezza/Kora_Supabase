import 'package:flutter_bloc/flutter_bloc.dart';
import 'workout_summary_event.dart';
import 'workout_summary_state.dart';
import '../../../../models/workout.dart';
import '../../../../services/database_helper.dart';
import '../../../../services/cloud_sync_service.dart';
import '../../../../services/social_service.dart';

class WorkoutSummaryBloc extends Bloc<WorkoutSummaryEvent, WorkoutSummaryState> {
  final DatabaseHelper _db = DatabaseHelper();

  WorkoutSummaryBloc() : super(const WorkoutSummaryState()) {
    on<WorkoutSummarySaveRequested>(_onSaveRequested);
  }

  Future<void> _onSaveRequested(
    WorkoutSummarySaveRequested event,
    Emitter<WorkoutSummaryState> emit,
  ) async {
    emit(state.copyWith(status: WorkoutSummaryStatus.saving));

    try {
      final durationMins = event.sessionSeconds / 60.0;
      
      final int totalSets = event.allLogs.fold(0, (sum, logs) => sum + logs.length);
      
      final List<String> exNames = event.exercises.map((e) => e.name).toList();
      String title = exNames.length > 2 
          ? '${exNames.take(2).join(', ')} +${exNames.length - 2} lainnya' 
          : exNames.join(' & ');
          
      String detailLogs = '';
      for (int i = 0; i < event.exercises.length; i++) {
        if (event.allLogs[i].isEmpty) continue;
        detailLogs += '${event.exercises[i].name}:\n';
        for (int s = 0; s < event.allLogs[i].length; s++) {
          final l = event.allLogs[i][s];
          detailLogs += '  Set ${s+1}: ${l.reps} reps ${l.weightKg != null ? 'x ${l.weightKg}kg' : ''}\n';
        }
      }

      int totalReps = event.allLogs.fold(0, (sum, logs) => sum + logs.fold(0, (s, l) => s + l.reps));
      double totalVolumeKg = event.allLogs.fold(0.0, (sum, logs) => sum + logs.fold(0.0, (s, l) => s + (l.reps * (l.weightKg ?? 1.0))));
      int totalCalories = Workout.calculateCalories('weightlifting', durationMins.clamp(1, 9999));

      final workout = Workout(
        type: 'weightlifting',
        duration: durationMins.clamp(1, 9999),
        reps: totalReps,
        sets: totalSets,
        weight: totalVolumeKg,
        caloriesBurned: totalCalories,
        proteinNeeded: Workout.calculateProteinNeeded('weightlifting', durationMins.clamp(1, 9999), weight: event.userWeight),
        date: DateTime.now(),
        title: title,
        notes: '${event.notes.isNotEmpty ? 'Catatan: ${event.notes}\n' : ''}Intensitas (RPE): ${event.rpe.toInt()}/10\n\nDetail Latihan:\n$detailLogs',
      );
      
      await _db.insertWorkout(workout);
      CloudSyncService.syncWorkoutsToCloud().catchError((_) {});
      SocialService.publishWorkoutToFeed(workout.toMap()).catchError((_) {});

      emit(state.copyWith(status: WorkoutSummaryStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: WorkoutSummaryStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }
}
