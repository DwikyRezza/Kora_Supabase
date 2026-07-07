import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kora/models/workout.dart';
import 'package:kora/services/auth_service.dart';
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

  Future<List<Workout>> getAllWorkouts() async {
    if (AuthService.isLoggedIn) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(AuthService.uid)
            .collection('workouts')
            .get();
        if (snap.docs.isNotEmpty) {
          final workouts = snap.docs.map((doc) {
            final data = doc.data();
            data['id'] = int.tryParse(doc.id) ?? data['id'] ?? 0;
            return Workout.fromMap(data);
          }).toList();
          workouts.sort((a, b) => b.date.compareTo(a.date));
          return workouts;
        }
      } catch (e) {
        print('[WorkoutRepository] Failed to fetch from cloud: $e');
      }
    }
    return _localDb.getAllWorkouts();
  }

  Future<List<Workout>> getRecentWorkouts({int limit = 7}) => _localDb.getRecentWorkouts(limit: limit);
  Future<List<Workout>> getWorkoutsByDateRange({required DateTime start, required DateTime end}) async {
    if (AuthService.isLoggedIn) {
      try {
        final all = await getAllWorkouts();
        return all.where((w) {
          return w.date.isAfter(start.subtract(const Duration(seconds: 1))) && 
                 w.date.isBefore(end.add(const Duration(seconds: 1)));
        }).toList();
      } catch (e) {
        print('[WorkoutRepository] Failed to fetch date range from cloud: $e');
      }
    }
    return _localDb.getWorkoutsByDateRange(start: start, end: end);
  }
  Future<Map<String, int>> getCalculateWorkoutStreak() async {
    if (AuthService.isLoggedIn) {
      try {
        final all = await getAllWorkouts();
        if (all.isEmpty) return {'current': 0, 'best': 0};

        Set<String> dateStrings = all.map((w) => w.date.toIso8601String().split('T')[0]).toSet();
        List<String> dates = dateStrings.toList()..sort((a, b) => b.compareTo(a));

        int bestStreak = 0;
        int currentStreak = 0;
        int tempStreak = 1;

        for (int i = 0; i < dates.length - 1; i++) {
          DateTime d1 = DateTime.parse(dates[i]);
          DateTime d2 = DateTime.parse(dates[i + 1]);
          if (d1.difference(d2).inDays == 1) {
            tempStreak++;
          } else {
            if (tempStreak > bestStreak) bestStreak = tempStreak;
            tempStreak = 1;
          }
        }
        if (tempStreak > bestStreak) bestStreak = tempStreak;

        DateTime today = DateTime.now();
        String todayStr = today.toIso8601String().split('T')[0];
        DateTime yesterday = today.subtract(const Duration(days: 1));
        String yesterdayStr = yesterday.toIso8601String().split('T')[0];

        bool hasToday = dates.contains(todayStr);
        bool hasYesterday = dates.contains(yesterdayStr);

        if (!hasToday && !hasYesterday) {
          currentStreak = 0;
        } else {
          DateTime checkDate = hasToday ? today : yesterday;
          for (int i = 0; i < dates.length; i++) {
            DateTime expectedDate = DateTime(checkDate.year, checkDate.month, checkDate.day - i);
            String expectedDateStr = expectedDate.toIso8601String().split('T')[0];
            if (dates.contains(expectedDateStr)) {
              currentStreak++;
            } else {
              break;
            }
          }
        }
        return {'current': currentStreak, 'best': bestStreak};
      } catch (e) {
        print('[WorkoutRepository] Failed to calculate streak from cloud: $e');
      }
    }
    return _localDb.getCalculateWorkoutStreak();
  }
  Future<Map<String, double>> getWeeklyWorkoutStats(String type) => _localDb.getWeeklyWorkoutStats(type);
  Future<Map<String, num>> getTodayWorkoutMetrics() => _localDb.getTodayWorkoutMetrics();
}
