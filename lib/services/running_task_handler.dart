import 'dart:async';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int _elapsedAtPause = 0; // Elapsed yang tersimpan saat pause
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

  // ── GPS Watchdog ────────────────────────────────────────────────────────
  // Deteksi "silent freeze": stream tidak error tapi juga tidak mengirim data.
  // Sering terjadi saat layar mati di Xiaomi MIUI / Samsung OneUI / ColorOS.
  Timer? _gpsWatchdog;
  DateTime? _lastGpsUpdateTime;
  // Jika tidak ada update GPS selama N detik → anggap freeze → restart stream
  static const int _kWatchdogTimeoutSeconds = 10;

  String _userName = 'Pelari';

  Future<void> _loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('user_name') ?? 'Pelari';
      print('👤 [SERVICE] Loaded username: $_userName');
    } catch (e) {
      print('⚠️ [SERVICE] Failed to load username: $e');
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('🚀 [SERVICE] RunningTaskHandler started');
    await _loadUserName();
    _handleStart({});
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('💀 [SERVICE] RunningTaskHandler destroyed');
    _gpsWatchdog?.cancel();
    _gpsWatchdog = null;
    await _positionStream?.cancel();
    _positionStream = null;
  }

  // ── Repeat event: dipanggil setiap 1 detik ────────────────────────────
  @override
  void onRepeatEvent(DateTime timestamp) {
    if (!_isRunning || _runStartTime == null) return;

    // Elapsed = waktu sejak _runStartTime (sudah di-adjust saat resume)
    _elapsedSeconds = _elapsedAtPause +
        DateTime.now().difference(_runStartTime!).inSeconds;

    // Cek watchdog setiap tick — restart stream jika GPS freeze terdeteksi
    _tickWatchdog();

    // Update notifikasi setiap detik — format: Berlari / Waktu · Pace · Jarak
    FlutterForegroundTask.updateService(
      notificationTitle: 'Berlari',
      notificationText: '${_formattedTime()} Waktu  ·  ${_buildPaceStr()} Pace  ·  ${_distanceKm.toStringAsFixed(2)} Jarak (km)',
      notificationButtons: const [
        NotificationButton(id: 'pause_btn', text: 'Pause'),
        NotificationButton(id: 'finish_btn', text: 'Finish'),
      ],
    );

    // Kirim data ke UI
    FlutterForegroundTask.sendDataToMain({
      'type': 'update',
      'elapsedSeconds': _elapsedSeconds,
      'movingSeconds': _movingSeconds,
      'distanceKm': _distanceKm,
      'elevationGain': _elevationGain,
      'maxElevation': _maxElevation < 0 ? 0.0 : _maxElevation,
      'splits': jsonEncode(_splits),
      'routePoints': jsonEncode(_routePoints),
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
    print('🔘 [SERVICE] Button: $id');
    if (id == 'pause_btn') {
      _handlePause();
      FlutterForegroundTask.sendDataToMain({'type': 'pause_from_notif'});
    } else if (id == 'resume_btn') {
      _handleResume({});
      FlutterForegroundTask.sendDataToMain({'type': 'resume_from_notif'});
    } else if (id == 'finish_btn') {
      _handleStop();
      FlutterForegroundTask.sendDataToMain({'type': 'stop_from_notif'});
      FlutterForegroundTask.launchApp(); // Otomatis buka app saat di stop
    }
  }

  @override
  void onNotificationPressed() {
    // Tap body notifikasi → langsung buka aplikasi KORA ke foreground
    FlutterForegroundTask.launchApp();
  }

  // ─── Private Logic ────────────────────────────────────────────────────

  void _handleStart(Map data) {
    _isRunning = true;
    _runStartTime = DateTime.now();
    _elapsedAtPause = 0;
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
    _lastGpsUpdateTime = null;
    print('▶️ [SERVICE] Run started');
    _startGpsStream();
  }

  void _handlePause() {
    _isRunning = false;
    _elapsedAtPause = _elapsedSeconds; // Simpan elapsed saat ini sebelum pause
    _runStartTime = null; // Reset agar onRepeatEvent skip
    _gpsWatchdog?.cancel();
    _gpsWatchdog = null;
    print('⏸️ [SERVICE] Paused at ${_elapsedSeconds}s, dist: ${_distanceKm.toStringAsFixed(3)} km');
    FlutterForegroundTask.updateService(
      notificationTitle: 'Di-pause',
      notificationText: '${_formattedTime()} Waktu  ·  ${_buildPaceStr()} Pace  ·  ${_distanceKm.toStringAsFixed(2)} Jarak (km)',
      notificationButtons: const [
        NotificationButton(id: 'resume_btn', text: 'Resume'),
        NotificationButton(id: 'finish_btn', text: 'Finish'),
      ],
    );
  }

  void _handleResume(Map data) {
    // _runStartTime di-set ke NOW agar onRepeatEvent mulai menghitung dari 0
    // lalu elapsed final = _elapsedAtPause + diff(now, _runStartTime)
    _runStartTime = DateTime.now();
    _isRunning = true;
    // Reset agar tidak ada lompatan jarak saat resume
    _lastValidPosition = null;
    // Reset watchdog agar tidak langsung trigger restart
    _lastGpsUpdateTime = DateTime.now();
    print('▶️ [SERVICE] Resumed, elapsed so far: ${_elapsedAtPause}s');
    FlutterForegroundTask.updateService(
      notificationTitle: 'Berlari',
      notificationText: '${_formattedTime()} Waktu  ·  ${_buildPaceStr()} Pace  ·  ${_distanceKm.toStringAsFixed(2)} Jarak (km)',
      notificationButtons: const [
        NotificationButton(id: 'pause_btn', text: 'Pause'),
        NotificationButton(id: 'finish_btn', text: 'Finish'),
      ],
    );
  }

  void _handleStop() {
    _isRunning = false;
    _gpsWatchdog?.cancel();
    _gpsWatchdog = null;
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

  // ─── GPS Stream (PERBAIKAN UTAMA) ─────────────────────────────────────

  void _startGpsStream() {
    _positionStream?.cancel();
    _gpsWatchdog?.cancel();
    _gpsWatchdog = null;
    print('📡 [SERVICE] Starting GPS stream...');

    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, // Ubah dari 1 ke 0 agar GPS merekam pergerakan mikro
      intervalDuration: const Duration(seconds: 1),

      // ── KRITIS #1: forceLocationManager = true ──────────────────────────
      // Bypass Fused Location Provider (FLP) dan langsung ke LocationManager
      // hardware (GPS/GNSS chip). FLP bisa dibekukan Doze Mode, sedangkan
      // LocationManager jauh lebih tahan terhadap agresivitas baterai.
      forceLocationManager: true,

      // Gunakan Mean Sea Level altitude agar data elevasi/ketinggian akurat
      useMSLAltitude: true,
      
      // CATATAN PENTING: Jangan gunakan foregroundNotificationConfig di sini!
      // Karena kita sudah menggunakan flutter_foreground_task sebagai pengelola
      // foreground service. Memaksa Geolocator membuat foreground service kedua
      // tanpa deklarasi di AndroidManifest akan menyebabkan crash seketika!
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (e) {
        print('❌ [SERVICE] GPS error: $e');
        // Auto-restart stream setelah error dengan backoff 3 detik
        Future.delayed(const Duration(seconds: 3), _startGpsStream);
      },
      cancelOnError: false,
    );

    // Mulai watchdog timer setelah stream berjalan
    _startGpsWatchdog();
    print('✅ [SERVICE] GPS stream started (forceLocationManager=true)');
  }

  // ─── GPS Watchdog ──────────────────────────────────────────────────────

  /// Mulai watchdog timer periodik.
  /// Jika tidak ada update GPS selama [_kWatchdogTimeoutSeconds] detik,
  /// stream dianggap freeze secara diam-diam dan akan di-restart otomatis.
  void _startGpsWatchdog() {
    _gpsWatchdog?.cancel();
    _lastGpsUpdateTime = DateTime.now();
    _gpsWatchdog = Timer.periodic(
      const Duration(seconds: _kWatchdogTimeoutSeconds),
      (_) {
        if (!_isRunning) return;
        final lastUpdate = _lastGpsUpdateTime;
        if (lastUpdate == null) return;
        final secondsSinceUpdate =
            DateTime.now().difference(lastUpdate).inSeconds;
        if (secondsSinceUpdate >= _kWatchdogTimeoutSeconds) {
          print(
            '🐕 [WATCHDOG] GPS freeze! ${secondsSinceUpdate}s tanpa update. '
            'Restart stream...',
          );
          // Reset anchor agar tidak ada garis lurus saat GPS aktif kembali
          _lastValidPosition = null;
          _startGpsStream();
        }
      },
    );
  }

  /// Dipanggil setiap tick onRepeatEvent saat running.
  /// Jika watchdog tidak aktif (misal setelah resume), hidupkan kembali.
  void _tickWatchdog() {
    if (_gpsWatchdog == null || !_gpsWatchdog!.isActive) {
      _startGpsWatchdog();
    }
  }

  // ─── Position Update ──────────────────────────────────────────────────

  void _onPositionUpdate(Position position) {
    // Update watchdog timestamp setiap kali dapat data GPS
    _lastGpsUpdateTime = DateTime.now();

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

    // Filter akurasi buruk — 100m agar toleran di HP nyata / area terbuka
    // Jika tidak ada titik sama sekali, terima akurasi apapun agar rute mulai terekam
    if (position.accuracy > 100 && _routePoints.isNotEmpty) {
      print('⚠️ [SERVICE] Bad accuracy: ${position.accuracy}m — skipping');
      return;
    }

    // Titik pertama — simpan sebagai awal rute
    if (_lastValidPosition == null || _routePoints.isEmpty) {
      _lastValidPosition = position;
      _routePoints.add([position.latitude, position.longitude]);

      // Init elevasi
      if (position.altitude != 0) {
        _lastAltitude = position.altitude;
        _maxElevation = position.altitude;
      }
      print(
          '[SERVICE] First point recorded: ${position.latitude}, ${position.longitude}, acc=${position.accuracy}m');
      return;
    }

    final lastPoint = _routePoints.last;

    final segmentDistanceM = Geolocator.distanceBetween(
      lastPoint[0], lastPoint[1],
      position.latitude, position.longitude,
    );
    final segmentDistanceKm = segmentDistanceM / 1000.0;

    if (segmentDistanceM >= 200.0) {
      // GPS teleport (sering terjadi saat layar menyala setelah freeze)
      // Reset _lastValidPosition ke null sehingga titik berikutnya dianggap
      // "titik pertama baru" — mencegah garis lurus di peta.
      print(
          '⚠️ [SERVICE] GPS teleport: ${segmentDistanceM.toStringAsFixed(0)}m — reset anchor');
      _lastValidPosition = null;
      return;
    }

    // Filter drift statis: abaikan pergerakan kecil jika akurasi buruk
    if (segmentDistanceM < 2.0 && position.accuracy > 15.0) {
      print('⚠️ [SERVICE] Drift terdeteksi (acc: ${position.accuracy}m). Diabaikan.');
      return;
    }

    // Threshold 0.1m (sangat sensitif untuk merekam jarak aktual di tikungan)
    if (segmentDistanceM >= 0.1) {
      _distanceKm += segmentDistanceKm;
      _movingSeconds++;
      _lastValidPosition = position;
      print(
          '✅ [SERVICE] +${segmentDistanceM.toStringAsFixed(1)}m, total: ${(_distanceKm * 1000).toStringAsFixed(0)}m, acc:${position.accuracy.toStringAsFixed(0)}m');

      // Elevation
      if (_lastAltitude > -9000 && position.altitude != 0) {
        final altDiff = position.altitude - _lastAltitude;
        if (altDiff > 0.5) _elevationGain += altDiff;
        if (position.altitude > _maxElevation) _maxElevation = position.altitude;
      }
      if (position.altitude != 0) _lastAltitude = position.altitude;

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
    }
  }

  String _formattedTime() {
    final h = (_elapsedSeconds ~/ 3600);
    final m = ((_elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  String _buildPaceStr() {
    if (_distanceKm < 0.01 || _movingSeconds == 0) return '--:--';
    final paceMins = (_movingSeconds / 60.0) / _distanceKm;
    if (paceMins > 99) return '--:--';
    final m = paceMins.truncate();
    final s = ((paceMins - m) * 60).truncate().toString().padLeft(2, '0');
    return '$m:$s';
  }
}
