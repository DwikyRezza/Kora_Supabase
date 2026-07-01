import 'package:flutter/material.dart';
import '../../models/workout.dart';
import '../../theme/app_theme.dart';

class WorkoutPaceZones extends StatelessWidget {
  final Workout workout;

  const WorkoutPaceZones({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    final double workoutDistance = workout.distance ?? 0.0;
    final double avgPaceMins = workoutDistance > 0 ? (workout.duration / workoutDistance) : 0.0;
    final zones = _generatePaceZones(avgPaceMins);

    final zLabels = ['Z6', 'Z5', 'Z4', 'Z3', 'Z2', 'Z1'];
    final zColors = [
      AppTheme.accent,
      const Color(0xFFFF9966),
      const Color(0xFF4DCC60),
      AppTheme.accent,
      const Color(0xFF006623),
      Colors.black87,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: List.generate(6, (i) {
            final key = zLabels[i];
            final val = zones[key] ?? 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 28, child: Text(key, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: val / 100,
                        minHeight: 12,
                        backgroundColor: AppTheme.border,
                        valueColor: AlwaysStoppedAnimation<Color>(zColors[i]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 36, child: Text('${val.round()}%', textAlign: TextAlign.right, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13))),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Map<String, double> _generatePaceZones(double avgPace) {
    double z1 = 0, z2 = 0, z3 = 0, z4 = 0, z5 = 0, z6 = 0;
    if (avgPace >= 5.5) {
      z1 = 92; z2 = 7; z3 = 1;
    } else if (avgPace >= 4.7) {
      z1 = 18; z2 = 64; z3 = 15; z4 = 3;
    } else if (avgPace >= 4.2) {
      z2 = 12; z3 = 62; z4 = 21; z5 = 5;
    } else {
      z3 = 8; z4 = 38; z5 = 44; z6 = 10;
    }
    return {'Z1': z1, 'Z2': z2, 'Z3': z3, 'Z4': z4, 'Z5': z5, 'Z6': z6};
  }
}
