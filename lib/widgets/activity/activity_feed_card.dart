import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/workout.dart';
import '../../theme/app_theme.dart';
import '../../screens/workout_detail_screen.dart';
import '../mini_route_painter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Activity feed card ala Strava. Bisa dipakai di halaman Aktivitas Pribadi maupun Aktivitas Teman.
class ActivityFeedCard extends StatefulWidget {
  final Workout workout;
  final String userName;
  final String? userPhotoUrl;

  /// Callback opsional untuk refresh halaman setelah navigasi kembali
  final VoidCallback? onRefresh;

  const ActivityFeedCard({
    super.key,
    required this.workout,
    required this.userName,
    this.userPhotoUrl,
    this.onRefresh,
  });

  @override
  State<ActivityFeedCard> createState() => _ActivityFeedCardState();
}

class _ActivityFeedCardState extends State<ActivityFeedCard> {
  bool _isLiked = false;
  int _likesCount = 0;
  String _locationName = 'Mencari lokasi...';

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    final workout = widget.workout;
    if (workout.polyline != null && workout.polyline!.isNotEmpty) {
      final routePoints = MiniRoutePainter.parsePolyline(workout.polyline!);
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
  Widget build(BuildContext context) {
    final workout = widget.workout;
    final routePoints = workout.polyline != null && workout.polyline!.isNotEmpty
        ? MiniRoutePainter.parsePolyline(workout.polyline!)
        : <dynamic>[];

    final hasRoute = routePoints.isNotEmpty;

    return Dismissible(
      key: Key('feed_${workout.id ?? UniqueKey().toString()}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: Text('Hapus Aktivitas?', style: TextStyle(color: AppTheme.textPrimary)),
            content: const Text('Aktivitas ini akan dihapus secara permanen.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) {},
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(
            top: BorderSide(color: AppTheme.border, width: 0.5),
            bottom: BorderSide(color: AppTheme.border, width: 0.5),
          ),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(workout),
                    const SizedBox(height: 12),

                    // ── JUDUL AKTIVITAS ─────────────────────────────────────
                    Text(
                      workout.title ?? _defaultTitle(workout),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── 3 KOLOM METRIK ──────────────────────────────────────
                    if (workout.type == 'running' || workout.type == 'walking')
                      _buildRunMetrics(workout)
                    else
                      _buildStrengthMetrics(workout),

                    const SizedBox(height: 14),
                  ],
                ),
              ),

              // ── CHALLENGE / ENCOURAGEMENT BANNER ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.thumb_up_rounded, color: AppTheme.accent, size: 28),
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
                      backgroundColor: AppTheme.accent,
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
            if (hasRoute) _buildMapSnapshot(routePoints.cast()),
            if (!hasRoute)
              Container(
                height: 8,
                color: AppTheme.surfaceVariant,
              ),

              // ── FOOTER: INTERAKSI SOSIAL ─────────────────────────────────
              _buildSocialFooter(),
            ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkoutDetailScreen(workout: widget.workout)),
    ).then((_) => widget.onRefresh?.call());
  }

  Widget _buildHeader(Workout workout) {
    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.surfaceVariant,
          backgroundImage: _buildAvatarImage(),
          child: _buildAvatarImage() == null
              ? Text(
                  widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'A',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.userName.isNotEmpty ? widget.userName : 'Atlet',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                '${DateFormat('MMMM d, yyyy').format(workout.date)} at ${DateFormat('h:mm a').format(workout.date)} • Kora App',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    workout.type == 'running' ? Icons.directions_run_rounded : Icons.fitness_center_rounded,
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
        // More options button
        IconButton(
          icon: Icon(Icons.more_horiz, color: AppTheme.textSecondary),
          onPressed: () => _showMoreOptions(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildRunMetrics(Workout workout) {
    return Row(
      children: [
        _metricCell(
          label: 'Distance',
          value: workout.distance != null ? '${workout.distance!.toStringAsFixed(2)} km' : '—',
        ),
        _verticalDivider(),
        _metricCell(
          label: 'Pace',
          value: workout.distance != null && workout.distance! > 0
              ? '${_calcPace(workout)} /km'
              : '—',
        ),
        _verticalDivider(),
        _metricCell(
          label: 'Time',
          value: _formatDuration(workout.duration),
        ),
      ],
    );
  }

  Widget _buildStrengthMetrics(Workout workout) {
    return Row(
      children: [
        _metricCell(
          label: 'Sets',
          value: '${workout.sets ?? 0}',
        ),
        _verticalDivider(),
        _metricCell(
          label: 'Reps',
          value: '${workout.reps ?? 0}',
        ),
        _verticalDivider(),
        _metricCell(
          label: 'Time',
          value: _formatDuration(workout.duration),
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

  Widget _buildMapSnapshot(List<dynamic> routePoints) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.isDarkMode ? const Color(0xFF1A1F2E) : const Color(0xFFE8EDF5),
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 0.5),
          bottom: BorderSide(color: AppTheme.border, width: 0.5),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
              child: ClipRect(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: MiniRoutePainter(
                      routePoints.cast(),
                      routeColor: AppTheme.accent,
                    ),
                    child: Container(),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Text(
                '© OpenMapTiles © OpenStreetMap',
                style: TextStyle(
                  color: (AppTheme.isDarkMode ? Colors.white : Colors.black).withOpacity(0.4),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
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
                color: _isLiked ? AppTheme.accent : AppTheme.textSecondary,
                onTap: () => setState(() {
                  _isLiked = !_isLiked;
                  _likesCount += _isLiked ? 1 : -1;
                }),
              ),
              // Comment
              _socialButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Komentar',
                color: AppTheme.textSecondary,
                onTap: () {},
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

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit Judul'),
            onTap: () {
              Navigator.pop(context);
              _navigateToDetail();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Hapus Aktivitas', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  ImageProvider? _buildAvatarImage() {
    final url = widget.userPhotoUrl;
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
    return FileImage(File(url));
  }

  IconData _workoutTypeIcon(String type) {
    switch (type) {
      case 'running': return Icons.directions_run_rounded;
      case 'walking': return Icons.directions_walk_rounded;
      case 'weightlifting': return Icons.fitness_center_rounded;
      case 'basketball': return Icons.sports_basketball_rounded;
      default: return Icons.sports_rounded;
    }
  }

  String _defaultTitle(Workout w) {
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

  String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEEE').format(date);
    return DateFormat('d MMM yyyy').format(date);
  }

  String _calcPace(Workout w) {
    if (w.distance == null || w.distance == 0) return '0:00';
    final paceMins = w.duration / w.distance!;
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
