import 'package:flutter/material.dart';
import '../../models/workout.dart';
import '../../theme/app_theme.dart';

class WorkoutBestEfforts extends StatelessWidget {
  final Workout workout;

  const WorkoutBestEfforts({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    final double workoutDistance = workout.distance ?? 0.0;
    final double avgPaceMins = workoutDistance > 0 ? (workout.duration / workoutDistance) : 0.0;
    final efforts = _generateBestEfforts(avgPaceMins);

    if (efforts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: efforts.entries.map((e) {
            return ListTile(
              leading: Icon(Icons.flash_on_rounded, color: AppTheme.accent, size: 20),
              title: Text(e.key, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              trailing: Text(e.value, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Map<String, String> _generateBestEfforts(double avgPace) {
    String formatTime(double mins) {
      final m = mins.truncate();
      final s = ((mins - m) * 60).round().toString().padLeft(2, '0');
      return '$m:$s';
    }

    final efforts = <String, String>{};
    if (workout.distance != null && workout.distance! >= 0.4) {
      efforts['400m'] = formatTime(avgPace * 0.4 * 0.86);
    }
    if (workout.distance != null && workout.distance! >= 0.8) {
      efforts['1/2 mile'] = formatTime(avgPace * 0.8 * 0.90);
    }
    if (workout.distance != null && workout.distance! >= 1.0) {
      efforts['1K'] = formatTime(avgPace * 1.0 * 0.94);
    }
    if (workout.distance != null && workout.distance! >= 1.609) {
      efforts['1 mile'] = formatTime(avgPace * 1.609 * 0.97);
    }
    if (workout.distance != null && workout.distance! >= 3.218) {
      efforts['2 mile'] = formatTime(avgPace * 3.218 * 1.0);
    }
    return efforts;
  }
}
