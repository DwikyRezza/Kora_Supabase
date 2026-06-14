import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/workout.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../services/social_service.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import 'setting_screen.dart';
import 'edit_profile_screen.dart';
import 'social_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _profile = {};
  int _followersCount = 0;
  int _followingCount = 0;
  int _activitiesCount = 0;
  List<Workout> _activitiesList = [];
  Set<int> _workoutsWithPhotos = {};  // Lazy-loading: Set ID workout yang punya foto

  // State untuk Fitur Sosial (Lokal/Simulasi)
  final Map<int, int> _likesCount = {};
  final Map<int, bool> _isLiked = {};
  final Map<int, List<Map<String, String>>> _comments = {};

  // Constants for custom colors
  static const Color primaryColor = Color(0xFFA83300);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Load profile
    final profile = await ProfileService.getProfile();
    
    // Load social stats
    final uid = AuthService.uid;
    int followers = 0;
    int following = 0;
    if (uid != null && uid.isNotEmpty) {
      followers = await SocialService.getFollowersCount(uid);
      following = await SocialService.getFollowingCount(uid);
    }
    
    // Load activities
    final allWorkouts = await DatabaseHelper().getAllWorkouts();
    
    // Batch check: workout mana saja yang punya foto (lazy — tanpa load data foto)
    final workoutIds = allWorkouts.map((w) => w.id).where((id) => id != null).cast<int>().toList();
    final idsWithPhotos = await DatabaseHelper().getWorkoutIdsWithPhotos(workoutIds);
    
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _followersCount = followers;
      _followingCount = following;
      _activitiesList = allWorkouts;
      _activitiesCount = allWorkouts.length;
      _workoutsWithPhotos = idsWithPhotos;
      _isLoading = false;
    });
  }

  void _toggleLike(int index) {
    setState(() {
      final currentlyLiked = _isLiked[index] ?? false;
      _isLiked[index] = !currentlyLiked;
      final currentCount = _likesCount[index] ?? 0;
      _likesCount[index] = currentlyLiked ? (currentCount > 0 ? currentCount - 1 : 0) : currentCount + 1;
    });
  }

  void _deleteWorkout(Workout workout) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Aktivitas?'),
        content: const Text('Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && workout.id != null) {
      await DatabaseHelper().deleteWorkout(workout.id!);
      _loadData();
    }
  }

  void _shareWorkout(Workout workout) {
    final title = workout.title ?? workout.typeLabel;
    final text = 'Saya baru saja menyelesaikan $title selama ${workout.duration.toStringAsFixed(0)} menit dan membakar ${workout.caloriesBurned} kalori! #AthleteSync';
    Share.share(text);
  }

  void _showComments(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentBottomSheet(
        comments: _comments[index] ?? [],
        onCommentAdded: (text) {
          setState(() {
            if (_comments[index] == null) _comments[index] = [];
            _comments[index]!.add({
              'name': _profile[ProfileService.keyName] ?? 'Atlet Elit',
              'text': text,
              'time': 'Baru saja',
            });
          });
        },
      ),
    );
  }

  Widget _buildMap(String polylineStr) {
    try {
      final List<dynamic> decoded = jsonDecode(polylineStr);
      if (decoded.isEmpty) return Container(color: Colors.grey[200]);
      final List<LatLng> points = decoded.map((p) => LatLng(p[0] as double, p[1] as double)).toList();
      
      double minLat = points.first.latitude;
      double maxLat = points.first.latitude;
      double minLng = points.first.longitude;
      double maxLng = points.first.longitude;
      for (var p in points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      
      return GoogleMap(
        initialCameraPosition: CameraPosition(target: points.first, zoom: 14),
        liteModeEnabled: true,
        zoomControlsEnabled: false,
        myLocationButtonEnabled: false,
        polylines: {
          Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: const Color(0xFFFF5406),
            width: 4,
          )
        },
        onMapCreated: (controller) {
          Future.delayed(const Duration(milliseconds: 200), () {
            controller.animateCamera(CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(minLat, minLng),
                northeast: LatLng(maxLat, maxLng),
              ),
              20.0,
            ));
          });
        },
      );
    } catch (e) {
      return Container(color: Colors.grey[200]);
    }
  }

  double _calculateBMI() {
    final height = (_profile[ProfileService.keyHeight] as num?)?.toDouble() ?? 0.0;
    final weight = (_profile[ProfileService.keyWeight] as num?)?.toDouble() ?? 0.0;
    if (height > 0 && weight > 0) {
      final h = height / 100;
      return weight / (h * h);
    }
    return 0.0;
  }

  void _goToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (result == true) {
      _loadData(); // Reload if updated
    }
  }

  void _goToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    final username = _profile[ProfileService.keyUsername] ?? '';
    final displayName = _profile[ProfileService.keyName] ?? 'Atlet Elit';
    final bio = _profile[ProfileService.keyStatus] ?? '';
    final goal = _profile[ProfileService.keyGoal] ?? 'Bulking';
    final photoUrl = _profile['photoUrl'] as String?;
    final bmi = _calculateBMI();
    
    // BMI Status string formatter
    String bmiStr = bmi > 0 ? bmi.toStringAsFixed(1) : '-';
    String bmiStatus = ProfileService.getBMIStatus(bmi);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // since it's a bottom nav page
        title: Row(
          children: [
            const Text(
              'Profile',
              style: TextStyle(
                color: primaryColor,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '@$username',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: AppTheme.textSecondary),
            onPressed: _goToSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              
              // Profile Header Section
              Row(
                children: [
                  // Photo
                  GestureDetector(
                    onTap: _goToEditProfile,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFF5F5F5), width: 4),
                          ),
                          child: ClipOval(
                            child: (photoUrl != null && photoUrl.isNotEmpty)
                                ? (photoUrl.startsWith('data:image')
                                    ? Image.memory(base64Decode(photoUrl.split(',')[1]), fit: BoxFit.cover)
                                    : Image.network(photoUrl, fit: BoxFit.cover))
                                : Container(
                                    color: const Color(0xFFF5F5F5),
                                    child: const Icon(Icons.person, size: 48, color: Colors.grey),
                                  ),
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5406),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.photo_camera, color: Colors.white, size: 14),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Stats
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final username = _profile[ProfileService.keyUsername] ?? _profile[ProfileService.keyName] ?? 'user';
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => SocialScreen(initialTab: 'following', username: username)));
                              _loadData();
                            },
                            child: _buildStatColumn(_followingCount.toString(), 'Mengikuti'),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final username = _profile[ProfileService.keyUsername] ?? _profile[ProfileService.keyName] ?? 'user';
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => SocialScreen(initialTab: 'followers', username: username)));
                              _loadData();
                            },
                            child: _buildStatColumn(_followersCount.toString(), 'Pengikut'),
                          ),
                        ),
                        Expanded(child: _buildStatColumn(_activitiesCount.toString(), 'Aktivitas')),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Bio Section
              Text(
                displayName,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bio.isNotEmpty ? '$bio • $goal Goal' : '$goal Goal',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              
              // BMI Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7EC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00B33F).withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monitor_weight_rounded, color: Color(0xFF00B33F), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'BMI $bmiStr $bmiStatus',
                      style: const TextStyle(
                        color: Color(0xFF00B33F),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToEditProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F2F2F), // Graphite
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Edit Profil',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Feed Content
              _buildListFeed(),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }



  Widget _buildListFeed() {
    if (_activitiesList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('Belum ada aktivitas olahraga.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _activitiesList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final workout = _activitiesList[index];
        final hasPhoto = workout.id != null && _workoutsWithPhotos.contains(workout.id);
        final dateStr = DateFormat('dd MMM yyyy • HH.mm').format(workout.date);

        final typeLower = workout.type.toLowerCase();
        String defaultImage;
        if (typeLower == 'running' || typeLower == 'lari') {
          // Visual running track map / lari
          defaultImage = 'https://images.unsplash.com/photo-1552674605-15c2145efa38?q=80&w=800&auto=format&fit=crop'; 
        } else if (typeLower == 'weightlifting' || typeLower == 'beban' || typeLower == 'gym') {
          // Visual angkat beban
          defaultImage = 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=800&auto=format&fit=crop';
        } else if (typeLower == 'basketball' || typeLower == 'basket') {
          // Visual basket
          defaultImage = 'https://images.unsplash.com/photo-1546519638-68e109498ffc?q=80&w=800&auto=format&fit=crop';
        } else {
          defaultImage = 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?q=80&w=800&auto=format&fit=crop';
        }

        final title = workout.title ?? workout.typeLabel;
        final profilePhoto = _profile?['photoUrl'] as String?;
        final profileName = _profile?['name'] ?? 'User';
        
        return Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
          ),
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header User
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: (profilePhoto != null && profilePhoto.isNotEmpty)
                          ? (profilePhoto.startsWith('data:image')
                              ? Image.memory(base64Decode(profilePhoto.split(',')[1]), fit: BoxFit.cover)
                              : Image.network(profilePhoto, fit: BoxFit.cover))
                          : const Icon(Icons.person, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profileName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600, 
                            fontSize: 16, 
                            color: AppTheme.textPrimary
                          ),
                        ),
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: AppTheme.textSecondary, 
                            fontSize: 12
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: AppTheme.textSecondary),
                    onSelected: (value) {
                      if (value == 'share') _shareWorkout(workout);
                      if (value == 'delete') _deleteWorkout(workout);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'share', child: Text('Bagikan')),
                      const PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Judul Aktivitas
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700, 
                  fontSize: 22, 
                  color: AppTheme.textPrimary
                ),
              ),
              const SizedBox(height: 16),
              
              // Baris Statistik
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (workout.type == 'running') ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Jarak', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.7)),
                        Text('${workout.distance?.toStringAsFixed(2) ?? "0.0"} km', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pace', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.7)),
                        Text('${(workout.duration / (workout.distance == null || workout.distance == 0 ? 1 : workout.distance!)).toStringAsFixed(2)} /km', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Waktu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.7)),
                        Text('${workout.duration.toStringAsFixed(0)}m', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      ],
                    ),
                  ] else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Durasi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.7)),
                        Text('${workout.duration.toStringAsFixed(0)} mnt', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kalori', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.7)),
                        Text('${workout.caloriesBurned} kkal', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      ],
                    ),

                  ],
                ],
              ),
              const SizedBox(height: 24),
              
              if (typeLower == 'running' || typeLower == 'lari' || hasPhoto) ...[
                // Gambar/Visual Aktivitas
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    color: const Color(0xFFF5F5F5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: hasPhoto 
                      ? FutureBuilder<String?>(
                          future: DatabaseHelper().getFirstWorkoutPhoto(workout.id!),
                          builder: (context, snap) {
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                            }
                            final path = snap.data;
                            if (path != null && File(path).existsSync()) {
                              return Image.file(File(path), fit: BoxFit.cover);
                            }
                            // Fallback jika file hilang
                            return ((typeLower == 'running' || typeLower == 'lari') && workout.polyline != null && workout.polyline!.isNotEmpty)
                                ? _buildMap(workout.polyline!)
                                : Image.network(defaultImage, fit: BoxFit.cover);
                          },
                        )
                      : ((typeLower == 'running' || typeLower == 'lari') && workout.polyline != null && workout.polyline!.isNotEmpty)
                          ? _buildMap(workout.polyline!)
                          : Image.network(defaultImage, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Aksi (Like & Komen)
              Container(
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => _toggleLike(index),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              (_isLiked[index] ?? false) ? Icons.favorite : Icons.favorite_border, 
                              color: (_isLiked[index] ?? false) ? Colors.red : AppTheme.textSecondary, 
                              size: 24
                            ),
                            const SizedBox(width: 8),
                            Text('${_likesCount[index] ?? 0}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () => _showComments(index),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.chat_bubble_outline, color: AppTheme.textSecondary, size: 24),
                            const SizedBox(width: 8),
                            Text('${_comments[index]?.length ?? 0}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommentBottomSheet extends StatefulWidget {
  final List<Map<String, String>> comments;
  final Function(String) onCommentAdded;
  
  const _CommentBottomSheet({required this.comments, required this.onCommentAdded});

  @override
  State<_CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<_CommentBottomSheet> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.only(top: kToolbarHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('Komentar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(),
          Expanded(
            child: widget.comments.isEmpty
                ? const Center(child: Text('Belum ada komentar. Jadilah yang pertama!', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.comments.length,
                    itemBuilder: (context, i) {
                      final c = widget.comments[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(radius: 16, backgroundColor: Colors.grey[300], child: const Icon(Icons.person, size: 20, color: Colors.grey)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(c['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Text(c['time']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(c['text']!),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Tambahkan komentar...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFFA83300)),
                  onPressed: () {
                    if (_controller.text.trim().isNotEmpty) {
                      widget.onCommentAdded(_controller.text.trim());
                      _controller.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
