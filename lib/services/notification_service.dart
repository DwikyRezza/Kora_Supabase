import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/schedule_event.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
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

  // ── Notifikasi instan ──────────────────────────────────────────────────────
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
            'Kora_channel', 'Kora Notifications',
            channelDescription: 'Default channel for Kora',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: false);
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        id, title, body, platformChannelSpecifics,
        payload: 'item x');
  }

  // ── Jadwal dari ScheduleScreen ─────────────────────────────────────────────

  /// Jadwalkan notifikasi untuk satu event jadwal.
  /// [advanceMinutes] = berapa menit SEBELUM waktu event notifikasi dikirim.
  Future<void> scheduleEventReminder(
    ScheduleEvent event, {
    int advanceMinutes = 30,
  }) async {
    if (event.id == null) return;

    final notifTime = event.dateTime.subtract(Duration(minutes: advanceMinutes));
    if (!notifTime.isAfter(DateTime.now())) return; // sudah lewat, skip

    final advLabel = advanceMinutes >= 60
        ? '${advanceMinutes ~/ 60} jam'
        : '$advanceMinutes menit';

    await flutterLocalNotificationsPlugin.zonedSchedule(
      event.id!,
      event.title,
      'Jadwalmu dimulai $advLabel lagi. Semangat! ',
      tz.TZDateTime.from(notifTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'Kora_schedule', 'Schedule Reminders',
          channelDescription: 'Notifikasi pengingat jadwal latihan',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Penjadwalan ulang semua event setelah setting advance notice berubah.
  Future<void> rescheduleAllEvents(
    List<ScheduleEvent> events, {
    int advanceMinutes = 30,
  }) async {
    // Batalkan semua notif yang ada untuk event jadwal (ID < 900)
    for (final event in events) {
      if (event.id != null) {
        await flutterLocalNotificationsPlugin.cancel(event.id!);
      }
    }
    // Jadwalkan ulang
    for (final event in events) {
      await scheduleEventReminder(event, advanceMinutes: advanceMinutes);
    }
  }

  /// Batalkan notifikasi satu event
  Future<void> cancelEventReminder(int eventId) async {
    await flutterLocalNotificationsPlugin.cancel(eventId);
  }

  // ── Notifikasi protein ─────────────────────────────────────────────────────
  Future<void> scheduleNutritionReminders() async {
    final now = DateTime.now();
    
    // Siang (12:00) - Santai
    var noonDate = DateTime(now.year, now.month, now.day, 12, 0);
    if (noonDate.isBefore(now)) {
      noonDate = noonDate.add(const Duration(days: 1));
    }
    await flutterLocalNotificationsPlugin.zonedSchedule(
      999,
      'Jangan Lupa Makan Siang!',
      'Gimana progress nutrisimu? Jangan sampai kosong ya.',
      tz.TZDateTime.from(noonDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails('Kora_protein', 'Nutrition Reminders', channelDescription: 'Reminders', importance: Importance.defaultImportance),
      ),
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    // Sore (18:00) - Tegas
    var eveningDate = DateTime(now.year, now.month, now.day, 18, 0);
    if (eveningDate.isBefore(now)) {
      eveningDate = eveningDate.add(const Duration(days: 1));
    }
    await flutterLocalNotificationsPlugin.zonedSchedule(
      1000,
      'Waktu hampir habis, Za! 🔥',
      'Segera penuhi target protein/kalori kamu sekarang atau biarkan streak apimu padam malam ini. Disiplin adalah kunci!',
      tz.TZDateTime.from(eveningDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails('Kora_protein_strict', 'Strict Nutrition Reminders', channelDescription: 'Strict Reminders', importance: Importance.high, priority: Priority.high),
      ),
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNutritionReminders() async {
    await flutterLocalNotificationsPlugin.cancel(999);
    await flutterLocalNotificationsPlugin.cancel(1000);
  }

  // biarkan backward-compat ─ masih dipakai di schedule_screen lama
  Future<void> cancelWorkoutReminder(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  // ── Laporan mingguan ───────────────────────────────────────────────────────
  Future<void> scheduleWeeklyProgressReminder({
    int weekday = DateTime.monday,
    int hour = 8,
    int minute = 0,
  }) async {
    final now = DateTime.now();
    int daysUntil = (weekday - now.weekday + 7) % 7;
    if (daysUntil == 0 &&
        (now.hour > hour || (now.hour == hour && now.minute >= minute))) {
      daysUntil = 7;
    }
    final nextDate =
        DateTime(now.year, now.month, now.day + daysUntil, hour, minute);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      998,
      ' Laporan Progress Mingguanmu!',
      'Lihat seberapa jauh perkembanganmu minggu ini di Kora.',
      tz.TZDateTime.from(nextDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'Kora_progress', 'Weekly Progress',
          channelDescription: 'Channel for weekly progress reports',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelWeeklyProgressReminder() async {
    await flutterLocalNotificationsPlugin.cancel(998);
  }
}
