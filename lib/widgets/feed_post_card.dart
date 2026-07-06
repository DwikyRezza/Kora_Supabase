import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/social_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../features/profile/presentation/screens/public_profile_screen.dart';
import '../features/profile/bloc/public_profile/public_profile_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/workout/presentation/screens/workout_detail_screen.dart';
import '../models/workout.dart';
import 'comment_bottom_sheet.dart';
import 'mini_route_painter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' hide Polyline, LatLngBounds;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll2;
import 'package:geocoding/geocoding.dart';
import '../utils/responsive.dart';

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

class _FeedPostCardState extends State<FeedPostCard> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late bool _isLiked;
  late int _likesCount;
  late int _commentsCount;
  bool _isLiking = false;
  bool _isKeyboardOpen = false;

  String _authorName = 'Athlete';
  String? _photoUrl;
  String _locationName = 'Mencari lokasi...';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initData();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    final workoutData = widget.post['workoutData'] as Map<String, dynamic>? ?? {};
    final polylineStr = workoutData['polyline'] as String?;
    if (polylineStr != null && polylineStr.isNotEmpty) {
      final routePoints = MiniRoutePainter.parsePolyline(polylineStr);
      if (routePoints.isNotEmpty) {
        try {
          final pt = routePoints.first;
          final placemarks = await placemarkFromCoordinates(pt.latitude, pt.longitude);
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            String loc = '';
            if (place.subLocality != null && place.subLocality!.isNotEmpty) {
              loc = place.subLocality!;
            } else if (place.locality != null && place.locality!.isNotEmpty) {
              loc = place.locality!;
            }
            if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
              loc += (loc.isNotEmpty ? ', ' : '') + place.administrativeArea!;
            }
            if (mounted) setState(() => _locationName = loc.isNotEmpty ? loc : 'Aktivitas Kora');
            return;
          }
        } catch (e) {
          // Fallback on error
        }
      }
    }
    if (mounted) setState(() => _locationName = 'Aktivitas Kora');
  }



  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final isOpen = view.viewInsets.bottom > 0;
    if (_isKeyboardOpen != isOpen) {
      setState(() {
        _isKeyboardOpen = isOpen;
      });
    }
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
    return '${DateFormat('MMMM d, yyyy').format(date)} at ${DateFormat('h:mm a').format(date)}';
  }

  ImageProvider? _buildAvatarImage() {
    final url = _photoUrl;
    if (url == null) return null;
    if (url.startsWith('http')) return NetworkImage(url);
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
    super.build(context);
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
      decoration: BoxDecoration(
        color: AppTheme.surface,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _navigateToDetail,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HEADER ──────────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(context.spaceLG, context.spaceLG, context.spaceLG, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(typeLower),
                    const RSpace.md(),

                    // ── JUDUL AKTIVITAS ─────────────────────────────────────
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: context.fontLG,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const RSpace.md(),

                    // ── 3 KOLOM METRIK ──────────────────────────────────────
                    typeLower == 'running' || typeLower == 'walking'
                        ? _buildRunMetrics(dist, dur)
                        : _buildStrengthMetrics(workoutData, dur),

                    const RSpace.md(),
                  ],
                ),
              ),


              // ── MAP SNAPSHOT ─────────────────────────────────────────────
              if (hasRoute) _buildMapSnapshot(routePoints),
              if (!hasRoute)
                const SizedBox(height: 8),

              // ── FOOTER: INTERAKSI SOSIAL ─────────────────────────────────
              _buildSocialFooter(),
            ],
          ),
        ),
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
              MaterialPageRoute(
                builder: (_) => BlocProvider<PublicProfileBloc>(
                  create: (_) => PublicProfileBloc(),
                  child: PublicProfileScreen(uid: widget.post['uid']),
                ),
              ),
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
                    MaterialPageRoute(
                      builder: (_) => BlocProvider<PublicProfileBloc>(
                        create: (_) => PublicProfileBloc(),
                        child: PublicProfileScreen(uid: widget.post['uid']),
                      ),
                    ),
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
                    _locationName,
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

  Widget _buildMapSnapshot(List<LatLng> googlePoints) {
    if (googlePoints.isEmpty) return const SizedBox();

    final List<ll2.LatLng> ll2Points = googlePoints
        .map((p) => ll2.LatLng(p.latitude, p.longitude))
        .toList();

    // Hitung bounding box
    final bounds = LatLngBounds.fromPoints(ll2Points);

    // Pilih URL berdasarkan tema
    final isDark = AppTheme.isDarkMode;
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 0.5),
          bottom: BorderSide(color: AppTheme.border, width: 0.5),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer( // Kunci interaksi map agar seperti image
              child: FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.all(24.0),
                  ),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none, // Matikan scroll/zoom
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: tileUrl,
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.tubes.apb',
                    retinaMode: true, // <-- Memuat ubin resolusi tinggi (@2x) untuk layar HD
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: ll2Points,
                        strokeWidth: 4.0,
                        color: AppTheme.accent,
                        strokeJoin: StrokeJoin.round,
                        strokeCap: StrokeCap.round,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.1),
                  ],
                  stops: const [0.0, 0.2, 0.8, 1.0],
                ),
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

  Widget _buildCustomPaintRoute(List<LatLng> routePoints) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: MiniRoutePainter(routePoints),
      ),
    );
  }

  Widget _buildSocialFooter() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spaceSM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_likesCount > 0)
            Padding(
              padding: EdgeInsets.fromLTRB(context.spaceMD, context.spaceSM, context.spaceMD, 0),
              child: Text(
                '$_likesCount Likes',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: context.fontSM,
                    fontWeight: FontWeight.bold),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Like
              _socialButton(
                icon: _isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                label: 'Like',
                color: _isLiked ? AppTheme.accent : AppTheme.textSecondary,
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
          SizedBox(height: context.spaceXS),
        ],
      ),
    );
  }

  Widget _socialButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.radiusSM),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.spaceSM),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: context.iconMD * 0.9, color: color),
              SizedBox(width: context.spaceXS),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(color: color, fontSize: context.fontSM, fontWeight: FontWeight.w600),
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
}
