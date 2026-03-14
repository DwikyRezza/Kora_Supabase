import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../models/workout.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _workout = widget.workout;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _isLoading = true);
      
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(pickedFile.path)}';
      final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');

      List<String> currentPhotos = [];
      if (_workout.photosJson != null && _workout.photosJson!.isNotEmpty) {
        try {
          currentPhotos = List<String>.from(jsonDecode(_workout.photosJson!));
        } catch (_) {}
      } else if (_workout.photoPath != null) {
        currentPhotos = [_workout.photoPath!];
      }
      currentPhotos.add(savedImage.path);

      final updatedWorkout = Workout(
        id: _workout.id,
        type: _workout.type,
        duration: _workout.duration,
        distance: _workout.distance,
        sets: _workout.sets,
        reps: _workout.reps,
        weight: _workout.weight,
        caloriesBurned: _workout.caloriesBurned,
        proteinNeeded: _workout.proteinNeeded,
        notes: _workout.notes,
        date: _workout.date,
        movingTime: _workout.movingTime,
        elevationGain: _workout.elevationGain,
        maxElevation: _workout.maxElevation,
        photoPath: _workout.photoPath, // keep for compatibility
        splitsStr: _workout.splitsStr,
        polyline: _workout.polyline,
        title: _workout.title,
        photosJson: jsonEncode(currentPhotos),
      );

      await DatabaseHelper().updateWorkout(updatedWorkout);

      setState(() {
        _workout = updatedWorkout;
        _isLoading = false;
      });
    }
  }

  Future<void> _editTitle() async {
    final controller = TextEditingController(text: _workout.title ?? (_workout.type == 'running' ? 'Afternoon Run' : 'Workout Session'));
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
                photoPath: _workout.photoPath, splitsStr: _workout.splitsStr,
                polyline: _workout.polyline, title: newTitle, photosJson: _workout.photosJson,
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
      
      await Share.shareXFiles([XFile(imagePath.path)], text: 'Latihan saya hari ini: ${_workout.title ?? _workout.typeLabel}! 🔥 #AthleteSync');
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
        routePoints = decoded.map((p) => LatLng(p[0], p[1])).toList();
      } catch (e) {
        // ignore
      }
    }
    List<String> photos = [];
    if (_workout.photosJson != null && _workout.photosJson!.isNotEmpty) {
      try {
        photos = List<String>.from(jsonDecode(_workout.photosJson!));
      } catch (_) {}
    } else if (_workout.photoPath != null) {
      photos = [_workout.photoPath!];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_workout.typeLabel),
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined),
            onPressed: _shareActivity,
          ),
        ],
      ),
      backgroundColor: AppTheme.background,
      body: Screenshot(
        controller: _screenshotController,
        child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Activity Title & User Info (Image 2 style)
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.surfaceVariant,
                    child: Text('👤'),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dwiky Rezza', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
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
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _workout.title ?? (_workout.type == 'running' ? 'Afternoon Run' : 'Workout Session'),
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
            
            SizedBox(height: 16),
            
            // Main Stats Row
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_workout.distance != null)
                    _statHeader('Distance', '${_workout.distance!.toStringAsFixed(2)} km'),
                  if (_workout.type == 'running')
                    _statHeader('Pace', '${_calculatePace()} /km'),
                  _statHeader('Time', _formatDuration(_workout.duration)),
                ],
              ),
            ),

            SizedBox(height: 24),

            if (routePoints.isNotEmpty)
              Container(
                height: 300,
                width: double.infinity,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: routePoints.isNotEmpty ? routePoints[routePoints.length ~/ 2] : LatLng(0, 0),
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.athletesync',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          strokeWidth: 4.0,
                          color: Color(0xFFFC5200),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            SizedBox(height: 24),

            Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Lainnya'),
                  SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _buildStatCard('Kalori', '${_workout.caloriesBurned} kal', Icons.local_fire_department),
                      _buildStatCard('Protein', '${_workout.proteinNeeded.toStringAsFixed(1)}g', Icons.egg_alt),
                      if (_workout.elevationGain != null && _workout.elevationGain! > 0)
                        _buildStatCard('Elev Gain', '${_workout.elevationGain!.toStringAsFixed(1)} m', Icons.terrain),
                      if (_workout.maxElevation != null && _workout.maxElevation! > 0)
                        _buildStatCard('Max Elev', '${_workout.maxElevation!.toStringAsFixed(1)} m', Icons.landscape),
                    ],
                  ),
                  
                  if (splits.isNotEmpty) ...[
                    SizedBox(height: 24),
                    _buildSectionTitle('Splits'),
                    SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: splits.length,
                        separatorBuilder: (_, __) => Divider(color: AppTheme.border, height: 1),
                        itemBuilder: (context, i) {
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.surfaceVariant,
                              child: Text('${i + 1}', style: TextStyle(color: AppTheme.textPrimary)),
                            ),
                            title: Text('Kilometer ${i + 1}', style: TextStyle(color: AppTheme.textPrimary)),
                            trailing: Text('${splits[i]} /km', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                    ),
                  ],

                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('Foto Latihan'),
                      IconButton(
                        icon: Icon(Icons.add_a_photo, color: AppTheme.electricBlue),
                        onPressed: _isLoading ? null : _pickImage,
                      )
                    ],
                  ),
                  SizedBox(height: 12),
                  if (photos.isNotEmpty)
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        itemBuilder: (context, i) {
                          return Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                File(photos[i]),
                                width: 300,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 48),
          ],
        ),
      ),
    ),
    );
  }

  Widget _statHeader(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
      ],
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.electricBlue, size: 24),
          SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
