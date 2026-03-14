import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/workout.dart';
import '../services/database_helper.dart';

class RunningTrackerScreen extends StatefulWidget {
  final double userWeight;
  RunningTrackerScreen({super.key, required this.userWeight});

  @override
  State<RunningTrackerScreen> createState() => _RunningTrackerScreenState();
}

class _RunningTrackerScreenState extends State<RunningTrackerScreen> {
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  LatLng? _currentLocation;
  bool _isRunning = false;
  double _distanceKm = 0.0;
  int _elapsedSeconds = 0;
  int _movingSeconds = 0;
  double _currentSpeed = 0.0;
  double _elevationGain = 0.0;
  double _maxElevation = 0.0;
  double _lastAltitude = 0.0;
  int _lastSplitKm = 0;
  int _lastSplitTimeSeconds = 0;
  List<String> _splits = [];

  Timer? _timer;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation);
    
    if (mounted) {
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
      });
      _mapController.move(_currentLocation!, 17.0);
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 1),
    ).listen((Position position) {
      final latLng = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _currentSpeed = position.speed;
          _currentLocation = latLng;
          if (_isRunning) {
            if (_routePoints.isNotEmpty) {
              final lastPos = _routePoints.last;
              _distanceKm += Distance().as(LengthUnit.Kilometer, lastPos, latLng);
              
              double altDiff = position.altitude - _lastAltitude;
              if (altDiff > 0) {
                _elevationGain += altDiff;
              }
              if (position.altitude > _maxElevation) {
                _maxElevation = position.altitude;
              }
              
              int currentKm = _distanceKm.floor();
              if (currentKm > _lastSplitKm) {
                int splitTime = _elapsedSeconds - _lastSplitTimeSeconds;
                final m = (splitTime ~/ 60).toString().padLeft(2, '0');
                final s = (splitTime % 60).toString().padLeft(2, '0');
                _splits.add('$m:$s');
                _lastSplitKm = currentKm;
                _lastSplitTimeSeconds = _elapsedSeconds;
              }

            } else {
              _maxElevation = position.altitude;
            }
            _lastAltitude = position.altitude;
            _routePoints.add(latLng);
            _mapController.move(latLng, 17.0);
          }
        });
      }
    });
  }

  Future<void> _centerOnCurrentLocation() async {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 17.0);
    } else {
      try {
        Position pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.bestForNavigation);
        _mapController.move(LatLng(pos.latitude, pos.longitude), 17.0);
      } catch (e) {
        // Ignore if location is unavailable
      }
    }
  }

  void _startRun() {
    setState(() {
      _isRunning = true;
      _routePoints.clear();
      if (_currentLocation != null) {
        _routePoints.add(_currentLocation!);
      }
      _distanceKm = 0.0;
      _elapsedSeconds = 0;
      _movingSeconds = 0;
      _elevationGain = 0.0;
      _maxElevation = 0.0;
      _lastSplitKm = 0;
      _lastSplitTimeSeconds = 0;
      _splits.clear();
    });

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
        if (_currentSpeed > 0.5) {
          _movingSeconds++;
        }
      });
    });
  }


  Future<void> _saveRun() async {
    final durationMinutes = _elapsedSeconds / 60.0;
    final calories = Workout.calculateCalories('running', durationMinutes);
    final protein = Workout.calculateProteinNeeded('running', durationMinutes, weight: widget.userWeight);

    // Save route as JSON
    final polylineData = jsonEncode(_routePoints.map((p) => [p.latitude, p.longitude]).toList());

    final workout = Workout(
      type: 'running',
      duration: durationMinutes,
      distance: _distanceKm,
      caloriesBurned: calories,
      proteinNeeded: protein,
      date: DateTime.now(),
      notes: 'Lari dari GPS Tracker. Jarak: ${_distanceKm.toStringAsFixed(2)} km',
      movingTime: _movingSeconds / 60.0,
      elevationGain: _elevationGain,
      maxElevation: _maxElevation,
      splitsStr: jsonEncode(_splits),
      polyline: polylineData,
    );

    await DatabaseHelper().insertWorkout(workout);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sesi lari berhasil disimpan!')));
      Navigator.pop(context);
    }
  }

  String get _formattedTime {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _pace {
    if (_distanceKm == 0) return '0:00';
    final paceMins = (_elapsedSeconds / 60) / _distanceKm;
    final m = paceMins.truncate();
    final s = ((paceMins - m) * 60).truncate().toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  void _pauseRun() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resumeRun() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
          if (_currentSpeed > 0.5) {
            _movingSeconds++;
          }
        });
      }
    });
    setState(() => _isRunning = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Map Background
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation ?? LatLng(-6.200000, 106.816666),
                initialZoom: 17.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.athletesync',
                ),
                PolylineLayer(
                  polylines: [
                    if (_routePoints.length > 1)
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 6.0,
                        color: Color(0xFFFC5200), // Strava Orange
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    if (_currentLocation != null)
                      Marker(
                        point: _currentLocation!,
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blueAccent.withOpacity(0.3),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Top Back Button
          Positioned(
            top: 50,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black38,
              child: IconButton(
                icon: Icon(Icons.expand_more, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Right Map Tools
          Positioned(
            right: 16,
            top: 100,
            child: Column(
              children: [
                _mapToolIcon(Icons.near_me_outlined),
                SizedBox(height: 12),
                _mapToolIcon(Icons.my_location, onTap: _centerOnCurrentLocation),
              ],
            ),
          ),

          // Bottom Stats & Controls
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Stopped Banner
                if (!_isRunning && _routePoints.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: Color(0xFFFFD12B), // Strava Yellow
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'Stopped',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),

                // Stats Panel
                Container(
                  color: Color(0xFF191919),
                  padding: EdgeInsets.fromLTRB(24, 32, 24, 48),
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
                      SizedBox(height: 16),
                      // Drag handle placeholder
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

                // Control Panel
                Container(
                  color: Colors.black,
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Row(
                    children: [
                      if (!_isRunning && _routePoints.isNotEmpty) ...[
                        Expanded(
                          child: _actionButton(
                            label: 'Resume',
                            color: Color(0xFFFC5200),
                            icon: Icons.play_arrow,
                            textColor: Colors.white,
                            onTap: _resumeRun,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _actionButton(
                            label: 'Finish',
                            color: Colors.white,
                            icon: Icons.stop,
                            textColor: Colors.black,
                            onTap: _saveRun,
                          ),
                        ),
                      ] else if (_isRunning) ...[
                        Expanded(
                          child: _actionButton(
                            label: 'Pause',
                            color: Color(0xFFFC5200),
                            icon: Icons.pause,
                            textColor: Colors.white,
                            onTap: _pauseRun,
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: _actionButton(
                            label: 'Start',
                            color: Color(0xFFFC5200),
                            icon: Icons.play_arrow,
                            textColor: Colors.white,
                            onTap: _startRun,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapToolIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }


  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _statItemPace(String label, String value) {
    return Column(
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.more_horiz, color: Colors.white, size: 20),
              SizedBox(width: 4),
              Text(value, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
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
        height: 64,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 28),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

