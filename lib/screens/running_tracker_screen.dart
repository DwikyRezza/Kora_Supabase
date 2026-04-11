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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    _createLocationMarker();
    _initGps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _uiTimer?.cancel();
    _initialLocationStream?.cancel();
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
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 2, borderPaint);

    // Titik biru solid di tengah
    final Paint innerPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), 14, innerPaint);

    final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
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
      if (!mounted) return;
      setState(() {
        if (_uiRunStartTime != null) {
          _elapsedSeconds =
              _elapsedBeforePause +
              DateTime.now().difference(_uiRunStartTime!).inSeconds;
        }
      });
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

      setState(() {
        _currentLocation = newLoc;

        // Kalkulasi jarak LANGSUNG di screen dari event lokasi yang sudah terbukti bekerja
        if (_isRunning && accuracy <= 60.0) {
          if (_routePoints.isEmpty) {
            _routePoints.add(newLoc);
          } else {
            final lastPt = _routePoints.last;
            final segmentM = Geolocator.distanceBetween(
              lastPt.latitude, lastPt.longitude,
              newLoc.latitude, newLoc.longitude,
            );
            // Filter noise GPS (<1m) & GPS teleport (>200m)
            if (segmentM >= 1.0 && segmentM < 200.0) {
              _distanceKm += segmentM / 1000.0;
              _movingSeconds++;
              _routePoints.add(newLoc);

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
            }
          }
        }
      });

      if (_isRunning) {
        _animateCameraToLocation(newLoc);
      }

    } else if (type == 'update') {
      // Hanya ambil data elevasi dari service
      if (!mounted) return;
      setState(() {
        _elevationGain = (map['elevationGain'] as num?)?.toDouble() ?? _elevationGain;
        _maxElevation  = (map['maxElevation']  as num?)?.toDouble() ?? _maxElevation;
      });

    } else if (type == 'final') {
      // Simpan elevasi dari service, jarak & rute dari perhitungan lokal
      _elevationGain = (map['elevationGain'] as num?)?.toDouble() ?? _elevationGain;
      _maxElevation  = (map['maxElevation']  as num?)?.toDouble() ?? _maxElevation;
      _finalSplitsJson = null; // pakai _splits lokal
      _finalRouteJson  = null; // pakai _routePoints lokal
      _saveRunToDatabase();

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
      _stopRun();
    }
  }

  // ── Gerak kamera Google Maps ──────────────────────────────────────────
  Future<void> _animateCameraToLocation(LatLng loc) async {
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
        distanceFilter: 1, // update setiap 1m bergerak
      ),
    ).listen((pos) {
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);

      if (_isRunning) {
        // ── Saat lari: hitung jarak, rute, splits di sini ──────────────
        setState(() {
          _currentLocation = loc;
          // Filter akurasi buruk (longgar 65m untuk HP biasa)
          if (pos.accuracy <= 65.0) {
            if (_routePoints.isEmpty) {
              _routePoints.add(loc);
            } else {
              final lastPt = _routePoints.last;
              final segmentM = Geolocator.distanceBetween(
                lastPt.latitude, lastPt.longitude,
                loc.latitude, loc.longitude,
              );
              // Tambah jika >= 1m dan < 200m (filter GPS teleport)
              if (segmentM >= 1.0 && segmentM < 200.0) {
                _distanceKm += segmentM / 1000.0;
                _movingSeconds++;
                _routePoints.add(loc);
                // Splits per km
                final currentKm = _distanceKm.floor();
                if (currentKm > _lastSplitKm) {
                  final splitTime = _elapsedSeconds - _lastSplitTimeSeconds;
                  final mStr = (splitTime ~/ 60).toString().padLeft(2, '0');
                  final sStr = (splitTime % 60).toString().padLeft(2, '0');
                  _splits.add('$mStr:$sStr');
                  _lastSplitKm = currentKm;
                  _lastSplitTimeSeconds = _elapsedSeconds;
                }
              }
            }
          }
        });
        _animateCameraToLocation(loc);
      } else {
        // ── Sebelum lari: hanya update marker
        setState(() => _currentLocation = loc);
        _animateCameraToLocation(loc);
      }
    }, cancelOnError: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused && _isRunning) {
      _stopUiTimer();
    } else if (state == AppLifecycleState.resumed && _isRunning) {
      _startUiTimer();
      _startInitialLocationStream();
    }
  }

  // ── Start Run ─────────────────────────────────────────────────────────
  Future<void> _startRun() async {
    if (_currentLocation == null) {
      _showSnackBar('Menunggu sinyal GPS...');
      return;
    }

    setState(() {
      _isRunning     = true;
      _hasStarted    = true;
      _showPauseStopScreen = false;
      _routePoints.clear();
      _distanceKm    = 0.0;
      _elapsedSeconds      = 0;
      _movingSeconds  = 0;
      _elevationGain  = 0.0;
      _maxElevation   = 0.0;
      _splits.clear();
      _elapsedBeforePause = 0;
      _lastSplitKm = 0;
      _lastSplitTimeSeconds = 0;
    });

    _uiRunStartTime = DateTime.now();
    _startUiTimer();
    // JANGAN cancel _initialLocationStream — kita pakai untuk kalkulasi jarak
    // Stream ini tetap jalan dan menggerakkan marker DAN menghitung jarak
    await LocationService.startService();

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
    _stopUiTimer();
    setState(() {
      _isRunning = false;
      _showPauseStopScreen = false;
    });
    await LocationService.sendCommand({'command': 'stop'});
    await _saveRunToDatabase();
  }

  // ── Simpan ke Database ────────────────────────────────────────────────
  Future<void> _saveRunToDatabase() async {
    await LocationService.stopService();

    if (_distanceKm < 0.01) {
      if (mounted) {
        _showSnackBar('Aktivitas dibatalkan: Tidak ada rekaman jarak (0 km).');
        Navigator.pop(context);
      }
      return;
    }

    final durationMinutes = _elapsedSeconds / 60.0;
    final calories = Workout.calculateCalories('running', durationMinutes);
    final protein = Workout.calculateProteinNeeded(
      'running', durationMinutes,
      weight: widget.userWeight,
    );

    final workout = Workout(
      type: 'running',
      duration: durationMinutes,
      distance: _distanceKm,
      caloriesBurned: calories,
      proteinNeeded: protein,
      date: DateTime.now(),
      notes: 'Lari GPS Tracker. Jarak: ${_distanceKm.toStringAsFixed(2)} km',
      movingTime: _movingSeconds / 60.0,
      elevationGain: _elevationGain,
      maxElevation: _maxElevation,
      splitsStr: _finalSplitsJson ?? jsonEncode(_splits),
      polyline: _finalRouteJson ??
          jsonEncode(_routePoints.map((p) => [p.latitude, p.longitude]).toList()),
    );

    await DatabaseHelper().insertWorkout(workout);

    if (mounted) {
      _showSnackBar('Sesi lari berhasil disimpan! 🎉');
      Navigator.pop(context);
    }
  }

  void _showSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
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
  String get _formattedTime {
    final h = (_elapsedSeconds ~/ 3600);
    final m = ((_elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  String get _pace {
    if (_distanceKm < 0.01) return '--:--';
    final secs = _movingSeconds > 0 ? _movingSeconds : _elapsedSeconds;
    if (secs == 0) return '--:--';
    final paceMins = (secs / 60.0) / _distanceKm;
    if (paceMins > 99) return '--:--';
    final m = paceMins.truncate();
    final s = ((paceMins - m) * 60).truncate().toString().padLeft(2, '0');
    return '$m:$s';
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
        backgroundColor: Colors.black,
        body: _showPauseStopScreen
            ? _buildPauseStopScreen()
            : _buildMainScreen(),
      ),
    );
  }

  // ─── PAUSE/STOP SCREEN ────────────────────────────────────────────────
  Widget _buildPauseStopScreen() {
    return Container(
      color: const Color(0xFF111111),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text(
                    'Sesi Lari Dijeda',
                    style: TextStyle(
                      color: Color(0xFFFFD12B),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _pauseStatItem('Waktu', _formattedTime),
                      _pauseStatItem('Jarak', '${_distanceKm.toStringAsFixed(2)} km'),
                      _pauseStatItem('Pace', _pace),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _pauseStatItem('Elevasi', '${_elevationGain.toStringAsFixed(0)} m'),
                      _pauseStatItem('Max Elev', '${_maxElevation.toStringAsFixed(0)} m'),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: GestureDetector(
                onTap: _resumeRun,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFC5200),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow, color: Colors.white, size: 32),
                      SizedBox(width: 8),
                      Text('Resume',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: GestureDetector(
                onTap: _stopRun,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stop, color: Colors.black, size: 32),
                      SizedBox(width: 8),
                      Text('Finish & Simpan',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 22,
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
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
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
        icon: _locationMarker ?? BitmapDescriptor.defaultMarkerWithHue(
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
            style: _mapStyleDark,
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
              icon: const Icon(Icons.expand_more, color: Colors.white, size: 30),
              onPressed: _handleBackPress,
            ),
          ),
        ),

        // ── GPS status badge ──────────────────────────────────────────
        Positioned(
          top: 50,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.gps_fixed,
                  color: _currentLocation != null ? Colors.greenAccent : Colors.redAccent,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  _currentLocation != null ? 'GPS Ready' : 'Mencari GPS...',
                  style: TextStyle(
                    color: _currentLocation != null ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
                  color: const Color(0xFFFFD12B),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: const Center(
                    child: Text('Dijeda',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 18)),
                  ),
                ),
              Container(
                color: const Color(0xFF191919),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _statItem('Time', _formattedTime),
                        _statItemPace('Avg pace (/km)', _pace),
                        _statItem('Distance (km)', _distanceKm.toStringAsFixed(2)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: Colors.black,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Row(
                  children: [
                    if (!_isRunning && _hasStarted) ...[
                      Expanded(child: _actionButton(
                        label: 'Resume',
                        color: const Color(0xFFFC5200),
                        icon: Icons.play_arrow,
                        textColor: Colors.white,
                        onTap: _resumeRun,
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: _actionButton(
                        label: 'Finish',
                        color: Colors.white,
                        icon: Icons.stop,
                        textColor: Colors.black,
                        onTap: _stopRun,
                      )),
                    ] else if (_isRunning) ...[
                      Expanded(child: _actionButton(
                        label: 'Pause',
                        color: const Color(0xFFFC5200),
                        icon: Icons.pause,
                        textColor: Colors.white,
                        onTap: _pauseRun,
                      )),
                    ] else ...[
                      Expanded(child: _actionButton(
                        label: _currentLocation == null ? 'Mencari GPS...' : 'Start',
                        color: _currentLocation == null ? Colors.grey : const Color(0xFFFC5200),
                        icon: Icons.play_arrow,
                        textColor: Colors.white,
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
        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        Text(label,
            style: TextStyle(
                color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _statItemPace(String label, String value) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.more_horiz, color: Colors.white, size: 20),
            const SizedBox(width: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          ],
        ),
        Text(label,
            style: TextStyle(
                color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
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
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 28),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
