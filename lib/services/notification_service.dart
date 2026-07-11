import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/schedule_event.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'auth_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final _firestore = FirebaseFirestore.instance;

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

  // ── Notifikasi instan (Lokal) ──────────────────────────────────────────────
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

  // ── Jadwal dari ScheduleScreen (Lokal) ─────────────────────────────────────

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
      event.id.hashCode,
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

  Future<void> rescheduleAllEvents(
    List<ScheduleEvent> events, {
    int advanceMinutes = 30,
  }) async {
    for (final event in events) {
      if (event.id != null) {
        await flutterLocalNotificationsPlugin.cancel(event.id.hashCode);
      }
    }
    for (final event in events) {
      await scheduleEventReminder(event, advanceMinutes: advanceMinutes);
    }
  }

  Future<void> cancelEventReminder(String eventId) async {
    await flutterLocalNotificationsPlugin.cancel(eventId.hashCode);
  }

  // ── Notifikasi protein (Lokal) ─────────────────────────────────────────────
  Future<void> scheduleNutritionReminders() async {
    final now = DateTime.now();
    
    // Siang (12:00)
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

    // Sore (18:00)
    var eveningDate = DateTime(now.year, now.month, now.day, 18, 0);
    if (eveningDate.isBefore(now)) {
      eveningDate = eveningDate.add(const Duration(days: 1));
    }
    await flutterLocalNotificationsPlugin.zonedSchedule(
      1000,
      'Waktu hampir habis, ${AuthService.displayName}! 🔥',
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

  Future<void> cancelWorkoutReminder(String id) async {
    await flutterLocalNotificationsPlugin.cancel(id.hashCode);
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

  // ── Sosial & Cloud Notifications (Firebase) ────────────────────────────────

  static StreamSubscription<QuerySnapshot>? _notifSub;

  static void startListening() {
    if (!AuthService.isLoggedIn) return;
    
    _notifSub?.cancel();
    
    // Gunakan timestamp saat mulai listen agar tidak munculkan notif lama sekaligus
    final startTime = Timestamp.now();
    
    _notifSub = _firestore
        .collection('users')
        .doc(AuthService.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .where('timestamp', isGreaterThanOrEqualTo: startTime)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final title = data['title'] ?? 'Kora';
            final body = data['body'] ?? '';
            NotificationService().showNotification(
              id: change.doc.id.hashCode,
              title: title,
              body: body,
            );
          }
        }
      }
    });
  }

  static void stopListening() {
    _notifSub?.cancel();
    _notifSub = null;
  }

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    if (!AuthService.isLoggedIn) return [];
    
    try {
      final snap = await _firestore
          .collection('users')
          .doc(AuthService.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('[NotificationService] Error getNotifications: $e');
      return [];
    }
  }

  static Future<void> addNotification(String targetUid, {
    required String title,
    required String body,
    required String type, // 'follow', 'reminder', 'system'
    String? relatedUid,
    String? relatedPhotoUrl,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(targetUid)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'type': type,
        'relatedUid': relatedUid,
        'relatedPhotoUrl': relatedPhotoUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('[NotificationService] Error addNotification: $e');
    }
  }

  static Future<void> markAllAsRead() async {
    if (!AuthService.isLoggedIn) return;
    
    try {
      final snap = await _firestore
          .collection('users')
          .doc(AuthService.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      if (snap.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('[NotificationService] Error markAllAsRead: $e');
    }
  }

  static Future<int> getUnreadCount() async {
    if (!AuthService.isLoggedIn) return 0;
    
    try {
      final snap = await _firestore
          .collection('users')
          .doc(AuthService.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
