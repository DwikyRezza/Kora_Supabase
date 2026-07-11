import '../models/schedule_event.dart';
import '../services/database_helper.dart';
import '../services/cloud_sync_service.dart';
import '../utils/id_generator.dart';

class ScheduleRepository {
  final DatabaseHelper _db;

  ScheduleRepository({DatabaseHelper? dbHelper}) 
      : _db = dbHelper ?? DatabaseHelper();

  Future<String> insertScheduleEvent(ScheduleEvent event) async {
    final newEvent = event.copyWith(id: IdGenerator.generate());
    await _db.insertScheduleEvent(newEvent);
    CloudSyncService.backupToCloud().catchError((_) {});
    return newEvent.id!;
  }

  Future<List<ScheduleEvent>> getScheduleEventsByDate(DateTime date) async {
    return await _db.getScheduleEventsByDate(date);
  }

  Future<List<ScheduleEvent>> getUpcomingEvents() async {
    return await _db.getUpcomingEvents();
  }

  Future<List<ScheduleEvent>> getAllScheduleEvents() async {
    return await _db.getAllScheduleEvents();
  }

  Future<void> updateScheduleEventCompletion(String id, bool isCompleted) async {
    await _db.updateScheduleEventCompletion(id, isCompleted);
    CloudSyncService.backupToCloud().catchError((_) {});
  }

  Future<void> updateScheduleEvent(ScheduleEvent event) async {
    await _db.updateScheduleEvent(event);
    CloudSyncService.backupToCloud().catchError((_) {});
  }

  Future<void> deleteScheduleEvent(String id) async {
    await _db.deleteScheduleEvent(id);
    CloudSyncService.backupToCloud().catchError((_) {});
  }
}
