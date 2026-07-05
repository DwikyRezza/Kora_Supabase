import 'package:kora/models/workout.dart';
import 'package:kora/services/database_helper.dart';
import 'package:kora/services/cloud_sync_service.dart';

class WorkoutRepository {
  final DatabaseHelper _localDb;

  WorkoutRepository({DatabaseHelper? localDb}) : _localDb = localDb ?? DatabaseHelper();

  Future<int> insertWorkout(Workout workout) async {
    final id = await _localDb.insertWorkout(workout);
    // Otomatis trigger cloud sync (background)
    CloudSyncService.backupToCloud().catchError((_) {});
    return id;
  }

  Future<int> updateWorkout(Workout workout) async {
    final result = await _localDb.updateWorkout(workout);
    CloudSyncService.backupToCloud().catchError((_) {});
    return result;
  }

  Future<int> deleteWorkout(int id) async {
    final result = await _localDb.deleteWorkout(id);
    CloudSyncService.backupToCloud().catchError((_) {});
    return result;
  }

  Future<List<Workout>> getAllWorkouts() => _localDb.getAllWorkouts();
  Future<List<Workout>> getRecentWorkouts({int limit = 7}) => _localDb.getRecentWorkouts(limit: limit);
  Future<List<Workout>> getWorkoutsByDateRange({required DateTime start, required DateTime end}) => _localDb.getWorkoutsByDateRange(start: start, end: end);
  Future<Map<String, int>> getCalculateWorkoutStreak() => _localDb.getCalculateWorkoutStreak();
  Future<Map<String, double>> getWeeklyWorkoutStats(String type) => _localDb.getWeeklyWorkoutStats(type);
  Future<Map<String, num>> getTodayWorkoutMetrics() => _localDb.getTodayWorkoutMetrics();
}
