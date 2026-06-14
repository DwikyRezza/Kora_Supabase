import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/social_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../screens/public_profile_screen.dart';
import 'comment_bottom_sheet.dart';

class FeedPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onDataChanged;

  const FeedPostCard({
    super.key,
    required this.post,
    required this.onDataChanged,
  });

  @override
  State<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<FeedPostCard> {
  late bool _isLiked;
  late int _likesCount;
  late int _commentsCount;
  bool _isLiking = false;
  
  String _authorName = 'Athlete';
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void didUpdateWidget(FeedPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post != oldWidget.post) {
      _initData();
    }
  }

  void _initData() {
    final likedBy = widget.post['likedBy'] as List<dynamic>? ?? [];
    final currentUid = AuthService.uid;
    _isLiked = likedBy.contains(currentUid);
    _likesCount = likedBy.length;
    _commentsCount = widget.post['commentsCount'] as int? ?? 0;
    
    _authorName = widget.post['authorName'] ?? 'Athlete';
    _photoUrl = widget.post['authorPhotoUrl'];
    
    _fetchLatestProfile();
  }

  Future<void> _fetchLatestProfile() async {
    try {
      final uid = widget.post['uid'] as String?;
      if (uid == null) return;
      
      final profile = await SocialService.getUserProfile(uid);
      if (profile != null && mounted) {
        setState(() {
          _authorName = profile['name'] ?? _authorName;
          _photoUrl = profile['photoUrl'] ?? _photoUrl;
        });
      }
    } catch (e) {
      print('[FeedPostCard] Error fetching profile: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    setState(() {
      _isLiking = true;
      if (_isLiked) {
        _likesCount--;
      } else {
        _likesCount++;
      }
      _isLiked = !_isLiked;
    });

    final postId = widget.post['postId'] as String;
    final likedBy = widget.post['likedBy'] as List<dynamic>? ?? [];
    
    await SocialService.toggleLike(postId, likedBy);
    setState(() => _isLiking = false);
    widget.onDataChanged(); // Trigger reload di parent
  }

  void _showComments() {
    final postId = widget.post['postId'] as String;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CommentBottomSheet(postId: postId),
      ),
    ).then((_) => widget.onDataChanged());
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy • HH.mm').format(date);
  }

  Widget _buildAvatar(String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      try {
        if (photoUrl.startsWith('data:image')) {
          final parts = photoUrl.split(',');
          if (parts.length > 1) {
            return ClipOval(child: Image.memory(base64Decode(parts[1]), fit: BoxFit.cover));
          }
        }
        return ClipOval(child: Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, color: Colors.grey)));
      } catch (_) {}
    }
    return const Icon(Icons.person, color: Colors.grey);
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

  @override
  Widget build(BuildContext context) {
    final workoutData = widget.post['workoutData'] as Map<String, dynamic>? ?? {};
    final typeLower = (workoutData['type'] ?? 'workout').toString().toLowerCase();
    final title = workoutData['title'] ?? 'Aktivitas Latihan';
    final dist = workoutData['distance'] as num? ?? 0.0;
    final dur = workoutData['duration'] as num? ?? 0.0; // minutes
    final calories = workoutData['caloriesBurned'] as num? ?? 0;
    final polylineStr = workoutData['polyline'] as String?;

    String defaultImage;
    if (typeLower == 'running' || typeLower == 'lari') {
      defaultImage = 'https://images.unsplash.com/photo-1552674605-15c2145efa38?q=80&w=800&auto=format&fit=crop'; 
    } else if (typeLower == 'weightlifting' || typeLower == 'beban' || typeLower == 'gym') {
      defaultImage = 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=800&auto=format&fit=crop';
    } else if (typeLower == 'basketball' || typeLower == 'basket') {
      defaultImage = 'https://images.unsplash.com/photo-1546519638-68e109498ffc?q=80&w=800&auto=format&fit=crop';
    } else {
      defaultImage = 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?q=80&w=800&auto=format&fit=crop';
    }

    final bool hasMap = (typeLower == 'running' || typeLower == 'lari') && polylineStr != null && polylineStr.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
      ),
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header User
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PublicProfileScreen(uid: widget.post['uid'])),
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
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
                    child: _buildAvatar(_photoUrl)
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _authorName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600, 
                          fontSize: 16, 
                          color: AppTheme.textPrimary
                        ),
                      ),
                      Text(
                        _formatTime(widget.post['timestamp']),
                        style: TextStyle(
                          color: AppTheme.textSecondary, 
                          fontSize: 12
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
              if (typeLower == 'running' || typeLower == 'lari') ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Jarak', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.7)),
                    Text('${dist > 0 ? dist.toStringAsFixed(2) : "0.0"} km', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pace', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.7)),
                    Text('${(dur / (dist == 0 ? 1 : dist)).toStringAsFixed(2)} /km', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Waktu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.7)),
                    Text('${dur.toStringAsFixed(0)}m', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  ],
                ),
              ] else ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Durasi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.7)),
                    Text('${dur.toStringAsFixed(0)} mnt', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kalori', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.7)),
                    Text('${calories} kkal', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          
          // Gambar/Visual Aktivitas
          if (hasMap) ...[
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                color: AppTheme.surfaceVariant,
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: _buildMap(polylineStr!),
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
                  onTap: _toggleLike,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border, 
                          color: _isLiked ? Colors.red : AppTheme.textSecondary, 
                          size: 24
                        ),
                        const SizedBox(width: 8),
                        Text('$_likesCount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: _showComments,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, color: AppTheme.textSecondary, size: 24),
                        const SizedBox(width: 8),
                        Text('$_commentsCount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
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
  }
}
