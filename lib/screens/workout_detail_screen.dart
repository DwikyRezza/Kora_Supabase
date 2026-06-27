import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../models/workout.dart';
import '../models/exercise_definition.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final Workout workout;

  WorkoutDetailScreen({super.key, required this.workout});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late Workout _workout;
  bool _isLoading = false;
  final ScreenshotController _screenshotController = ScreenshotController();

  String _userName = 'Atlet';
  String? _userPhotoUrl;

  /// Incremented to force FutureBuilder to re-fetch photos from DB
  int _photoRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _workout = widget.workout;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await ProfileService.getProfile();
      if (mounted) {
        setState(() {
          String name = profile[ProfileService.keyName] ?? '';
          if (name.isEmpty) name = AuthService.displayName;
          if (name.isEmpty) name = 'Atlet';
          _userName = name;
          _userPhotoUrl = profile['photoUrl'] ?? AuthService.photoUrl;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 75,
    );

    if (pickedFile != null) {
      setState(() => _isLoading = true);
      
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(pickedFile.path)}';
      final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');

      // Simpan ke tabel terpisah workout_photos (lazy loading)
      if (_workout.id != null) {
        await DatabaseHelper().addWorkoutPhoto(_workout.id!, savedImage.path);
      }

      setState(() {
        _isLoading = false;
        // Trigger rebuild — FutureBuilder akan re-fetch foto dari DB
        _photoRefreshKey++;
      });
    }
  }

  static String _defaultTitle(Workout w) {
    final hour = w.date.hour;
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
    switch (w.type) {
      case 'running':       return '$timeLabel Run';
      case 'weightlifting': return '$timeLabel Workout';
      case 'basketball':    return '$timeLabel Basketball';
      case 'walking':       return '$timeLabel Walk';
      default:              return '$timeLabel Activity';
    }
  }

  Future<void> _editTitle() async {
    final controller = TextEditingController(text: _workout.title ?? _defaultTitle(_workout));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Edit Title', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Activity Name',
            hintStyle: TextStyle(color: AppTheme.textMuted),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Batal')),
          TextButton(
            onPressed: () async {
              final newTitle = controller.text;
              final updated = Workout(
                id: _workout.id, type: _workout.type, duration: _workout.duration,
                distance: _workout.distance, sets: _workout.sets, reps: _workout.reps,
                weight: _workout.weight, caloriesBurned: _workout.caloriesBurned,
                proteinNeeded: _workout.proteinNeeded, notes: _workout.notes,
                date: _workout.date, movingTime: _workout.movingTime,
                elevationGain: _workout.elevationGain, maxElevation: _workout.maxElevation,
                splitsStr: _workout.splitsStr,
                polyline: _workout.polyline, title: newTitle,
              );
              await DatabaseHelper().updateWorkout(updated);
              setState(() => _workout = updated);
              Navigator.pop(context);
            },
            child: Text('Simpan', style: TextStyle(color: AppTheme.electricBlue)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareActivity() async {
    final image = await _screenshotController.capture();
    if (image != null) {
      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/workout_share.png').create();
      await imagePath.writeAsBytes(image);
      
      await Share.shareXFiles([XFile(imagePath.path)], text: 'Latihan saya hari ini: ${_workout.title ?? _workout.typeLabel}!  #Kora');
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> splits = [];
    if (_workout.splitsStr != null && _workout.splitsStr!.isNotEmpty) {
      try {
        splits = List<String>.from(jsonDecode(_workout.splitsStr!));
      } catch (e) {
        // ignore
      }
    }

    List<LatLng> routePoints = [];
    if (_workout.polyline != null && _workout.polyline!.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(_workout.polyline!);
        routePoints = decoded.map((p) => LatLng(
          (p[0] as num).toDouble(),
          (p[1] as num).toDouble(),
        )).toList();
      } catch (e) {
        // ignore
      }
    }

    final double workoutDistance = _workout.distance ?? 0.0;
    final double avgPaceMins = workoutDistance > 0 ? (_workout.duration / workoutDistance) : 0.0;

    // Generate sports science mock data based on actual run data
    final series = _generateSeriesData(workoutDistance, avgPaceMins);
    final efforts = _generateBestEfforts(avgPaceMins);
    final zones = _generatePaceZones(avgPaceMins);

    return Scaffold(
      appBar: AppBar(
        title: Text(_workout.typeLabel),
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined),
            onPressed: _shareActivity,
          ),
        ],
      ),
      backgroundColor: AppTheme.background,
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: AppTheme.themeNotifier,
        builder: (context, _, __) {
          return Screenshot(
            controller: _screenshotController,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. HEADER (Profil Atlet & Info Lari)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.surfaceVariant,
                          backgroundImage: _userPhotoUrl != null 
                              ? (_userPhotoUrl!.startsWith('http') 
                                  ? NetworkImage(_userPhotoUrl!) 
                                  : (_userPhotoUrl!.startsWith('data:image')
                                      ? MemoryImage(base64Decode(_userPhotoUrl!.split(',').last.replaceAll(RegExp(r'\s+'), '')))
                                      : FileImage(File(_userPhotoUrl!)))) as ImageProvider
                              : null,
                          child: _userPhotoUrl == null 
                              ? Text(_userName.isNotEmpty ? _userName[0].toUpperCase() : '', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_userName, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              DateFormat('MMMM d, yyyy • HH:mm', 'id').format(_workout.date),
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _workout.title ?? _defaultTitle(_workout),
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 20),
                          onPressed: _editTitle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. GRID METRIK UTAMA (Sports Science Style)
                  _buildMainMetricsGrid(avgPaceMins),
                  const SizedBox(height: 20),

                  // 3. MAPS INTERAKTIF
                  if (routePoints.isNotEmpty)
                    Container(
                      height: 280,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppTheme.border, width: 1),
                          bottom: BorderSide(color: AppTheme.border, width: 1),
                        ),
                      ),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: routePoints[routePoints.length ~/ 2],
                          zoom: 14.0,
                        ),
                        style: AppTheme.isDarkMode ? '''[
                          {"elementType":"geometry","stylers":[{"color":"#212121"}]},
                          {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
                          {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
                          {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
                          {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
                          {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},
                          {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
                          {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},
                          {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#181818"}]}
                        ]''' : null,
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        scrollGesturesEnabled: true,
                        zoomGesturesEnabled: true,
                        rotateGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                        mapToolbarEnabled: false,
                        polylines: {
                          Polyline(
                            polylineId: const PolylineId('route'),
                            points: routePoints,
                            color: const Color(0xFFFF5406),
                            width: 5,
                            startCap: Cap.roundCap,
                            endCap: Cap.roundCap,
                            jointType: JointType.round,
                          ),
                        },
                        markers: {
                          Marker(
                            markerId: const MarkerId('start'),
                            position: routePoints.first,
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                          ),
                          if (routePoints.length > 1)
                            Marker(
                              markerId: const MarkerId('end'),
                              position: routePoints.last,
                              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                            ),
                        },
                        onMapCreated: (controller) {
                          Future.delayed(const Duration(milliseconds: 150), () {
                            double minLat = routePoints.first.latitude;
                            double maxLat = routePoints.first.latitude;
                            double minLng = routePoints.first.longitude;
                            double maxLng = routePoints.first.longitude;
                            for (final p in routePoints) {
                              if (p.latitude < minLat) minLat = p.latitude;
                              if (p.latitude > maxLat) maxLat = p.latitude;
                              if (p.longitude < minLng) minLng = p.longitude;
                              if (p.longitude > maxLng) maxLng = p.longitude;
                            }
                            controller.animateCamera(
                              CameraUpdate.newLatLngBounds(
                                LatLngBounds(
                                  southwest: LatLng(minLat, minLng),
                                  northeast: LatLng(maxLat, maxLng),
                                ),
                                40.0,
                              ),
                            );
                          });
                        },
                      ),
                    ),
                  const SizedBox(height: 28),

                  // 4. SECTION RESULTS & WORKOUT ANALYSIS
                  if (workoutDistance > 0 && efforts.isNotEmpty) ...[
                    _buildSectionHeader('Results'),
                    _buildBestEffortsList(efforts),
                    const SizedBox(height: 28),
                  ],

                  if (workoutDistance > 0) ...[
                    _buildSectionHeader('Workout Analysis'),
                    _buildWorkoutAnalysisChart(series),
                    const SizedBox(height: 28),
                  ],

                  // 5. SECTION SPLITS
                  if (workoutDistance > 0) ...[
                    _buildSectionHeader('Splits'),
                    _buildSplitsList(splits),
                    const SizedBox(height: 28),
                  ],

                  // 6. METRIK GRAFIK (PACE, GAP, ZONES, CADENCE)
                  if (workoutDistance > 0) ...[
                    _buildSectionHeader('Pace'),
                    _buildPaceChart(series, avgPaceMins, splits),
                    const SizedBox(height: 28),

                    _buildSectionHeader('Grade Adjusted Pace (GAP)'),
                    _buildGapChart(series, avgPaceMins),
                    const SizedBox(height: 28),

                    _buildSectionHeader('Pace Zones'),
                    _buildPaceZones(zones),
                    const SizedBox(height: 28),

                    _buildSectionHeader('Cadence'),
                    _buildCadenceChart(series),
                    const SizedBox(height: 28),
                  ],

                  // 7. SECTION ELEVATION (PENTING)
                  if (workoutDistance > 0) ...[
                    _buildSectionHeader('Elevation'),
                    _buildElevationChart(series),
                    _buildElevationSummary(),
                    const SizedBox(height: 28),
                  ],

                  // MUSCLE DISTRIBUTION (jika weightlifting)
                  if (_workout.type == 'weightlifting') ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildMuscleSectionFromNotes(),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // DETAIL PER GERAKAN
                  if (_workout.notes.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSectionTitle('Detail Per Gerakan'),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildDetailLogsFromNotes(),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // FOTO LATIHAN
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Foto Latihan'),
                        IconButton(
                          icon: Icon(Icons.add_a_photo, color: AppTheme.electricBlue),
                          onPressed: _isLoading ? null : _pickImage,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_workout.id != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FutureBuilder<List<String>>(
                        key: ValueKey('photos_$_photoRefreshKey'),
                        future: DatabaseHelper().getWorkoutPhotos(_workout.id!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              height: 80,
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          }
                          final photos = snapshot.data ?? [];
                          if (photos.isEmpty) return const SizedBox.shrink();
                          return SizedBox(
                            height: 160,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: photos.length,
                              itemBuilder: (context, i) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(
                                      File(photos[i]),
                                      width: 240,
                                      height: 160,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── UTILITIES & WIDGET GENERATOR ──────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        title,
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.3),
      ),
    );
  }

  Widget _buildMainMetricsGrid(double avgPaceMins) {
    final speedLabel = _workout.type == 'running' ? 'Avg Pace' : 'Total Reps';
    final speedVal = _workout.type == 'running' ? '${_calculatePace()} /km' : '${_workout.reps ?? 0}';

    final elevGainVal = '${(_workout.elevationGain ?? 0).round()} m';
    final heartRateVal = _workout.type == 'running' ? '146 bpm' : '${_workout.sets ?? 0} sets';
    final hrLabel = _workout.type == 'running' ? 'Avg Heart Rate' : 'Total Set';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _metricCell('Distance', '${(_workout.distance ?? 0.0).toStringAsFixed(2)} km')),
                Expanded(child: _metricCell(speedLabel, speedVal)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _metricCell('Moving Time', _formatDuration(_workout.duration))),
                Expanded(child: _metricCell('Elevation Gain', elevGainVal)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _metricCell('Calories', '${_workout.caloriesBurned} Cal')),
                Expanded(child: _metricCell(hrLabel, heartRateVal)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
      ],
    );
  }

  Widget _buildBestEffortsList(Map<String, String> efforts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: efforts.entries.map((e) {
            return ListTile(
              leading: const Icon(Icons.flash_on_rounded, color: Color(0xFFFF5406), size: 20),
              title: Text(e.key, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              trailing: Text(e.value, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildWorkoutAnalysisChart(List<_SeriesPoint> series) {
    // Workout Analysis Bar Chart: visualisasi fluktuasi intensitas lari per segmen
    final barGroups = List.generate(series.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: 15.0 - series[i].pace, // Invert
            color: const Color(0xFFFF5406).withOpacity(0.85),
            width: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 12,
            barGroups: barGroups,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(
              show: false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSplitsList(List<String> splits) {
    // Generate splits if empty
    final finalSplits = splits.isNotEmpty ? splits : _generateSplitsList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: List.generate(finalSplits.length, (i) {
            final paceVal = finalSplits[i];
            // Hitung persentase untuk progress bar (misal 5:00 /km adalah 100%, 10:00 /km adalah 10%)
            double pct = 0.5;
            try {
              final parts = paceVal.split(':');
              final mins = double.parse(parts[0]) + (double.parse(parts[1]) / 60);
              pct = (12.0 - mins) / (12 - 4); // Rentang 4 - 12 menit
              pct = pct.clamp(0.1, 1.0);
            } catch (_) {}

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 48, child: Text('Km ${i + 1}', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13))),
                  const SizedBox(width: 10),
                  Text(paceVal, style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 12,
                        backgroundColor: AppTheme.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF5406)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('HR: ${140 + (i % 3) * 5}', style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  List<String> _generateSplitsList() {
    final double dist = _workout.distance ?? 3.0;
    final int count = dist.ceil();
    final double avgP = _workout.duration / (dist > 0 ? dist : 1.0);
    return List.generate(count, (i) {
      final p = avgP + (i % 3 - 1) * 0.2;
      final m = p.truncate();
      final s = ((p - m) * 60).round().toString().padLeft(2, '0');
      return '$m:$s';
    });
  }

  Widget _buildPaceChart(List<_SeriesPoint> series, double avgPaceMins, List<String> splits) {
    final spots = series.map((s) => FlSpot(s.distance, 15.0 - s.pace)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Expanded(
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: _workout.distance ?? 5.0,
                  minY: 5.0,
                  maxY: 12.0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 2.0,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppTheme.textPrimary.withOpacity(0.06),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    show: false,
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 15.0 - avgPaceMins,
                        color: Colors.grey.withOpacity(0.5),
                        strokeWidth: 1.5,
                        dashArray: [5, 5],
                      ),
                    ],
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: const Color(0xFF00A9DD), // Biru cerah
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF00A9DD).withOpacity(0.25),
                            const Color(0xFF00A9DD).withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniSubStat('Avg Elapsed Pace', '${_calculatePace()} /km'),
                _miniSubStat('Fastest Split', '${splits.isNotEmpty ? splits.first : "5:32"} /km'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGapChart(List<_SeriesPoint> series, double avgPaceMins) {
    final spots = series.map((s) => FlSpot(s.distance, 15.0 - s.gap)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(24),
        ),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: _workout.distance ?? 5.0,
            minY: 5.0,
            maxY: 12.0,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppTheme.textPrimary.withOpacity(0.06),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(
              show: false,
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: const Color(0xFFE28900),
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE28900).withOpacity(0.2),
                      const Color(0xFFE28900).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaceZones(Map<String, double> zones) {
    final zLabels = ['Z6', 'Z5', 'Z4', 'Z3', 'Z2', 'Z1'];
    final zColors = [
      Colors.red[700]!,
      Colors.red[400]!,
      Colors.orange[400]!,
      Colors.yellow[600]!,
      Colors.green[400]!,
      Colors.blue[400]!,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: List.generate(6, (i) {
            final key = zLabels[i];
            final val = zones[key] ?? 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 28, child: Text(key, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: val / 100,
                        minHeight: 12,
                        backgroundColor: AppTheme.border,
                        valueColor: AlwaysStoppedAnimation<Color>(zColors[i]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 36, child: Text('${val.round()}%', textAlign: TextAlign.right, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13))),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCadenceChart(List<_SeriesPoint> series) {
    final spots = series.map((s) => FlSpot(s.distance, s.cadence)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Expanded(
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: _workout.distance ?? 5.0,
                  minY: 130.0,
                  maxY: 195.0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppTheme.textPrimary.withOpacity(0.06),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    show: false,
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: const Color(0xFFBD4BE5), // Ungu/pink
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFFBD4BE5).withOpacity(0.25),
                            const Color(0xFFBD4BE5).withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniSubStat('Avg Cadence', '174 spm'),
                _miniSubStat('Max Cadence', '182 spm'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElevationChart(List<_SeriesPoint> series) {
    final spots = series.map((s) => FlSpot(s.distance, s.elevation)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(24),
        ),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: _workout.distance ?? 5.0,
            minY: 0.0,
            maxY: 100.0,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppTheme.textPrimary.withOpacity(0.06),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(
              show: false,
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: const Color(0xFF6B7280), // Abu-abu gelap
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF6B7280).withOpacity(0.25),
                      const Color(0xFF6B7280).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildElevationSummary() {
    final elevGain = '${(_workout.elevationGain ?? 0.0).round()} m';
    final maxElev = '${(_workout.maxElevation ?? (_workout.elevationGain != null ? _workout.elevationGain! * 1.5 : 55.0)).round()} m';
    final minElev = '${_workout.elevationGain != null ? (_workout.maxElevation != null ? (_workout.maxElevation! - _workout.elevationGain!).clamp(0.0, 999.0).round() : 12) : 12} m';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _miniSubStat('Elevation Gain', elevGain),
            _miniSubStat('Max Elevation', maxElev),
            _miniSubStat('Min Elevation', minElev),
          ],
        ),
      ),
    );
  }

  Widget _miniSubStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }

  // ─── DATA GENERATORS FOR SPORTS SCIENCE ────────────────────────────────────

  List<_SeriesPoint> _generateSeriesData(double dist, double avgPace) {
    final double actualDist = dist > 0 ? dist : 5.0;
    final double actualPace = avgPace > 0 ? avgPace : 7.0;
    final List<_SeriesPoint> list = [];
    const int count = 25;

    for (int i = 0; i <= count; i++) {
      final d = (actualDist / count) * i;
      final factor = 1.0 + 0.05 * (i % 4 - 2);
      final p = actualPace * factor;
      final elev = 35.0 + 15.0 * (i % 6 - 3) + (i % 3) * 2;
      final slope = (i == 0) ? 0.0 : (elev - list.last.elevation);
      final gap = p - (slope * 0.04);
      final cad = 171.0 + 3.0 * (i % 5 - 2);
      final hr = 138.0 + 12.0 * (i / count);

      list.add(_SeriesPoint(
        distance: d,
        pace: p.clamp(3.0, 15.0),
        gap: gap.clamp(3.0, 15.0),
        cadence: cad.clamp(140.0, 200.0),
        elevation: elev.clamp(0.0, 200.0),
        heartRate: hr.clamp(100.0, 190.0),
      ));
    }
    return list;
  }

  Map<String, String> _generateBestEfforts(double avgPace) {
    String formatTime(double mins) {
      final m = mins.truncate();
      final s = ((mins - m) * 60).round().toString().padLeft(2, '0');
      return '$m:$s';
    }

    final efforts = <String, String>{};
    if (_workout.distance != null && _workout.distance! >= 0.4) {
      efforts['400m'] = formatTime(avgPace * 0.4 * 0.86);
    }
    if (_workout.distance != null && _workout.distance! >= 0.8) {
      efforts['1/2 mile'] = formatTime(avgPace * 0.8 * 0.90);
    }
    if (_workout.distance != null && _workout.distance! >= 1.0) {
      efforts['1K'] = formatTime(avgPace * 1.0 * 0.94);
    }
    if (_workout.distance != null && _workout.distance! >= 1.609) {
      efforts['1 mile'] = formatTime(avgPace * 1.609 * 0.97);
    }
    if (_workout.distance != null && _workout.distance! >= 3.218) {
      efforts['2 mile'] = formatTime(avgPace * 3.218 * 1.0);
    }
    return efforts;
  }

  Map<String, double> _generatePaceZones(double avgPace) {
    double z1 = 0, z2 = 0, z3 = 0, z4 = 0, z5 = 0, z6 = 0;
    if (avgPace >= 5.5) {
      z1 = 92; z2 = 7; z3 = 1;
    } else if (avgPace >= 4.7) {
      z1 = 18; z2 = 64; z3 = 15; z4 = 3;
    } else if (avgPace >= 4.2) {
      z2 = 12; z3 = 62; z4 = 21; z5 = 5;
    } else {
      z3 = 8; z4 = 38; z5 = 44; z6 = 10;
    }
    return {'Z1': z1, 'Z2': z2, 'Z3': z3, 'Z4': z4, 'Z5': z5, 'Z6': z6};
  }

  Widget _buildMuscleSectionFromNotes() {
    final notes = _workout.notes;
    final detailIdx = notes.indexOf('Detail Latihan:');
    if (detailIdx < 0) return const SizedBox();
    final rawDetail = notes.substring(detailIdx + 'Detail Latihan:'.length).trim();

    final exerciseNames = rawDetail
        .split('\n')
        .where((line) => line.trim().isNotEmpty && line.trim().endsWith(':') && !line.trim().startsWith(' '))
        .map((line) => line.trim().replaceAll(':', '').trim())
        .toList();

    if (exerciseNames.isEmpty) return const SizedBox();

    final Map<String, double> muscleDist = {};
    for (final name in exerciseNames) {
      final ex = exerciseDatabase.cast<ExerciseDefinition?>().firstWhere(
        (e) => e!.name.toLowerCase() == name.toLowerCase(),
        orElse: () => null,
      );
      if (ex != null) {
        for (final muscle in ex.muscleGroups) {
          muscleDist[muscle] = (muscleDist[muscle] ?? 0) + 1;
        }
      } else {
        muscleDist[name] = (muscleDist[name] ?? 0) + 1;
      }
    }

    if (muscleDist.isEmpty) return const SizedBox();

    final totalVol = muscleDist.values.fold(0.0, (a, b) => a + b);
    final sorted = muscleDist.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Otot Terlatih', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ...sorted.map((e) {
            final percent = e.value / totalVol;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(width: 110, child: Text(e.key, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 8,
                        backgroundColor: AppTheme.border,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.electricBlue),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 40, child: Text('${(percent * 100).toStringAsFixed(0)}%', textAlign: TextAlign.right, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetailLogsFromNotes() {
    final notes = _workout.notes;
    final detailIdx = notes.indexOf('Detail Latihan:');
    String rawDetail = detailIdx >= 0 ? notes.substring(detailIdx + 'Detail Latihan:'.length).trim() : notes;

    rawDetail = rawDetail.replaceAll(RegExp(r'Catatan:.*\n?'), '').replaceAll(RegExp(r'Intensitas \(RPE\):.*\n?'), '').trim();

    if (rawDetail.isEmpty) return const SizedBox();

    final blocks = rawDetail.split(RegExp(r'\n(?=[A-Za-z])')).where((b) => b.trim().isNotEmpty).toList();

    return Column(
      children: blocks.map((block) {
        final lines = block.trim().split('\n');
        final title = lines.first.replaceAll(':', '').trim();
        final setLines = lines.skip(1).where((l) => l.trim().isNotEmpty).toList();
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.fitness_center_rounded, color: AppTheme.electricBlue, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15))),
              ]),
              if (setLines.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...setLines.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: AppTheme.electricBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text('${e.key + 1}', style: TextStyle(color: AppTheme.electricBlue, fontSize: 12, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 12),
                    Text(e.value.trim(), style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                  ]),
                )),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.electricBlue, size: 20),
          SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  String _calculatePace() {
    if (_workout.distance == null || _workout.distance == 0) return '0:00';
    final paceMins = _workout.duration / _workout.distance!;
    final m = paceMins.truncate();
    final s = ((paceMins - m) * 60).truncate().toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDuration(double mins) {
    final h = (mins / 60).truncate();
    final m = mins.truncate() % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _SeriesPoint {
  final double distance;
  final double pace;
  final double gap;
  final double cadence;
  final double elevation;
  final double heartRate;

  _SeriesPoint({
    required this.distance,
    required this.pace,
    required this.gap,
    required this.cadence,
    required this.elevation,
    required this.heartRate,
  });
}
