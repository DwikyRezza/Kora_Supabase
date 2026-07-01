import 'package:flutter/material.dart';
import '../utils/tab_visibility.dart';
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
import '../widgets/feed_post_card.dart';
import '../utils/responsive.dart';

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
  List<Map<String, dynamic>> _userPosts = [];
  Set<int> _workoutsWithPhotos = {};  // Lazy-loading: Set ID workout yang punya foto

  // Constants for custom colors
  static Color get primaryColor => AppTheme.accent;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    
    // Load profile
    final profile = await ProfileService.getProfile();
    
    // Load social stats
    final uid = AuthService.uid;
    int followers = 0;
    int following = 0;
    List<Map<String, dynamic>> userPosts = [];
    if (uid != null && uid.isNotEmpty) {
      followers = await SocialService.getFollowersCount(uid);
      following = await SocialService.getFollowingCount(uid);
      userPosts = await SocialService.getUserPosts(uid);
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
      _userPosts = userPosts;
      _activitiesCount = userPosts.length;
      _workoutsWithPhotos = idsWithPhotos;
      _isLoading = false;
    });
  }



  Widget _buildMap(String polylineStr) {
    try {
      final List<dynamic> decoded = jsonDecode(polylineStr);
      if (decoded.isEmpty) return Container(color: AppTheme.surfaceVariant);
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
            color: AppTheme.accent,
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
      return Container(color: AppTheme.surfaceVariant);
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
        backgroundColor: AppTheme.surface,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
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
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        automaticallyImplyLeading: false, // since it's a bottom nav page
        title: Row(
          children: [
            Text(
              'Profile',
              style: TextStyle(
                color: primaryColor,
                fontSize: context.fontXL * 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: context.spaceSM),
            Text(
              '@$username',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: context.fontSM,
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
          SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.spaceXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: context.spaceLG),
              
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
                          width: context.avatarLG * 1.5,
                          height: context.avatarLG * 1.5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.surfaceVariant, width: 4),
                          ),
                          child: ClipOval(
                            child: (photoUrl != null && photoUrl.isNotEmpty)
                                ? (photoUrl.startsWith('data:image')
                                    ? Image.memory(base64Decode(photoUrl.split(',')[1]), fit: BoxFit.cover)
                                    : Image.network(photoUrl, fit: BoxFit.cover))
                                : Container(
                                    color: AppTheme.surfaceVariant,
                                    child: Icon(Icons.person, size: context.iconLG * 1.5, color: AppTheme.textMuted),
                                  ),
                          ),
                        ),
                        Container(
                          width: context.spaceXL,
                          height: context.spaceXL,
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.surface, width: 2),
                          ),
                          child: Icon(Icons.photo_camera, color: Colors.white, size: context.iconSM * 0.7),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(width: context.spaceLG),
                  
                  // Stats
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final username = _profile[ProfileService.keyUsername] ?? _profile[ProfileService.keyName] ?? 'user';
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => SocialScreen(initialTab: 'followers', username: username, uid: AuthService.uid)));
                              _loadData();
                            },
                            child: _buildStatColumn(_followersCount.toString(), 'Pengikut'),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final username = _profile[ProfileService.keyUsername] ?? _profile[ProfileService.keyName] ?? 'user';
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => SocialScreen(initialTab: 'following', username: username, uid: AuthService.uid)));
                              _loadData();
                            },
                            child: _buildStatColumn(_followingCount.toString(), 'Mengikuti'),
                          ),
                        ),
                        Expanded(child: _buildStatColumn(_activitiesCount.toString(), 'Aktivitas')),
                      ],
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 20),
              
              // Bio Section
              Text(
                displayName,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                bio.isNotEmpty ? '$bio • $goal Goal' : '$goal Goal',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 12),
              
              // BMI Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monitor_weight_rounded, color: AppTheme.accent, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'BMI $bmiStr $bmiStatus',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 32),
              
              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToEditProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.textPrimary, // Graphite
                    foregroundColor: AppTheme.surface,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Edit Profil',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 48),
              
              // Feed Content
              _buildListFeed(),
              
              SizedBox(height: 40),
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
    if (_userPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('Belum ada aktivitas olahraga.', style: TextStyle(color: AppTheme.textMuted)),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        return FeedPostCard(
          post: _userPosts[index],
          onDataChanged: () => _loadData(silent: true),
        );
      },
    );
  }
}
