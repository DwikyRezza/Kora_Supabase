import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/social_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../screens/public_profile_screen.dart';
import '../screens/workout_detail_screen.dart';
import '../models/workout.dart';
import 'comment_bottom_sheet.dart';
import 'mini_route_painter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
      // ignore
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
    return DateFormat('MMMM d, yyyy').format(date) + ' at ' + DateFormat('h:mm a').format(date);
  }

  ImageProvider? _buildAvatarImage() {
    final url = _photoUrl;
    if (url == null) return null;
    if (url.startsWith('http')) return NetworkImage(url);
    if (url.startsWith('data:image')) {
      try {
        return MemoryImage(
          base64Decode(url.split(',').last.replaceAll(RegExp(r'\s+'), '')),
        );
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void _navigateToDetail() {
    final workoutData = widget.post['workoutData'] as Map<String, dynamic>? ?? {};
    final workout = Workout(
      id: null,
      type: (workoutData['type'] ?? 'running').toString().toLowerCase(),
      duration: (workoutData['duration'] as num? ?? 0.0).toDouble(),
      distance: (workoutData['distance'] as num?)?.toDouble(),
      sets: (workoutData['sets'] as num?)?.toInt(),
      reps: (workoutData['reps'] as num?)?.toInt(),
      weight: (workoutData['weight'] as num?)?.toDouble(),
      caloriesBurned: (workoutData['caloriesBurned'] as num? ?? 0).toInt(),
      proteinNeeded: (workoutData['proteinNeeded'] as num? ?? 0.0).toDouble(),
      notes: workoutData['notes'] ?? '',
      date: widget.post['timestamp'] != null ? (widget.post['timestamp'] as dynamic).toDate() : DateTime.now(),
      polyline: workoutData['polyline'] as String?,
      title: workoutData['title'] as String?,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(
          workout: workout,
          postId: widget.post['postId'] as String?,
          likedBy: widget.post['likedBy'] as List<dynamic>?,
          commentsCount: widget.post['commentsCount'] as int?,
          authorName: _authorName,
          authorPhotoUrl: _photoUrl,
          authorUid: widget.post['uid'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workoutData = widget.post['workoutData'] as Map<String, dynamic>? ?? {};
    final typeLower = (workoutData['type'] ?? 'workout').toString().toLowerCase();
    final title = workoutData['title'] ?? (typeLower == 'running' ? 'Morning Run' : 'Workout');
    final dist = workoutData['distance'] as num? ?? 0.0;
    final dur = workoutData['duration'] as num? ?? 0.0; // minutes
    final polylineStr = workoutData['polyline'] as String?;

    final routePoints = polylineStr != null && polylineStr.isNotEmpty
        ? MiniRoutePainter.parsePolyline(polylineStr)
        : <LatLng>[];

    final hasRoute = routePoints.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 0.5),
          bottom: BorderSide(color: AppTheme.border, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(typeLower),
                const SizedBox(height: 12),

                // ── JUDUL AKTIVITAS ─────────────────────────────────────
                InkWell(
                  onTap: _navigateToDetail,
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── 3 KOLOM METRIK ──────────────────────────────────────
                InkWell(
                  onTap: _navigateToDetail,
                  child: typeLower == 'running' || typeLower == 'walking'
                      ? _buildRunMetrics(dist, dur)
                      : _buildStrengthMetrics(workoutData, dur),
                ),

                const SizedBox(height: 14),
              ],
            ),
          ),

          // ── CHALLENGE / ENCOURAGEMENT BANNER ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.thumb_up_rounded, color: Color(0xFFFF5406), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nicely done! Keep moving by joining a challenge',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5406),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    elevation: 0,
                  ),
                  child: const Text(
                    'See More',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // ── MAP SNAPSHOT ─────────────────────────────────────────────
          if (hasRoute) _buildMapSnapshot(routePoints),
          if (!hasRoute)
            Container(
              height: 8,
              color: AppTheme.surfaceVariant,
            ),

          // ── FOOTER: INTERAKSI SOSIAL ─────────────────────────────────
          _buildSocialFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader(String typeLower) {
    return Row(
      children: [
        // Avatar
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PublicProfileScreen(uid: widget.post['uid'])),
            );
          },
          child: CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.surfaceVariant,
            backgroundImage: _buildAvatarImage(),
            child: _buildAvatarImage() == null
                ? Text(
                    _authorName.isNotEmpty ? _authorName[0].toUpperCase() : 'A',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PublicProfileScreen(uid: widget.post['uid'])),
                  );
                },
                child: Text(
                  _authorName,
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatTime(widget.post['timestamp'])} • Kora App',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    typeLower == 'running' ? Icons.directions_run_rounded : Icons.fitness_center_rounded,
                    size: 13,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Karah, East Java',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRunMetrics(num dist, num dur) {
    return Row(
      children: [
        _metricCell(
          label: 'Distance',
          value: '${dist.toDouble().toStringAsFixed(2)} km',
        ),
        _verticalDivider(),
        _metricCell(
          label: 'Pace',
          value: dist > 0 ? '${_calcPace(dist, dur)} /km' : '—',
        ),
        _verticalDivider(),
        _metricCell(
          label: 'Time',
          value: _formatDuration(dur.toDouble()),
        ),
      ],
    );
  }

  Widget _buildStrengthMetrics(Map<String, dynamic> workoutData, num dur) {
    final sets = workoutData['sets'] as num? ?? 0;
    final reps = workoutData['reps'] as num? ?? 0;

    return Row(
      children: [
        _metricCell(
          label: 'Distance',
          value: '—',
        ),
        _verticalDivider(),
        _metricCell(
          label: 'Pace',
          value: '—',
        ),
        _verticalDivider(),
        _metricCell(
          label: 'Time',
          value: _formatDuration(dur.toDouble()),
        ),
      ],
    );
  }

  Widget _metricCell({required String label, required String value}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.3),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 36,
      color: AppTheme.border,
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  Widget _buildMapSnapshot(List<LatLng> routePoints) {
    if (routePoints.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 0.5),
          bottom: BorderSide(color: AppTheme.border, width: 0.5),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Builder(
                builder: (context) {
                  final apiKey = dotenv.env['MAPS_API_KEY'] ?? '';
                  if (apiKey.isEmpty || routePoints.isEmpty) {
                    return CustomPaint(
                      size: Size.infinite,
                      painter: MiniRoutePainter(routePoints),
                    );
                  }
                  final enc = _encodePolyline(routePoints);
                  final start = '${routePoints.first.latitude},${routePoints.first.longitude}';
                  final end = '${routePoints.last.latitude},${routePoints.last.longitude}';
                  final markers = '&markers=color:green|size:mid|$start&markers=color:red|size:mid|$end';
                  
                  // Gunakan style default untuk Maps
                  final url = 'https://maps.googleapis.com/maps/api/staticmap?size=600x400&path=color:0xFFFF5406ff|weight:4|enc:$enc$markers&key=$apiKey';
                  
                  return Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => CustomPaint(
                      size: Size.infinite,
                      painter: MiniRoutePainter(routePoints),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _navigateToDetail,
                splashColor: Colors.black12,
                highlightColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_likesCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                '$_likesCount Likes',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Like
              _socialButton(
                icon: _isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                label: 'Like',
                color: _isLiked ? const Color(0xFFFF5406) : AppTheme.textSecondary,
                onTap: _toggleLike,
              ),
              // Comment
              _socialButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Komentar',
                color: AppTheme.textSecondary,
                onTap: _showComments,
              ),
              // Share
              _socialButton(
                icon: Icons.share_outlined,
                label: 'Bagikan',
                color: AppTheme.textSecondary,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _socialButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _calcPace(num dist, num dur) {
    if (dist == 0) return '0:00';
    final paceMins = dur / dist;
    final m = paceMins.truncate();
    final s = ((paceMins - m) * 60).truncate().toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDuration(double mins) {
    final h = (mins / 60).truncate();
    final m = mins.truncate() % 60;
    final s = ((mins - mins.truncate()) * 60).round();
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${(mins * 60).round()}s';
  }

  String _encodePolyline(List<LatLng> points) {
    int _round(double value) => (value * 1e5).round();
    String _encode(int value) {
      value = value < 0 ? ~(value << 1) : value << 1;
      String str = '';
      while (value >= 0x20) {
        str += String.fromCharCode((0x20 | (value & 0x1f)) + 63);
        value >>= 5;
      }
      str += String.fromCharCode(value + 63);
      return str;
    }
    int lastLat = 0;
    int lastLng = 0;
    String result = '';
    for (var point in points) {
      int lat = _round(point.latitude);
      int lng = _round(point.longitude);
      result += _encode(lat - lastLat);
      result += _encode(lng - lastLng);
      lastLat = lat;
      lastLng = lng;
    }
    return result;
  }
}
