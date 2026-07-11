import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kora/models/workout.dart';
import 'package:kora/services/auth_service.dart';
import 'package:kora/services/database_helper.dart';
import 'package:kora/services/cloud_sync_service.dart';
import 'package:kora/utils/id_generator.dart';

class WorkoutRepository {
  final DatabaseHelper _localDb;

  WorkoutRepository({DatabaseHelper? localDb}) : _localDb = localDb ?? DatabaseHelper();

  Future<String> insertWorkout(Workout workout) async {
    final newId = workout.id ?? IdGenerator.generate();
    // Reconstruct workout with the new UUID if it was null
    final workoutToInsert = Workout(
      id: newId,
      type: workout.type,
      duration: workout.duration,
      distance: workout.distance,
      sets: workout.sets,
      reps: workout.reps,
      weight: workout.weight,
      caloriesBurned: workout.caloriesBurned,
      proteinNeeded: workout.proteinNeeded,
      notes: workout.notes,
      date: workout.date,
      title: workout.title,
      photoPath: workout.photoPath,
      photosJson: workout.photosJson,
      movingTime: workout.movingTime,
      elevationGain: workout.elevationGain,
      maxElevation: workout.maxElevation,
      splitsStr: workout.splitsStr,
      polyline: workout.polyline,
    );

    await _localDb.insertWorkout(workoutToInsert);
    // Otomatis trigger cloud sync (background)
    CloudSyncService.backupToCloud().catchError((_) {});
    return newId;
  }

  Future<void> updateWorkout(Workout workout) async {
    await _localDb.updateWorkout(workout);
    CloudSyncService.backupToCloud().catchError((_) {});
  }

  Future<void> deleteWorkout(String id) async {
    await _localDb.deleteWorkout(id);
    CloudSyncService.backupToCloud().catchError((_) {});
  }

  // --- Methods from WorkoutRepository ---
  // Note: Firestore logic has been removed to respect Clean Architecture (separation of concerns).
  // If cloud data is needed, it should be orchestrated via a RemoteDataSource.
  // Currently, the app will read purely from local SQLite which is synced.
  Future<List<Workout>> getAllWorkouts() async {
    return _localDb.getAllWorkouts();
  }

  Future<List<Workout>> getRecentWorkouts({int limit = 7}) => _localDb.getRecentWorkouts(limit: limit);
  
  Future<List<Workout>> getWorkoutsByDateRange({required DateTime start, required DateTime end}) async {
    return _localDb.getWorkoutsByDateRange(start: start, end: end);
  }

  Future<Map<String, int>> getCalculateWorkoutStreak() async {
    return _localDb.getCalculateWorkoutStreak();
  }

  Future<List<String>> getWorkoutPhotos(String workoutId) async {
    return _localDb.getWorkoutPhotos(workoutId);
  }

  Future<String> addWorkoutPhoto(String workoutId, String filePath) async {
    return _localDb.addWorkoutPhoto(workoutId, filePath);
  }

  Future<Map<String, double>> getWeeklyWorkoutStats(String type) => _localDb.getWeeklyWorkoutStats(type);
  Future<Map<String, num>> getTodayWorkoutMetrics() => _localDb.getTodayWorkoutMetrics();
}
