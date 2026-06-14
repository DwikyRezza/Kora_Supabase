import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/workout.dart';
import '../services/database_helper.dart';
import '../services/location_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/social_service.dart';
import '../utils/responsive.dart';
import '../utils/tab_visibility.dart';

class RunningTrackerScreen extends StatefulWidget {
  final double userWeight;
  const RunningTrackerScreen({super.key, required this.userWeight});

  @override
  State<RunningTrackerScreen> createState() => _RunningTrackerScreenState();
}

class _RunningTrackerScreenState extends State<RunningTrackerScreen>
    with WidgetsBindingObserver {
  // ── Google Maps controller ────────────────────────────────────────────
  final Completer<GoogleMapController> _mapController = Completer();
  static const String _mapStyleDark = '''[
    {"elementType":"geometry","stylers":[{"color":"#212121"}]},
    {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
    {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},
    {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
    {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
    {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},
    {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
    {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#181818"}]},
    {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
    {"featureType":"poi.park","elementType":"labels.text.stroke","stylers":[{"color":"#1b1b1b"}]},
    {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
    {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
    {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},
    {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
    {"featureType":"road.highway.controlled_access","elementType":"geometry","stylers":[{"color":"#4e4e4e"}]},
    {"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
    {"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},
    {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}
  ]''';

  // ── State UI ──────────────────────────────────────────────────────────
  List<LatLng> _routePoints = [];
  LatLng? _currentLocation;
  bool _isRunning = false;
  bool _hasStarted = false;
  bool _showPauseStopScreen = false;
  double _distanceKm = 0.0;
  int _elapsedSeconds = 0;
  int _movingSeconds = 0;
  double _elevationGain = 0.0;
  double _maxElevation = 0.0;
  List<String> _splits = [];
  bool _isSaving = false; // Guard agar tidak double-save

  // ── Marker kustom ─────────────────────────────────────────────────────
  BitmapDescriptor? _locationMarker;

  // ── Local UI timer ────────────────────────────────────────────────────
  Timer? _uiTimer;
  DateTime? _uiRunStartTime;
  int _elapsedBeforePause = 0;

  // ── Splits tracking (dihitung di screen langsung) ─────────────────────
  int _lastSplitKm = 0;
  int _lastSplitTimeSeconds = 0;

  // ── Data final untuk disimpan ─────────────────────────────────────────
  String? _finalSplitsJson;
  String? _finalRouteJson;

  // ── GPS stream awal (sebelum lari dimulai) ────────────────────────────
  StreamSubscription<Position>? _initialLocationStream;

  // ── Flag background ────────────────────────────────────────────────────
  bool _isInBackground = false;
  DateTime? _backgroundStartTime; // Waktu tepat saat app di-minimize
  int _lastServiceElapsed = 0;   // Elapsed terakhir diterima dari service
  double _lastServiceDistance = 0.0; // Distance terakhir dari service

  // ── Flag tab visibility (IndexedStack optimization) ─────────────────────
  // true = tab Workout visible (RunningTrackerScreen mungkin terlihat)
  // false = user pindah tab → pause GPS stream, skip setState, stop camera
  bool _isMapVisible = true;
  DateTime? _tabHiddenTime;

  // ── ValueNotifiers — granular metric updates tanpa rebuild seluruh screen ─
  // Updated every second by timer & on GPS/service data change.
  // Only the small ValueListenableBuilder widgets that listen to these
  // will rebuild — GoogleMap, buttons, GPS badge stay untouched.
  final ValueNotifier<int> _elapsedNotifier = ValueNotifier<int>(0);
  final ValueNotifier<double> _distanceNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<String> _paceNotifier = ValueNotifier<String>('--:--');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TabVisibility.instance.addListener(_onTabVisibilityChanged);
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    _createLocationMarker();
    _initGps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    TabVisibility.instance.removeListener(_onTabVisibilityChanged);
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _uiTimer?.cancel();
    _initialLocationStream?.cancel();
    _elapsedNotifier.dispose();
    _distanceNotifier.dispose();
    _paceNotifier.dispose();
    super.dispose();
  }

  // ── Buat marker lingkaran kustom ──────────────────────────────────────
  Future<void> _createLocationMarker() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    const double size = 80;

    // Lingkaran luar (semi-transparan)
    final Paint outerPaint = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, outerPaint);

    // Border putih
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(
        const Offset(size / 2, size / 2), size / 2 - 2, borderPaint);

    // Titik biru solid di tengah
    final Paint innerPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), 14, innerPaint);

    final img =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data != null && mounted) {
      setState(() {
        _locationMarker = BitmapDescriptor.bytes(data.buffer.asUint8List());
      });
    }
  }

  // ── Local UI timer ────────────────────────────────────────────────────
  void _startUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isMapVisible) return;
      if (_uiRunStartTime != null) {
        final newElapsed = _elapsedBeforePause +
            DateTime.now().difference(_uiRunStartTime!).inSeconds;
        // Update ValueNotifier TANPA setState — hanya widget metrics yang rebuild
        _elapsedSeconds = newElapsed;
        _elapsedNotifier.value = newElapsed;
        _recalcPace();
      }
    });
  }

  void _stopUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = null;
  }

  // ── Terima data dari TaskHandler (GPS dari background service) ─────────
  void _onReceiveTaskData(Object data) {
    if (!mounted || data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final type = map['type'] as String?;

    if (type == 'location') {
      final lat = map['lat'] as double?;
      final lng = map['lng'] as double?;
      final accuracy = (map['accuracy'] as num?)?.toDouble() ?? 100.0;
      if (lat == null || lng == null) return;

      final newLoc = LatLng(lat, lng);
      if (!mounted) return;
      // Simpan lokasi tanpa setState saat tab hidden — hemat rebuild
      _currentLocation = newLoc;
      if (_isMapVisible) {
        if (mounted) setState(() {});
        if (_isRunning) _animateCameraToLocation(newLoc);
      }
    } else if (type == 'update') {
      // ── Selalu simpan nilai terbaru dari service ke variabel tracking ────
      // Ini penting agar saat UI resume dari background, data sudah tersedia
      final svcElapsedRaw = (map['elapsedSeconds'] as num?)?.toInt() ?? 0;
      final svcDistRaw = (map['distanceKm'] as num?)?.toDouble() ?? 0.0;
      if (svcElapsedRaw > 0) _lastServiceElapsed = svcElapsedRaw;
      if (svcDistRaw > 0) _lastServiceDistance = svcDistRaw;

      // ── Merge data service ke UI (hanya jika mounted) ─────────────────
      if (!mounted) return;

      // Selalu update variabel data (tanpa setState) — murah dan perlu untuk sync
      if (_isInBackground || !_isMapVisible) {
        // Saat di background atau tab hidden: service adalah sumber kebenaran penuh
        if (svcDistRaw > 0) _distanceKm = svcDistRaw;

        final svcMoving = (map['movingSeconds'] as num?)?.toInt();
        if (svcMoving != null) _movingSeconds = svcMoving;

        if (svcElapsedRaw > 0) {
          _elapsedSeconds = svcElapsedRaw;
          _elapsedBeforePause = svcElapsedRaw;
        }
      } else {
        // Saat foreground & visible: UI menghitung jarak sendiri, tapi terima
        // nilai service jika lebih besar
        if (svcDistRaw > _distanceKm) _distanceKm = svcDistRaw;

        final svcMoving = (map['movingSeconds'] as num?)?.toInt() ?? 0;
        if (svcMoving > _movingSeconds) _movingSeconds = svcMoving;

        // Sync elapsed HANYA jika UI timer mati
        if (_uiTimer == null || !_uiTimer!.isActive) {
          if (svcElapsedRaw > 0) _elapsedSeconds = svcElapsedRaw;
        }
      }

      _elevationGain =
          (map['elevationGain'] as num?)?.toDouble() ?? _elevationGain;
      _maxElevation =
          (map['maxElevation'] as num?)?.toDouble() ?? _maxElevation;

      // Sync splits dari service
      final rawSplits = map['splits'];
      if (rawSplits is String) {
        try {
          final decoded = jsonDecode(rawSplits);
          if (decoded is List) _splits = List<String>.from(decoded);
        } catch (_) {}
      } else if (rawSplits is List) {
        _splits = List<String>.from(rawSplits);
      }

      // Hanya pakai route dari service jika lebih banyak titiknya
      final rawRoute = map['routePoints'];
      List<LatLng>? svcRoute;
      if (rawRoute is String) {
        try {
          final decoded = jsonDecode(rawRoute);
          if (decoded is List && decoded.isNotEmpty) {
            final parsed = <LatLng>[];
            for (final p in decoded) {
              if (p is List && p.length >= 2) {
                try {
                  parsed.add(LatLng(
                      (p[0] as num).toDouble(), (p[1] as num).toDouble()));
                } catch (_) {}
              }
            }
            if (parsed.isNotEmpty) svcRoute = parsed;
          }
        } catch (_) {}
      }
      final bool hasNewRoute = svcRoute != null && svcRoute.length > _routePoints.length;
      if (hasNewRoute) {
        _routePoints = svcRoute;
      }

      // Sync ValueNotifiers — metric widgets update granularly, no full rebuild.
      _syncAllNotifiers();
      // Rebuild map only when new route points arrived from service
      if (_isMapVisible && hasNewRoute) {
        setState(() {});
      }
    } else if (type == 'final') {
      // Saat selesai: ambil data terbaik (max) antara service & UI
      if (!mounted) return;
      final svcDist = (map['distanceKm'] as num?)?.toDouble() ?? 0.0;
      if (svcDist > _distanceKm) _distanceKm = svcDist;

      final svcMoving = (map['movingSeconds'] as num?)?.toInt() ?? 0;
      if (svcMoving > _movingSeconds) _movingSeconds = svcMoving;

      _elevationGain =
          (map['elevationGain'] as num?)?.toDouble() ?? _elevationGain;
      _maxElevation =
          (map['maxElevation'] as num?)?.toDouble() ?? _maxElevation;

      // Simpan splits dari service jika ada
      try {
        final splitsJson = map['splits'] as String?;
        if (splitsJson != null) _finalSplitsJson = splitsJson;
      } catch (_) {}

      // Simpan route dari service jika ada dan lebih panjang
      try {
        final routeJson = map['routePoints'] as String?;
        if (routeJson != null) {
          final decoded = jsonDecode(routeJson);
          if (decoded is List && decoded.length > _routePoints.length) {
            _finalRouteJson = routeJson; // Service punya lebih banyak titik
          }
        }
      } catch (_) {}

      _saveRunToDatabase(); // Guard _isSaving ada di dalam method ini
    } else if (type == 'pause_from_notif') {
      _stopUiTimer();
      _elapsedBeforePause = _elapsedSeconds;
      setState(() {
        _isRunning = false;
        _showPauseStopScreen = true;
      });
    } else if (type == 'resume_from_notif') {
      _uiRunStartTime = DateTime.now();
      _startUiTimer();
      setState(() {
        _isRunning = true;
        _showPauseStopScreen = false;
      });
    } else if (type == 'stop_from_notif') {
      if (!_isSaving) _stopRun();
    }
  }

  /// Generates a time-aware default activity title.
  String _defaultActivityTitle(String type, DateTime date) {
    final hour = date.hour;
    String timeLabel;
    if (hour >= 5 && hour < 10) {
      timeLabel = 'Morning';
    } else if (hour >= 10 && hour < 14) {
      timeLabel = 'Midday';
    } else if (hour >= 14 && hour < 17) {
      timeLabel = 'Afternoon';
    } else if (hour >= 17 && hour < 20) {
      timeLabel = 'Evening';
    } else {
      timeLabel = 'Night';
    }
    switch (type) {
      case 'running':
        return '$timeLabel Run';
      case 'weightlifting':
        return '$timeLabel Workout';
      case 'basketball':
        return '$timeLabel Basketball';
      case 'walking':
        return '$timeLabel Walk';
      default:
        return '$timeLabel Activity';
    }
  }

  // ── Gerak kamera Google Maps ──────────────────────────────────────────
  Future<void> _animateCameraToLocation(LatLng loc) async {
    // Skip camera animation saat tab hidden — hemat GPU
    if (!_isMapVisible) return;
    if (_mapController.isCompleted) {
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLng(loc));
    }
  }

  Future<void> _centerOnCurrentLocation() async {
    if (_currentLocation == null) {
      _showSnackBar('Menunggu posisi GPS...');
      return;
    }
    if (_mapController.isCompleted) {
      final controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation!, zoom: 17.0),
        ),
      );
    }
  }

  // ── Init GPS ──────────────────────────────────────────────────────────
  Future<void> _initGps() async {
    LocationService.initialize();
    try {
      await LocationService.requestPermissions();
    } catch (e) {
      debugPrint('⚠️ Permission error: $e');
    }
    await _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Layanan GPS tidak aktif. Aktifkan GPS.');
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Izin lokasi ditolak.');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Izin lokasi diblokir. Buka Settings.');
      return;
    }

    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) {
        final loc = LatLng(lastPos.latitude, lastPos.longitude);
        setState(() => _currentLocation = loc);
        _animateCameraToLocation(loc);
      }
    } catch (_) {}

    _startInitialLocationStream();
  }

  void _startInitialLocationStream() {
    _initialLocationStream?.cancel();
    _initialLocationStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((pos) {
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);

      // Hitung jarak DULU (update _distanceKm + notifier tanpa setState)
      if (_isRunning) {
        _addRoutePointWithDistance(loc, gpsSpeedMs: pos.speed);
        _distanceNotifier.value = _distanceKm;
        _recalcPace();
      }

      // setState HANYA untuk update posisi marker di Google Maps
      _currentLocation = loc;
      setState(() {});

      if (_isRunning || !_hasStarted) {
        _animateCameraToLocation(loc);
      }
    }, cancelOnError: false);
  }

  // ── Tambah titik rute + hitung jarak di UI ────────────────────────────
  // gpsSpeedMs: kecepatan dari GPS sensor (m/s). -1 = tidak diketahui (semua diterima)
  void _addRoutePointWithDistance(LatLng newLoc, {double gpsSpeedMs = -1}) {
    // Filter: skip jika GPS melaporkan kecepatan sangat rendah (<0.5 m/s = diam/drift)
    // 0.5 m/s ≈ 1.8 km/h — ambang batas bahwa orang sedang bergerak
    // Hanya filter jika speed tersedia (>= 0) dari sensor
    if (gpsSpeedMs >= 0 && gpsSpeedMs < 0.5) return;

    if (_routePoints.isEmpty) {
      _routePoints.add(newLoc);
      return;
    }
    final last = _routePoints.last;

    // Filter duplikat koordinat identik
    final degDiff = (last.latitude - newLoc.latitude).abs() +
        (last.longitude - newLoc.longitude).abs();
    if (degDiff < 0.000004) return;

    // Hitung jarak meter pakai Geolocator
    final segmentM = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      newLoc.latitude,
      newLoc.longitude,
    );

    if (segmentM >= 1.0 && segmentM < 200.0) {
      // Gerakan valid: akumulasi jarak
      _distanceKm += segmentM / 1000.0;
      _routePoints.add(newLoc);
    } else if (segmentM >= 200.0) {
      // GPS teleport: update posisi tanpa tambah jarak
      _routePoints.add(newLoc);
    }
    // segmentM < 1.0: terlalu kecil (noise), skip
  }

  // ── Tab Visibility handler (IndexedStack optimization) ──────────────
  // Dipanggil saat user ganti tab di MainNavigation.
  // Tab 2 = Workout tab (induk dari RunningTrackerScreen).
  void _onTabVisibilityChanged() {
    final isVisible = TabVisibility.instance.isTabVisible(2);
    if (isVisible == _isMapVisible) return; // Tidak ada perubahan

    if (!isVisible) {
      // ── Tab disembunyikan → PAUSE map & GPS stream ─────────────────
      _isMapVisible = false;
      _tabHiddenTime = DateTime.now();

      // Stop UI timer — hemat CPU rebuild
      _stopUiTimer();
      _elapsedBeforePause = _elapsedSeconds;

      // Cancel GPS stream — hemat baterai & mencegah setState saat hidden
      _initialLocationStream?.cancel();
      _initialLocationStream = null;

      debugPrint('🗺️ [TabVisibility] Tab hidden — GPS stream & UI timer paused');

    } else {
      // ── Tab ditampilkan kembali → RESUME map & GPS stream ──────────
      _isMapVisible = true;

      if (_isRunning) {
        // Sync elapsed dari service (sumber kebenaran saat tab hidden)
        if (_lastServiceElapsed > _elapsedSeconds) {
          _elapsedSeconds = _lastServiceElapsed;
          debugPrint('✅ [TabVisibility] Sync elapsed dari service: ${_elapsedSeconds}s');
        } else if (_tabHiddenTime != null) {
          // Fallback: hitung dari wall clock
          final hiddenDuration = DateTime.now().difference(_tabHiddenTime!).inSeconds;
          _elapsedSeconds += hiddenDuration;
          debugPrint('✅ [TabVisibility] Elapsed dari wall clock: +${hiddenDuration}s = ${_elapsedSeconds}s');
        }

        // Sync distance dari service jika lebih besar
        if (_lastServiceDistance > _distanceKm) {
          _distanceKm = _lastServiceDistance;
          debugPrint('✅ [TabVisibility] Sync distance dari service: ${_distanceKm.toStringAsFixed(3)} km');
        }

        _elapsedBeforePause = _elapsedSeconds;
        _uiRunStartTime = DateTime.now();
        _startUiTimer();
        _startInitialLocationStream();
        _syncAllNotifiers(); // Sync ValueNotifiers setelah resume

        // Re-center kamera ke posisi terakhir
        if (_currentLocation != null) {
          _animateCameraToLocation(_currentLocation!);
        }
        debugPrint('🗺️ [TabVisibility] Tab visible — GPS stream & UI timer resumed');
      }

      _tabHiddenTime = null;

      // Force refresh UI setelah resume
      if (mounted) setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive) &&
        _isRunning &&
        !_isInBackground) {
      // ── Layar mati / app ke background ──────────────────────────────
      _stopUiTimer();
      _elapsedBeforePause = _elapsedSeconds;
      _isInBackground = true;
      _backgroundStartTime = DateTime.now();

      // Matikan UI GPS stream — hemat baterai, biarkan foreground service
      // yang terus merekam GPS & menghitung jarak di background
      _initialLocationStream?.cancel();
      _initialLocationStream = null;

      debugPrint('📱 [UI] App ke background — foreground service tetap tracking');

    } else if (state == AppLifecycleState.resumed) {
      if (!_isInBackground) return; // Sudah resumed, skip
      _isInBackground = false;

      if (_isRunning) {
        // ── Layar menyala kembali — sync dari service ──────────────────
        // Gunakan elapsed dari service jika tersedia (paling akurat)
        // karena service terus menghitung di background
        if (_lastServiceElapsed > _elapsedSeconds) {
          // Service punya data lebih baru — pakai itu
          _elapsedSeconds = _lastServiceElapsed;
          debugPrint('✅ [UI] Sync elapsed dari service: ${_elapsedSeconds}s');
        } else if (_backgroundStartTime != null) {
          // Fallback: hitung sendiri dari wall clock
          final bgElapsed =
              DateTime.now().difference(_backgroundStartTime!).inSeconds;
          _elapsedSeconds += bgElapsed;
          debugPrint('✅ [UI] Elapsed dari wall clock: +${bgElapsed}s = ${_elapsedSeconds}s');
        }

        // Sync jarak dari service jika lebih besar
        if (_lastServiceDistance > _distanceKm) {
          _distanceKm = _lastServiceDistance;
          debugPrint('✅ [UI] Sync distance dari service: ${_distanceKm.toStringAsFixed(3)} km');
        }

        _backgroundStartTime = null;
        _elapsedBeforePause = _elapsedSeconds;
        _uiRunStartTime = DateTime.now();
        _startUiTimer();
        _startInitialLocationStream();
        _syncAllNotifiers(); // Sync ValueNotifiers setelah resume dari background
        debugPrint('📱 [UI] App kembali foreground — UI timer & GPS stream restart');
      }
    } else if (state == AppLifecycleState.detached) {
      _isInBackground = false;
    }
  }

  // ── Start Run ─────────────────────────────────────────────────────────
  Future<void> _startRun() async {
    if (_currentLocation == null) {
      _showSnackBar('Menunggu sinyal GPS...');
      return;
    }

    setState(() {
      _isRunning = true;
      _hasStarted = true;
      _showPauseStopScreen = false;
      _routePoints.clear();
      _distanceKm = 0.0;
      _elapsedSeconds = 0;
      _movingSeconds = 0;
      _elevationGain = 0.0;
      _maxElevation = 0.0;
      _splits.clear();
      _elapsedBeforePause = 0;
      _lastSplitKm = 0;
      _lastSplitTimeSeconds = 0;
    });
    _syncAllNotifiers(); // Reset metrics di ValueNotifier juga

    _uiRunStartTime = DateTime.now();
    _startUiTimer();
    // JANGAN cancel _initialLocationStream — kita pakai untuk kalkulasi jarak
    // Stream ini tetap jalan dan menggerakkan marker DAN menghitung jarak
    final started = await LocationService.startService();
    if (!started && mounted) {
      _showSnackBar('⚠️ Gagal memulai background tracking. Coba lagi.');
      debugPrint('❌ [UI] Foreground service gagal start!');
    }
  }

  // ── Pause Run ─────────────────────────────────────────────────────────
  Future<void> _pauseRun() async {
    _stopUiTimer();
    _elapsedBeforePause = _elapsedSeconds;
    await LocationService.sendCommand({'command': 'pause'});
    setState(() {
      _isRunning = false;
      _showPauseStopScreen = false;
    });
  }

  // ── Resume Run ────────────────────────────────────────────────────────
  Future<void> _resumeRun() async {
    // Set elapsedBeforePause = elapsed sekarang, timer start = now
    // Formula timer: elapsed = elapsedBeforePause + diff(now, uiRunStartTime)
    // = elapsedSeconds + 0 = elapsedSeconds (benar, tidak loncat)
    _elapsedBeforePause = _elapsedSeconds;
    _uiRunStartTime = DateTime.now();
    _startUiTimer();
    await LocationService.sendCommand({'command': 'resume'});
    setState(() {
      _isRunning = true;
      _showPauseStopScreen = false;
    });
  }

  // ── Stop Run ──────────────────────────────────────────────────────────
  Future<void> _stopRun() async {
    // Guard: jangan stop 2x
    if (_isSaving) return;
    _stopUiTimer();
    setState(() {
      _isRunning = false;
      _isSaving = true;
    });
    await LocationService.sendCommand({'command': 'stop'});
    // Jika service tidak merespons dalam 3 detik (misalnya service mati), simpan langsung
    await Future.delayed(const Duration(seconds: 3));
    if (mounted && _isSaving) {
      _saveRunToDatabase();
    }
  }

  // ── Simpan ke Database ────────────────────────────────────────────────
  Future<void> _saveRunToDatabase() async {
    // Guard double-save
    if (!_isSaving) return;

    await LocationService.stopService();

    if (_distanceKm < 0.01) {
      if (mounted) {
        _showSnackBar('Aktivitas dibatalkan: Tidak ada rekaman jarak (0 km).');
        setState(() {
          _isSaving = false;
        });
        Navigator.pop(context);
      }
      return;
    }

    final durationMinutes = _elapsedSeconds / 60.0;
    final calories = Workout.calculateCalories('running', durationMinutes);
    final protein = Workout.calculateProteinNeeded(
      'running',
      durationMinutes,
      weight: widget.userWeight,
    );

    final now = DateTime.now();
    final workout = Workout(
      type: 'running',
      duration: durationMinutes,
      distance: _distanceKm,
      caloriesBurned: calories,
      proteinNeeded: protein,
      date: now,
      notes: 'Lari GPS Tracker. Jarak: ${_distanceKm.toStringAsFixed(2)} km',
      movingTime: _movingSeconds / 60.0,
      elevationGain: _elevationGain,
      maxElevation: _maxElevation,
      splitsStr: _finalSplitsJson ?? jsonEncode(_splits),
      polyline: _finalRouteJson ??
          jsonEncode(
              _routePoints.map((p) => [p.latitude, p.longitude]).toList()),
      title: _defaultActivityTitle('running', now),
    );

    await DatabaseHelper().insertWorkout(workout);

    // Auto-backup ke Firestore setelah sesi selesai disimpan
    CloudSyncService.backupToCloud().catchError((_) {});

    // Publish ke Social Feed
    SocialService.publishWorkoutToFeed(workout.toMap()).catchError((_) {});

    if (mounted) {
      _showSnackBar('Sesi lari berhasil disimpan! ');
      Navigator.pop(context);
    }
  }

  void _showSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _handleBackPress() {
    if (_isRunning || (_hasStarted && !_isRunning)) {
      setState(() {
        _showPauseStopScreen = true;
        if (_isRunning) _pauseRun();
      });
    } else {
      Navigator.pop(context);
    }
  }

  // ── Getters ───────────────────────────────────────────────────────────
  String get _formattedTime => _formatElapsed(_elapsedSeconds);

  /// Format elapsed seconds → "HH:MM:SS" or "MM:SS".
  /// Pure function — bisa dipakai oleh ValueListenableBuilder tanpa akses state.
  static String _formatElapsed(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  String get _pace {
    // Pace = elapsed time / distance (min/km)
    if (_distanceKm < 0.01) return '--:--';
    if (_elapsedSeconds == 0) return '--:--';
    final paceMins = (_elapsedSeconds / 60.0) / _distanceKm;
    // Sembunyikan hanya jika sangat tidak masuk akal (> 60 min/km = tidak bergerak)
    if (paceMins > 60.0) return '--:--';
    final m = paceMins.truncate();
    final s = ((paceMins - m) * 60).truncate().toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── ValueNotifier sync helpers ─────────────────────────────────────────
  // Setiap kali _elapsedSeconds atau _distanceKm berubah, panggil helper ini
  // agar ValueNotifier ikut ter-update dan widget metrics ter-rebuild granular.
  void _recalcPace() {
    _paceNotifier.value = _pace;
  }

  /// Sync semua ValueNotifier dari variabel state saat ini.
  /// Dipanggil setelah operasi yang mengubah banyak variabel sekaligus.
  void _syncAllNotifiers() {
    _elapsedNotifier.value = _elapsedSeconds;
    _distanceNotifier.value = _distanceKm;
    _recalcPace();
  }

  // ─── BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasStarted && !_isRunning,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body:
            _showPauseStopScreen ? _buildPauseStopScreen() : _buildMainScreen(),
      ),
    );
  }

  // ─── PAUSE/STOP SCREEN ────────────────────────────────────────────────
  Widget _buildPauseStopScreen() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                children: [
                  const Text(
                    'Sesi Lari Dijeda',
                    style: TextStyle(
                      color: Color(0xFF2F2F2F),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _pauseStatItem('Waktu', _formattedTime),
                      _pauseStatItem(
                          'Jarak', '${_distanceKm.toStringAsFixed(2)} km'),
                      _pauseStatItem('Pace', _pace),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _pauseStatItem(
                          'Elevasi', '${_elevationGain.toStringAsFixed(0)} m'),
                      _pauseStatItem(
                          'Max Elev', '${_maxElevation.toStringAsFixed(0)} m'),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: _isSaving ? null : _resumeRun,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: _isSaving ? const Color(0xFFF5F5F5) : const Color(0xFFFF5406),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow, color: _isSaving ? Colors.grey : Colors.white, size: 32),
                      const SizedBox(width: 8),
                      Text('Resume',
                          style: TextStyle(
                              color: _isSaving ? Colors.grey : Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: _isSaving ? null : _stopRun,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: _isSaving ? const Color(0xFFF5F5F5) : const Color(0xFF00A9DD),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _isSaving
                        ? const [
                            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.grey, strokeWidth: 3)),
                            SizedBox(width: 12),
                            Text('Menyimpan...', style: TextStyle(color: Colors.grey, fontSize: 20, fontWeight: FontWeight.w900)),
                          ]
                        : const [
                            Icon(Icons.stop, color: Colors.white, size: 32),
                            SizedBox(width: 8),
                            Text('Finish & Simpan',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900)),
                          ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _pauseStatItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Color(0xFF2F2F2F),
                fontSize: 24,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ─── MAIN RUNNING SCREEN ──────────────────────────────────────────────
  Widget _buildMainScreen() {
    // Susun polyline route
    final Set<Polyline> polylines = {};
    if (_routePoints.length > 1) {
      polylines.add(Polyline(
        polylineId: const PolylineId('run_route'),
        points: _routePoints,
        color: Colors.blueAccent,
        width: 6,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ));
    }

    // Marker posisi saat ini
    final Set<Marker> markers = {};
    if (_currentLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('current_location'),
        position: _currentLocation!,
        icon: _locationMarker ??
            BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
        anchor: const Offset(0.5, 0.5),
        flat: true,
        zIndexInt: 2,
      ));
    }

    return Stack(
      children: [
        // ── Google Map ────────────────────────────────────────────────
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? const LatLng(-6.200000, 106.816666),
              zoom: 17.0,
            ),
            onMapCreated: (controller) async {
              _mapController.complete(controller);
              if (_currentLocation != null) {
                _animateCameraToLocation(_currentLocation!);
              }
            },
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            polylines: polylines,
            markers: markers,
            mapType: MapType.normal,
          ),
        ),

        // ── Back button ───────────────────────────────────────────────
        Positioned(
          top: 50,
          left: 16,
          child: CircleAvatar(
            backgroundColor: Colors.black54,
            child: IconButton(
              icon:
                  const Icon(Icons.expand_more, color: Colors.white, size: 30),
              onPressed: _handleBackPress,
            ),
          ),
        ),

        // ── GPS status badge ──────────────────────────────────────────
        Positioned(
          top: 50,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // GPS badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.gps_fixed,
                      color: _currentLocation != null
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _currentLocation != null ? 'GPS Ready' : 'Mencari GPS...',
                      style: TextStyle(
                        color: _currentLocation != null
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Map tools (zoom to location) ──────────────────────────────
        Positioned(
          right: 16,
          top: 110,
          child: Column(
            children: [
              _mapToolIcon(Icons.add, onTap: () async {
                if (_mapController.isCompleted) {
                  final ctrl = await _mapController.future;
                  ctrl.animateCamera(CameraUpdate.zoomIn());
                }
              }),
              const SizedBox(height: 8),
              _mapToolIcon(Icons.remove, onTap: () async {
                if (_mapController.isCompleted) {
                  final ctrl = await _mapController.future;
                  ctrl.animateCamera(CameraUpdate.zoomOut());
                }
              }),
              const SizedBox(height: 12),
              _mapToolIcon(Icons.my_location, onTap: _centerOnCurrentLocation),
            ],
          ),
        ),

        // ── Bottom panel ──────────────────────────────────────────────
        Align(
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isRunning && _hasStarted)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFF5F5F5),
                  padding: EdgeInsets.symmetric(vertical: context.spaceMD),
                  child: Center(
                    child: Text('Dijeda',
                        style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w900,
                            fontSize: context.fontLG)),
                  ),
                ),
              Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(context.spaceLG, context.space2XL, context.spaceLG, context.spaceLG),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // ── Waktu (elapsed) — rebuild only when seconds change ──
                        ValueListenableBuilder<int>(
                          valueListenable: _elapsedNotifier,
                          builder: (_, elapsed, __) => _statItem(
                            'Waktu',
                            _formatElapsed(elapsed),
                          ),
                        ),
                        // ── Pace — rebuild only when pace recalc triggers ──
                        ValueListenableBuilder<String>(
                          valueListenable: _paceNotifier,
                          builder: (_, pace, __) => _statItemPace(
                            'Avg pace (/km)',
                            pace,
                          ),
                        ),
                        // ── Jarak — rebuild only when distance changes ──
                        ValueListenableBuilder<double>(
                          valueListenable: _distanceNotifier,
                          builder: (_, dist, __) => _statItem(
                            'Jarak (km)',
                            dist.toStringAsFixed(2),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.spaceLG),
                    Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(context.spaceLG, context.spaceMD, context.spaceLG, context.spaceXL),
                child: Row(
                  children: [
                    if (!_isRunning && _hasStarted) ...[
                      Expanded(
                          child: _actionButton(
                        label: 'Resume',
                        color: _isSaving ? const Color(0xFFF5F5F5) : const Color(0xFFFF5406),
                        icon: Icons.play_arrow,
                        textColor: _isSaving ? Colors.grey : Colors.white,
                        onTap: _isSaving ? () {} : _resumeRun,
                      )),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _actionButton(
                        label: _isSaving ? 'Menyimpan...' : 'Finish',
                        color: _isSaving ? const Color(0xFFF5F5F5) : const Color(0xFF00A9DD),
                        icon: _isSaving ? Icons.hourglass_empty : Icons.stop,
                        textColor: _isSaving ? Colors.grey : Colors.white,
                        onTap: _isSaving ? () {} : _stopRun,
                      )),
                    ] else if (_isRunning) ...[
                      Expanded(
                          child: _actionButton(
                        label: 'Pause',
                        color: const Color(0xFFFF5406),
                        icon: Icons.pause,
                        textColor: Colors.white,
                        onTap: _pauseRun,
                      )),
                    ] else ...[
                      Expanded(
                          child: _actionButton(
                        label: _currentLocation == null
                            ? 'Mencari GPS...'
                            : 'Mulai Lari',
                        color: _currentLocation == null
                            ? const Color(0xFFF5F5F5)
                            : const Color(0xFFFF5406),
                        icon: Icons.play_arrow,
                        textColor: _currentLocation == null ? Colors.grey : Colors.white,
                        onTap: _currentLocation == null ? () {} : _startRun,
                      )),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────
  Widget _mapToolIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration:
            const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: const Color(0xFF2F2F2F),
                fontSize: context.fontXL,
                fontWeight: FontWeight.w900)),
        Text(label,
            style: TextStyle(
                color: Colors.grey,
                fontSize: context.fontXS,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _statItemPace(String label, String value) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed, color: Colors.grey, size: context.iconSM),
            const SizedBox(width: 4),
            Text(value,
                style: TextStyle(
                    color: const Color(0xFF2F2F2F),
                    fontSize: context.fontXL,
                    fontWeight: FontWeight.w900)),
          ],
        ),
        Text(label,
            style: TextStyle(
                color: Colors.grey,
                fontSize: context.fontXS,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required IconData icon,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: context.iconMD),
            SizedBox(width: context.spaceSM),
            Text(label,
                style: TextStyle(
                    color: textColor,
                    fontSize: context.fontLG,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
