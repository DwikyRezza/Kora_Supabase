import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/workout.dart';
import '../../theme/app_theme.dart';

class WorkoutDetailHeader extends StatefulWidget {
  final Workout workout;
  final String userName;
  final String? userPhotoUrl;

  const WorkoutDetailHeader({
    super.key,
    required this.workout,
    required this.userName,
    this.userPhotoUrl,
  });

  @override
  State<WorkoutDetailHeader> createState() => _WorkoutDetailHeaderState();
}

class _WorkoutDetailHeaderState extends State<WorkoutDetailHeader> {
  bool _isLiked = false;
  int _likesCount = 377; // Dummy Strava Kudos Count matching visual spec

  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;

    final formattedDate = DateFormat('MMMM d, yyyy').format(workout.date) +
        ' at ' +
        DateFormat('h:mm a').format(workout.date) +
        ' • Central Java';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── BARIS 1: PROFIL ATLET ───────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.surfaceVariant,
                backgroundImage: _buildAvatarImage(),
                child: _buildAvatarImage() == null
                    ? Text(
                        widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'A',
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
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
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
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
                        Expanded(
                          child: Text(
                            formattedDate,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── BARIS 2: JUDUL AKTIVITAS ────────────────────────────────────
          Text(
            workout.title ?? (workout.type == 'running' ? 'Morning Run' : 'Workout'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "59 Training Load -- from COROS",
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          // ── BARIS 3: GRID METRIK UTAMA (3x2) ─────────────────────────────
          Table(
            children: [
              TableRow(
                children: [
                  _gridMetricCell('Distance', workout.distance != null ? '${workout.distance!.toStringAsFixed(2)} km' : '0.00 km'),
                  _gridMetricCell('Avg Pace', '${_calculatePace(workout)} /km'),
                  _gridMetricCell('Elevation Gain', '${(workout.elevationGain ?? 0.0).round()} m'),
                ],
              ),
              const TableRow(
                children: [
                  SizedBox(height: 16),
                  SizedBox(height: 16),
                  SizedBox(height: 16),
                ],
              ),
              TableRow(
                children: [
                  _gridMetricCell('Moving Time', _formatDuration(workout.duration)),
                  _gridMetricCell('Calories', '${workout.caloriesBurned} Cal'),
                  _gridMetricCell('Avg Heart Rate', '130 bpm'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── BARIS 4: INFO PERANGKAT & CUACA ──────────────────────────────
          Row(
            children: [
              Icon(Icons.watch_rounded, size: 20, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                'COROS NOMAD',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_queue_rounded, size: 20, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cloudy, 24 °C. Feels like 25 °C. Humidity 93%. Wind 3.2 km/h from WSW.',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── BARIS 5: SOCIAL BAR (KUDOS & IKON TOMBOL) ────────────────────
          Text(
            '$_likesCount gave kudos',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Divider(color: AppTheme.border, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _socialButton(
                  icon: _isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                  label: 'Like',
                  color: _isLiked ? const Color(0xFFFF5406) : AppTheme.textSecondary,
                  onTap: () {
                    setState(() {
                      _isLiked = !_isLiked;
                      _likesCount += _isLiked ? 1 : -1;
                    });
                  },
                ),
                _socialButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Komentar',
                  color: AppTheme.textSecondary,
                  onTap: () {},
                ),
                _socialButton(
                  icon: Icons.share_outlined,
                  label: 'Bagikan',
                  color: AppTheme.textSecondary,
                  onTap: () {},
                ),
              ],
            ),
          ),
          Divider(color: AppTheme.border, height: 1),
        ],
      ),
    );
  }

  Widget _gridMetricCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ],
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
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
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

  String _calculatePace(Workout w) {
    if (w.distance == null || w.distance == 0) return '0:00';
    final paceMins = w.duration / w.distance!;
    final m = paceMins.truncate();
    final s = ((paceMins - m) * 60).truncate().toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDuration(double mins) {
    final int totalSeconds = (mins * 60).round();
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    if (hours > 0) {
      return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    } else {
      return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    }
  }
}
