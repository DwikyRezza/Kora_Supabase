import 'dart:async';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

// ─── Entry point — HARUS top-level function ───────────────────────────────
// Ini adalah entry point yang dipanggil Android Service saat mulai.
// Wajib @pragma agar tidak di-tree-shake oleh compiler.
@pragma('vm:entry-point')
void startRunningTaskCallback() {
  FlutterForegroundTask.setTaskHandler(RunningTaskHandler());
}

// ─── Task Handler: berjalan DI DALAM Android Service ─────────────────────
// Semua logika tracking (GPS, timer, distance) ada di sini,
// sehingga tetap berjalan meski layar mati / app di-minimise.
class RunningTaskHandler extends TaskHandler {
  // State tracking
  bool _isRunning = false;
  DateTime? _runStartTime;
  int _elapsedSeconds = 0;
  int _movingSeconds = 0;
  double _distanceKm = 0.0;
  double _elevationGain = 0.0;
  double _maxElevation = 0.0;
  double _lastAltitude = 0.0;
  int _lastSplitKm = 0;
  int _lastSplitTimeSeconds = 0;
  final List<String> _splits = [];
  final List<List<double>> _routePoints = []; // [[lat, lng], ...]

  StreamSubscription<Position>? _positionStream;

  // ── Lifecycle: dipanggil saat service dimulai ──────────────────────────
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('🟢 [SERVICE] RunningTaskHandler started (starter: ${starter.name})');
    // Langsung mulai tracking saat service booting (hindari race condition)
    _handleStart({});
  }

  // ── Getter untuk _paceStr ───────────────────────────────────────────────
  String get _paceStr {
    if (_distanceKm < 0.01) return '--:--';
    final paceMins = (_elapsedSeconds / 60.0) / _distanceKm;
    if (paceMins > 99) return '--:--';
    final m = paceMins.truncate();
    final s = ((paceMins - m) * 60).truncate().toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Repeat event: dipanggil setiap 1 detik (dari ForegroundTaskOptions) ─
  @override
  void onRepeatEvent(DateTime timestamp) {
    if (!_isRunning) return;

    _elapsedSeconds = DateTime.now().difference(_runStartTime!).inSeconds;

    // Update notifikasi setiap 2 detik agar selalu up-to-date di layar pull-down
    if (_elapsedSeconds % 2 == 0) {
      FlutterForegroundTask.updateService(
        notificationTitle: 'Sesi Lari Sedang Berjalan 🏃',
        notificationText: 'waktu: ${_formattedTime()} | pace: $_paceStr | jarak: ${_distanceKm.toStringAsFixed(2)} km',
      );
    }

    // Kirim data ke Flutter UI (running_tracker_screen)
    FlutterForegroundTask.sendDataToMain({
      'type': 'update',
      'elapsedSeconds': _elapsedSeconds,
      'movingSeconds': _movingSeconds,
      'distanceKm': _distanceKm,
      'elevationGain': _elevationGain,
      'maxElevation': _maxElevation,
      'splits': _splits,
      'routePoints': _routePoints,
      'isRunning': _isRunning,
    });
  }

  // ── Terima perintah dari Flutter UI ───────────────────────────────────
  @override
  void onReceiveData(Object data) {
    print('📨 [SERVICE] Received command: $data');
    if (data is! Map) return;

    final cmd = data['command'] as String?;
    switch (cmd) {
      case 'start':
        _handleStart(data);
        break;
      case 'pause':
        _handlePause();
        break;
      case 'resume':
        _handleResume(data);
        break;
      case 'stop':
        _handleStop();
        break;
    }
  }

  // ── Lifecycle: dipanggil saat service dihentikan ──────────────────────
  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('🔴 [SERVICE] RunningTaskHandler destroyed');
    _positionStream?.cancel();
  }

  @override
  void onNotificationButtonPressed(String id) {
    print('🔔 [SERVICE] Notification button pressed: $id');
    if (id == 'pause_btn') {
      _handlePause();
      FlutterForegroundTask.sendDataToMain({'type': 'pause_from_notif'});
    } else if (id == 'resume_btn') {
      _handleResume({});
      FlutterForegroundTask.sendDataToMain({'type': 'resume_from_notif'});
    } else if (id == 'finish_btn') {
      _handleStop();
      FlutterForegroundTask.sendDataToMain({'type': 'stop_from_notif'});
    }
  }

  @override
  void onNotificationPressed() {}

  // ─── Private Logic ────────────────────────────────────────────────────

  void _handleStart(Map data) {
    _isRunning = true;
    _runStartTime = DateTime.now();
    _elapsedSeconds = 0;
    _movingSeconds = 0;
    _distanceKm = 0.0;
    _elevationGain = 0.0;
    _maxElevation = 0.0;
    _lastAltitude = 0.0;
    _lastSplitKm = 0;
    _lastSplitTimeSeconds = 0;
    _splits.clear();
    _routePoints.clear();
    print('▶️ [SERVICE] Run started at $_runStartTime');
    
    // Mulai stream GPS di dalam background
    _startGpsStream();
  }

  void _handlePause() {
    _isRunning = false;
    print('⏸️ [SERVICE] Run paused at ${_elapsedSeconds}s');
    FlutterForegroundTask.updateService(
      notificationTitle: 'Sesi Lari Dijeda ⏸️',
      notificationText: 'waktu: ${_formattedTime()} | jarak: ${_distanceKm.toStringAsFixed(2)} km',
      notificationButtons: const [
        NotificationButton(id: 'resume_btn', text: 'Lanjut'),
        NotificationButton(id: 'finish_btn', text: 'Finish'),
      ],
    );
  }

  void _handleResume(Map data) {
    // Hitung ulang runStartTime agar elapsed tetap kontinyu
    _runStartTime = DateTime.now().subtract(Duration(seconds: _elapsedSeconds));
    _isRunning = true;
    print('▶️ [SERVICE] Run resumed, elapsed was: ${_elapsedSeconds}s');
    FlutterForegroundTask.updateService(
      notificationTitle: 'Sesi Lari Sedang Berjalan 🏃',
      notificationText: 'waktu: ${_formattedTime()} | pace: $_paceStr | jarak: ${_distanceKm.toStringAsFixed(2)} km',
      notificationButtons: const [
        NotificationButton(id: 'pause_btn', text: 'Pause'),
        NotificationButton(id: 'finish_btn', text: 'Finish'),
      ],
    );
  }

  void _handleStop() {
    _isRunning = false;
    print('⏹️ [SERVICE] Run stopped');
    // Kirim data final ke UI untuk disimpan ke database
    FlutterForegroundTask.sendDataToMain({
      'type': 'final',
      'elapsedSeconds': _elapsedSeconds,
      'movingSeconds': _movingSeconds,
      'distanceKm': _distanceKm,
      'elevationGain': _elevationGain,
      'maxElevation': _maxElevation,
      'splits': jsonEncode(_splits),
      'routePoints': jsonEncode(_routePoints),
    });
  }

  void _startGpsStream() {
    print('🚀 [SERVICE] Starting GPS stream inside service...');
    _positionStream?.cancel();

    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,       // update setiap 1 meter bergerak
      intervalDuration: const Duration(seconds: 1),
      forceLocationManager: false,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (e) {
        print('❌ [SERVICE] GPS error: $e');
        // Restart GPS stream setelah 3 detik jika error
        Future.delayed(const Duration(seconds: 3), _startGpsStream);
      },
      cancelOnError: false,
    );
    print('✅ [SERVICE] GPS stream started inside service');
  }

  void _onPositionUpdate(Position position) {
    final latLng = [position.latitude, position.longitude];

    // Kirim posisi terbaru ke UI (untuk update peta real-time)
    FlutterForegroundTask.sendDataToMain({
      'type': 'location',
      'lat': position.latitude,
      'lng': position.longitude,
      'accuracy': position.accuracy,
      'speed': position.speed,
      'altitude': position.altitude,
    });

    if (!_isRunning) return;

    // Filter akurasi buruk — longgarkan ke 50m agar bekerja di HP murah
    if (position.accuracy > 50) {
      print('⚠️ [SERVICE] Bad accuracy: ${position.accuracy}m — skipping distance');
      return;
    }

    if (_routePoints.isEmpty) {
      _routePoints.add(latLng);
      _lastAltitude = position.altitude;
      _maxElevation = position.altitude;
      return;
    }

    final lastPoint = _routePoints.last;

    final segmentDistanceM = Geolocator.distanceBetween(
      lastPoint[0], lastPoint[1],
      position.latitude, position.longitude,
    );
    final segmentDistanceKm = segmentDistanceM / 1000.0;

    // Hanya tambah jika 1m – 150m (filter GPS teleport, lebih toleran)
    if (segmentDistanceM >= 1.0 && segmentDistanceM < 150.0) {
      _distanceKm += segmentDistanceKm;
      _movingSeconds++;
      print('✅ [SERVICE] +${segmentDistanceM.toStringAsFixed(1)}m, total: ${(_distanceKm * 1000).toStringAsFixed(0)}m');

      // Elevation
      final altDiff = position.altitude - _lastAltitude;
      if (altDiff > 0.5) _elevationGain += altDiff;
      if (position.altitude > _maxElevation) _maxElevation = position.altitude;
      _lastAltitude = position.altitude;

      // Splits per km
      final currentKm = _distanceKm.floor();
      if (currentKm > _lastSplitKm) {
        final splitTime = _elapsedSeconds - _lastSplitTimeSeconds;
        final m = (splitTime ~/ 60).toString().padLeft(2, '0');
        final s = (splitTime % 60).toString().padLeft(2, '0');
        _splits.add('$m:$s');
        _lastSplitKm = currentKm;
        _lastSplitTimeSeconds = _elapsedSeconds;
      }

      _routePoints.add(latLng);
    } else if (segmentDistanceM >= 150.0) {
      print('⚠️ [SERVICE] GPS teleport: ${segmentDistanceM.toStringAsFixed(0)}m — ignored');
    }
  }

  String _formattedTime() {
    final h = (_elapsedSeconds ~/ 3600);
    final m = ((_elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }
}
