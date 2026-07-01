import 'package:flutter/material.dart';
import '../../models/workout.dart';
import '../../theme/app_theme.dart';

class WorkoutPerformanceMetrics extends StatelessWidget {
  final Workout workout;

  const WorkoutPerformanceMetrics({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    final speedLabel = workout.type == 'running' ? 'Avg Pace' : 'Total Reps';
    final speedVal = workout.type == 'running' ? _calculatePace() : '${workout.reps ?? 0}';

    final elevGainVal = '${(workout.elevationGain ?? 0).round()} m';
    final heartRateVal = workout.type == 'running' ? '146 bpm' : '${workout.sets ?? 0} sets';
    final hrLabel = workout.type == 'running' ? 'Avg Heart Rate' : 'Total Set';

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
                Expanded(child: _metricCell('Distance', '${(workout.distance ?? 0.0).toStringAsFixed(2)} km')),
                Expanded(child: _metricCell(speedLabel, speedVal)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _metricCell('Moving Time', _formatDuration(workout.duration))),
                Expanded(child: _metricCell('Elevation Gain', elevGainVal)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _metricCell('Calories', '${workout.caloriesBurned} Cal')),
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
        Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
      ],
    );
  }

  String _calculatePace() {
    if (workout.distance == null || workout.distance == 0) return '0:00';
    final paceMins = workout.duration / workout.distance!;
    final m = paceMins.truncate();
    final s = ((paceMins - m) * 60).truncate().toString().padLeft(2, '0');
    return '$m:$s /km';
  }

  String _formatDuration(double mins) {
    final h = (mins / 60).truncate();
    final m = mins.truncate() % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
