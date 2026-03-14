import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
            'athletesync_channel', 'AthleteSync Notifications',
            channelDescription: 'Default channel for AthleteSync',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: false);
    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        id, title, body, platformChannelSpecifics,
        payload: 'item x');
  }

  Future<void> scheduleWorkoutReminder(int id, String title, DateTime scheduledTime) async {
    if (scheduledTime.isBefore(DateTime.now())) return;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Waktunya Latihan! 💪',
      'Jadwalmu: $title sudah dekat.',
      tz.TZDateTime.from(scheduledTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
            'athletesync_workout', 'Workout Reminders',
            channelDescription: 'Channel for workout reminders',
            importance: Importance.high,
            priority: Priority.high),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleProteinReminder() async {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, 20, 0); // 20:00
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(Duration(days: 1));
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      999,
      '⚠ Jangan Lupa Protein!',
      'Gimana progress harianmu? Pastikan target protein terpenuhi ya.',
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
            'athletesync_protein', 'Protein Reminders',
            channelDescription: 'Channel for protein reminders',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority),
      ),
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelProteinReminder() async {
    await flutterLocalNotificationsPlugin.cancel(999);
  }

  Future<void> cancelWorkoutReminder(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}
