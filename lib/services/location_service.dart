import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'running_task_handler.dart'; // untuk startRunningTaskCallback

class LocationService {
  /// Inisialisasi foreground task — panggil SEKALI di awal app (biasanya di main()).
  static void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'running_tracker_channel',
        channelName: 'Running Tracker',
        channelDescription: 'Notifikasi aktif selama sesi lari berlangsung.',
        // LOW = tidak bunyi/vibrate saat update, tapi tetap tampil di status bar
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Setiap 1 detik TaskHandler.onRepeatEvent dipanggil
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        allowWakeLock: true,  // CPU tetap aktif saat layar mati
        allowWifiLock: true,  // WiFi tetap aktif untuk map
      ),
    );
  }

  /// Request semua izin yang diperlukan (notif + battery optimization).
  static Future<void> requestPermissions() async {
    // 1. Izin notifikasi (Android 13+)
    final notifPerm = await FlutterForegroundTask.checkNotificationPermission();
    if (notifPerm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (Platform.isAndroid) {
      // 2. Abaikan optimasi baterai agar service tidak di-kill saat background
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }
  }

  /// Mulai foreground service dengan TaskHandler yang berjalan di dalam service.
  static Future<void> startService() async {
    if (await FlutterForegroundTask.isRunningService) return;

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Lari  ·  0:00  ·  0.00 km',
      notificationText: 'Mempersiapkan GPS...',
      notificationButtons: const [
        NotificationButton(id: 'pause_btn', text: 'Pause'),
        NotificationButton(id: 'finish_btn', text: 'Stop'),
      ],
      // ← Ini yang membuat TaskHandler berjalan di dalam service
      callback: startRunningTaskCallback,
    );
  }

  /// Kirim perintah ke TaskHandler di dalam service.
  static Future<void> sendCommand(Map<String, dynamic> command) async {
    FlutterForegroundTask.sendDataToTask(command);
  }

  /// Update teks notifikasi (fallback kalau tidak pakai TaskHandler).
  static Future<void> updateNotification({
    required String distance,
    required String time,
  }) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Sesi Lari Aktif ',
      notificationText: '$distance km · $time',
    );
  }

  /// Stop foreground service.
  static Future<void> stopService() async {
    await FlutterForegroundTask.stopService();
  }

  /// Cek apakah service sedang berjalan.
  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }
}
