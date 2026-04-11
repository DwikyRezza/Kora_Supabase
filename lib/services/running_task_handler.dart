import 'dart:async';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

// ─── Entry point — HARUS top-level function ───────────────────────────────
@pragma('vm:entry-point')
void startRunningTaskCallback() {
  FlutterForegroundTask.setTaskHandler(RunningTaskHandler());
}

// ─── Task Handler: berjalan DI DALAM Android Service ─────────────────────
class RunningTaskHandler extends TaskHandler {
  bool _isRunning = false;
  DateTime? _runStartTime;
  int _elapsedSeconds = 0;
  int _movingSeconds = 0;
  double _distanceKm = 0.0;
  double _elevationGain = 0.0;
  double _maxElevation = -9999.0;
  double _lastAltitude = -9999.0;
  int _lastSplitKm = 0;
  int _lastSplitTimeSeconds = 0;
  final List<String> _splits = [];
  final List<List<double>> _routePoints = [];

  // Buffer posisi terakhir yang VALID untuk kalkulasi jarak
  Position? _lastValidPosition;

  StreamSubscription<Position>? _positionStream;

  // ── Lifecycle ──────────────────────────────────────────────────────────
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('🟢 [SERVICE] RunningTaskHandler started');
    _handleStart({});
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('🔴 [SERVICE] RunningTaskHandler destroyed');
    await _positionStream?.cancel();
    _positionStream = null;
  }

  // ── Repeat event: dipanggil setiap 1 detik ────────────────────────────
  @override
  void onRepeatEvent(DateTime timestamp) {
    if (!_isRunning || _runStartTime == null) return;

    _elapsedSeconds = DateTime.now().difference(_runStartTime!).inSeconds;

    // Update notifikasi setiap 3 detik
    if (_elapsedSeconds % 3 == 0) {
      final paceStr = _distanceKm > 0.01
          ? () {
              final paceMins = (_movingSeconds / 60.0) / _distanceKm;
              if (paceMins > 99) return '--:--';
              final m = paceMins.truncate();
              final s = ((paceMins - m) * 60).truncate().toString().padLeft(2, '0');
              return '$m:$s';
            }()
          : '--:--';
      FlutterForegroundTask.updateService(
        notificationTitle: 'Sesi Lari Sedang Berjalan 🏃',
        notificationText:
            '${_distanceKm.toStringAsFixed(2)} km · ${_formattedTime()} · $paceStr /km',
      );
    }

    // Kirim data ke UI
    FlutterForegroundTask.sendDataToMain({
      'type': 'update',
      'elapsedSeconds': _elapsedSeconds,
      'movingSeconds': _movingSeconds,
      'distanceKm': _distanceKm,
      'elevationGain': _elevationGain,
      'maxElevation': _maxElevation < 0 ? 0.0 : _maxElevation,
      'splits': _splits,
      'routePoints': _routePoints,
      'isRunning': _isRunning,
    });
  }

  // ── Terima perintah dari Flutter UI ───────────────────────────────────
  @override
  void onReceiveData(Object data) {
    print('📨 [SERVICE] Received: $data');
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

  @override
  void onNotificationButtonPressed(String id) {
    print('🔔 [SERVICE] Button: $id');
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
    _maxElevation = -9999.0;
    _lastAltitude = -9999.0;
    _lastSplitKm = 0;
    _lastSplitTimeSeconds = 0;
    _splits.clear();
    _routePoints.clear();
    _lastValidPosition = null;
    print('▶️ [SERVICE] Run started');
    _startGpsStream();
  }

  void _handlePause() {
    _isRunning = false;
    print('⏸️ [SERVICE] Paused at ${_elapsedSeconds}s, dist: ${_distanceKm.toStringAsFixed(3)} km');
    FlutterForegroundTask.updateService(
      notificationTitle: 'Sesi Lari Dijeda ⏸️',
      notificationText:
          '${_distanceKm.toStringAsFixed(2)} km · ${_formattedTime()}',
      notificationButtons: const [
        NotificationButton(id: 'resume_btn', text: 'Lanjut'),
        NotificationButton(id: 'finish_btn', text: 'Finish'),
      ],
    );
  }

  void _handleResume(Map data) {
    // Adjust runStartTime agar elapsed time tetap kontinyu
    _runStartTime =
        DateTime.now().subtract(Duration(seconds: _elapsedSeconds));
    _isRunning = true;
    _lastValidPosition = null; // Reset agar tidak ada lompatan jarak saat resume
    print('▶️ [SERVICE] Resumed, elapsed: ${_elapsedSeconds}s');
    FlutterForegroundTask.updateService(
      notificationTitle: 'Sesi Lari Sedang Berjalan 🏃',
      notificationText:
          '${_distanceKm.toStringAsFixed(2)} km · ${_formattedTime()}',
      notificationButtons: const [
        NotificationButton(id: 'pause_btn', text: 'Pause'),
        NotificationButton(id: 'finish_btn', text: 'Finish'),
      ],
    );
  }

  void _handleStop() {
    _isRunning = false;
    print(
        '⏹️ [SERVICE] Stopped. dist: ${_distanceKm.toStringAsFixed(3)} km, points: ${_routePoints.length}');
    FlutterForegroundTask.sendDataToMain({
      'type': 'final',
      'elapsedSeconds': _elapsedSeconds,
      'movingSeconds': _movingSeconds,
      'distanceKm': _distanceKm,
      'elevationGain': _elevationGain,
      'maxElevation': _maxElevation < 0 ? 0.0 : _maxElevation,
      'splits': jsonEncode(_splits),
      'routePoints': jsonEncode(_routePoints),
    });
  }

  void _startGpsStream() {
    _positionStream?.cancel();
    print('🚀 [SERVICE] Starting GPS stream...');

    // Gunakan AndroidSettings untuk kontrol penuh di Android
    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,       // update setiap 1 meter bergerak
      intervalDuration: const Duration(seconds: 1),
      forceLocationManager: false,
      // Tetap jalan saat layar mati
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: 'GPS aktif merekam rute lari',
        notificationTitle: 'AthleteSync Tracking',
        enableWakeLock: true,
      ),
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (e) {
        print('❌ [SERVICE] GPS error: $e');
        Future.delayed(const Duration(seconds: 3), _startGpsStream);
      },
      cancelOnError: false,
    );
    print('✅ [SERVICE] GPS stream started');
  }

  void _onPositionUpdate(Position position) {
    // Selalu kirim lokasi ke UI (untuk update marker di peta)
    FlutterForegroundTask.sendDataToMain({
      'type': 'location',
      'lat': position.latitude,
      'lng': position.longitude,
      'accuracy': position.accuracy,
      'speed': position.speed,
    });

    // Hanya proses jarak jika sedang running
    if (!_isRunning) return;

    // Filter akurasi buruk — longgarkan ke 50m agar bekerja di HP murah
    if (position.accuracy > 50) {
      print('⚠️ [SERVICE] Bad accuracy: ${position.accuracy}m — skipping distance');
      return;
    }

    // Titik pertama — simpan sebagai awal rute
    if (_lastValidPosition == null) {
      _lastValidPosition = position;
      _routePoints.add([position.latitude, position.longitude]);

      // Init elevasi
      if (position.altitude != 0) {
        _lastAltitude = position.altitude;
        _maxElevation = position.altitude;
      }
      print('📍 [SERVICE] First point recorded: ${position.latitude}, ${position.longitude}');
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

      _routePoints.add([position.latitude, position.longitude]);
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
