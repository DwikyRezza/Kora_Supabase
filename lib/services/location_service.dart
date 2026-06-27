import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'running_task_handler.dart'; // untuk startRunningTaskCallback

class LocationService {
  /// Inisialisasi foreground task — panggil SEKALI di awal app (biasanya di main()).
  static void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'running_tracker_channel_v3',
        channelName: 'Running Tracker',
        channelDescription: 'Notifikasi aktif selama sesi lari berlangsung.',
        // MAX agar notifikasi tidak bisa dikuburkan oleh OS / MIUI / OneUI
        channelImportance: NotificationChannelImportance.MAX,
        priority: NotificationPriority.MAX,
        // Matikan suara & getar agar OS tidak throttle/rate-limit notifikasi ini
        enableVibration: false,
        playSound: false,
        showWhen: false,
        // Tampil di atas lockscreen — penting untuk Xiaomi MIUI
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
        iconData: const NotificationIconData(
          resType: ResourceType.drawable,
          resPrefix: ResourcePrefix.ic,
          name: 'stat_logo',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Setiap 1 detik TaskHandler.onRepeatEvent dipanggil
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        allowWakeLock: true, // CPU tetap aktif saat layar mati
        allowWifiLock: true, // WiFi tetap aktif untuk map
      ),
    );
  }

  /// Request semua izin yang diperlukan (notif + battery optimization).
  /// [context] diperlukan untuk menampilkan dialog edukatif battery optimization.
  static Future<void> requestPermissions(BuildContext context) async {
    // 1. Izin notifikasi (Android 13+)
    final notifPerm = await FlutterForegroundTask.checkNotificationPermission();
    if (notifPerm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (!Platform.isAndroid) return;

    // 2. Abaikan optimasi baterai — cek dulu agar tidak minta ulang jika sudah granted
    final isIgnoring =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!isIgnoring) {
      // Tampilkan dialog edukatif sebelum meminta izin sistem (best practice UX)
      final shouldRequest = await _showBatteryOptimizationDialog(context);
      if (shouldRequest) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }
  }

  /// Dialog edukatif agar user mengerti MENGAPA izin battery diperlukan.
  static Future<bool> _showBatteryOptimizationDialog(
      BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.battery_alert, color: Colors.orange),
                SizedBox(width: 8),
                Text('Izin Baterai Diperlukan'),
              ],
            ),
            content: const Text(
              'Untuk melacak rute lari secara akurat saat layar mati, '
              'Kora perlu dikecualikan dari optimasi baterai sistem.\n\n'
              'Tanpa izin ini, GPS bisa berhenti saat layar HP mati dan '
              'rute lari akan menjadi garis lurus.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Nanti Saja'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Izinkan'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Mulai foreground service dengan TaskHandler yang berjalan di dalam service.
  static Future<bool> startService() async {
    // Guard: pastikan izin notifikasi (Android 13+) masih aktif
    final notifPerm = await FlutterForegroundTask.checkNotificationPermission();
    if (notifPerm != NotificationPermission.granted) {
      debugPrint('⚠️ [LocationService] Izin notifikasi belum granted, request...');
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Jika service masih jalan, stop dulu dan tunggu sampai benar-benar berhenti
    if (await FlutterForegroundTask.isRunningService) {
      debugPrint('⚠️ [LocationService] Service masih jalan, stop dulu...');
      await FlutterForegroundTask.stopService();
      // Tunggu sampai service benar-benar berhenti
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (!await FlutterForegroundTask.isRunningService) break;
      }
    }

    debugPrint('🚀 [LocationService] Memulai foreground service...');
    var result = await _doStartService();

    // Retry sekali jika gagal (edge case: service belum fully stopped)
    if (result is! ServiceRequestSuccess) {
      debugPrint('⚠️ [LocationService] Start pertama gagal, retry setelah 500ms...');
      await Future.delayed(const Duration(milliseconds: 500));
      result = await _doStartService();
    }

    if (result is ServiceRequestSuccess) {
      debugPrint('✅ [LocationService] Foreground service berhasil dimulai!');
      return true;
    } else if (result is ServiceRequestFailure) {
      debugPrint('❌ [LocationService] Service GAGAL start setelah retry!');
      debugPrint('❌ [LocationService] Error detail: ${result.error}');
      return false;
    } else {
      debugPrint('❌ [LocationService] Service GAGAL start (unknown): $result');
      return false;
    }
  }

  /// Internal: eksekusi startService tanpa retry logic
  static Future<dynamic> _doStartService() async {
    return await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Berlari',
      notificationText: '00:00 Waktu  ·  --:-- Pace  ·  0.00 Jarak (km)',
      notificationButtons: const [
        NotificationButton(id: 'pause_btn', text: 'Pause'),
        NotificationButton(id: 'finish_btn', text: 'Finish'),
      ],
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
      notificationTitle: 'Sesi Lari Aktif 🏃',
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
