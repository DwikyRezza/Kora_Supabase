import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userName, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
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
            
            SizedBox(height: 16),
            
            // Main Stats Row
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (_workout.distance != null) ...[
                    Expanded(child: _statHeader('Distance', '${_workout.distance!.toStringAsFixed(2)} km')),
                    SizedBox(width: 8),
                  ],
                  if (_workout.type == 'running') ...[
                    Expanded(child: _statHeader('Pace', '${_calculatePace()} /km')),
                    SizedBox(width: 8),
                  ],
                  Expanded(child: _statHeader('Time', _formatDuration(_workout.duration))),
                ],
              ),
            ),

            SizedBox(height: 24),

            if (routePoints.isNotEmpty)
              Container(
                height: 300,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: routePoints[routePoints.length ~/ 2],
                      zoom: 14.0,
                    ),
                    style: '''[
                      {"elementType":"geometry","stylers":[{"color":"#212121"}]},
                      {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
                      {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
                      {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
                      {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
                      {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},
                      {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
                      {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},
                      {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#181818"}]}
                    ]''',
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    scrollGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    mapToolbarEnabled: false,
                    polylines: {
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: routePoints,
                        color: const Color(0xFFFC5200),
                        width: 5,
                        startCap: Cap.roundCap,
                        endCap: Cap.roundCap,
                        jointType: JointType.round,
                      ),
                    },
                    markers: {
                      if (routePoints.isNotEmpty)
                        Marker(
                          markerId: const MarkerId('start'),
                          position: routePoints.first,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen,
                          ),
                        ),
                      if (routePoints.length > 1)
                        Marker(
                          markerId: const MarkerId('end'),
                          position: routePoints.last,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed,
                          ),
                        ),
                    },
                    mapType: MapType.normal,
                  ),
                ),
              ),


            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- STAT GRID 2x2 ---
                  _buildStatsGrid(),
                  const SizedBox(height: 28),

                  // --- MUSCLE DISTRIBUTION (weightlifting) ---
                  if (_workout.type == 'weightlifting') ...[
                    _buildMuscleSectionFromNotes(),
                    const SizedBox(height: 28),
                  ],

                  // --- DETAIL PER GERAKAN (from notes) ---
                  if (_workout.notes != null && _workout.notes!.isNotEmpty) ...[
                    _buildSectionTitle('Detail Per Gerakan'),
                    const SizedBox(height: 12),
                    _buildDetailLogsFromNotes(),
                    const SizedBox(height: 28),
                  ],

                  // --- RPE (from notes) ---
                  ..._buildRPEFromNotes(),
                  const SizedBox(height: 28),

                  // --- SPLITS (lari) ---
                  if (splits.isNotEmpty) ...[
                    _buildSectionTitle('Splits'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
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
                    const SizedBox(height: 28),
                  ],

                  // --- FOTO LATIHAN (Lazy Loading dari tabel terpisah) ---
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
                  const SizedBox(height: 12),
                  if (_workout.id != null)
                    FutureBuilder<List<String>>(
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
                        if (photos.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return SizedBox(
                          height: 200,
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
                                    width: 300,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 48),
                ],
              ),
            ),

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
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final List<List<Widget>> rows = [];
    final allCards = <Widget>[
      _buildStatCard('Kalori', '${_workout.caloriesBurned} kal', Icons.local_fire_department),
      if (_workout.type == 'running') ...[
        _buildStatCard('Jarak', '${(_workout.distance ?? 0).toStringAsFixed(2)} km', Icons.straighten),
        _buildStatCard('Avg Pace', '${_calculatePace()} /km', Icons.speed),
        if (_workout.movingTime != null && _workout.movingTime! > 0)
          _buildStatCard('Moving Time', _formatDuration(_workout.movingTime!), Icons.timer),
      ] else if (_workout.type == 'weightlifting') ...[
        _buildStatCard('Total Reps', '${_workout.reps ?? 0}', Icons.repeat_rounded),
        _buildStatCard('Total Set', '${_workout.sets ?? 0}', Icons.layers_rounded),
        _buildStatCard('Total Volume', '${_workout.weight?.toStringAsFixed(0) ?? 0} kg', Icons.fitness_center_rounded),
        if (_workout.movingTime != null && _workout.movingTime! > 0)
          _buildStatCard('Moving Time', _formatDuration(_workout.movingTime!), Icons.timer),
      ] else ...[
        if (_workout.movingTime != null && _workout.movingTime! > 0)
          _buildStatCard('Moving Time', _formatDuration(_workout.movingTime!), Icons.timer),
      ],
      if (_workout.elevationGain != null && _workout.elevationGain! > 0)
        _buildStatCard('Elev Gain', '${_workout.elevationGain!.toStringAsFixed(1)} m', Icons.terrain),
      if (_workout.maxElevation != null && _workout.maxElevation! > 0)
        _buildStatCard('Max Elev', '${_workout.maxElevation!.toStringAsFixed(1)} m', Icons.landscape),
    ];
    for (int i = 0; i < allCards.length; i += 2) {
      rows.add([
        allCards[i],
        if (i + 1 < allCards.length) allCards[i + 1] else SizedBox.shrink(),
      ]);
    }
    return Column(
      children: rows.map((pair) => Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(child: pair[0]),
            SizedBox(width: 12),
            Expanded(child: pair[1]),
          ],
        ),
      )).toList(),
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

  // --- PARSE NOTES: Muscle Distribution ---
  Widget _buildMuscleSectionFromNotes() {
    final notes = _workout.notes ?? '';
    // Cari bagian 'Detail Latihan:'
    final detailIdx = notes.indexOf('Detail Latihan:');
    if (detailIdx < 0) return const SizedBox();
    final rawDetail = notes.substring(detailIdx + 'Detail Latihan:'.length).trim();

    // Ambil baris yang merupakan nama gerakan (diikuti tanda ':')
    final exerciseNames = rawDetail
        .split('\n')
        .where((line) => line.trim().isNotEmpty && line.trim().endsWith(':') && !line.trim().startsWith(' '))
        .map((line) => line.trim().replaceAll(':', '').trim())
        .toList();

    if (exerciseNames.isEmpty) return const SizedBox();

    // Lookup muscle groups dari exerciseDatabase
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
        // fallback: gunakan nama gerakan sebagai otot
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

  // --- PARSE NOTES: Detail Per Gerakan ---
  Widget _buildDetailLogsFromNotes() {
    final notes = _workout.notes ?? '';
    // Pisah bagian "Detail Latihan:" dari notes
    final detailIdx = notes.indexOf('Detail Latihan:');
    String rawDetail = detailIdx >= 0 ? notes.substring(detailIdx + 'Detail Latihan:'.length).trim() : notes;

    // Hilangkan baris Catatan & RPE agar tidak muncul di sini
    rawDetail = rawDetail.replaceAll(RegExp(r'Catatan:.*\n?'), '').replaceAll(RegExp(r'Intensitas \(RPE\):.*\n?'), '').trim();

    if (rawDetail.isEmpty) return const SizedBox();

    // Pecah per gerakan
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

  // --- PARSE NOTES: RPE ---
  List<Widget> _buildRPEFromNotes() {
    final notes = _workout.notes ?? '';
    final match = RegExp(r'Intensitas \(RPE\): (\d+)/10').firstMatch(notes);
    if (match == null) return [];
    final rpeVal = double.tryParse(match.group(1) ?? '0') ?? 0;
    final Color rpeColor = rpeVal > 7 ? const Color(0xFFFF4444) : (rpeVal > 4 ? const Color(0xFFFFB830) : const Color(0xFF00D68F));
    return [
      Text('Intensitas Latihan (RPE)', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          Expanded(child: LinearProgressIndicator(
            value: rpeVal / 10,
            minHeight: 10,
            backgroundColor: AppTheme.border,
            valueColor: AlwaysStoppedAnimation<Color>(rpeColor),
          )),
          const SizedBox(width: 16),
          Text('${rpeVal.toInt()}/10', style: TextStyle(color: rpeColor, fontSize: 20, fontWeight: FontWeight.w900)),
        ]),
      ),
    ];
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
}
