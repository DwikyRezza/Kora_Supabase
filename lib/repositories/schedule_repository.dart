import '../models/schedule_event.dart';
import '../services/database_helper.dart';

class ScheduleRepository {
  final DatabaseHelper _db;

  ScheduleRepository({DatabaseHelper? dbHelper}) 
      : _db = dbHelper ?? DatabaseHelper();

  Future<int> insertScheduleEvent(ScheduleEvent event) async {
    return await _db.insertScheduleEvent(event);
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

  Future<int> updateScheduleEventCompletion(int id, bool isCompleted) async {
    return await _db.updateScheduleEventCompletion(id, isCompleted);
  }

  Future<int> updateScheduleEvent(ScheduleEvent event) async {
    return await _db.updateScheduleEvent(event);
  }

  Future<int> deleteScheduleEvent(int id) async {
    return await _db.deleteScheduleEvent(id);
  }
}
