import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/workout.dart';
import '../../theme/app_theme.dart';

class WorkoutSplitsTable extends StatelessWidget {
  final Workout workout;

  const WorkoutSplitsTable({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    List<String> splits = [];
    if (workout.splitsStr != null && workout.splitsStr!.isNotEmpty) {
      try {
        splits = List<String>.from(jsonDecode(workout.splitsStr!));
      } catch (e) {
        // ignore
      }
    }

    final finalSplits = splits.isNotEmpty ? splits : _generateSplitsList();
    if (finalSplits.isEmpty) return const SizedBox.shrink();

    // Find fastest pace to calculate relative widths
    double fastestMins = double.maxFinite;
    final List<double> splitMinsList = [];
    for (final s in finalSplits) {
      try {
        final parts = s.split(':');
        final mins = double.parse(parts[0]) + (double.parse(parts[1]) / 60);
        splitMinsList.add(mins);
        if (mins < fastestMins) {
          fastestMins = mins;
        }
      } catch (_) {
        splitMinsList.add(7.0);
      }
    }
    if (fastestMins == 0) fastestMins = 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table Header Labels
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text('Lap', style: _headerStyle())),
                  Expanded(flex: 3, child: Text('Pace', style: _headerStyle())),
                  Expanded(flex: 5, child: Text('Split Progress', style: _headerStyle())),
                  Expanded(flex: 3, child: Text('Elev', style: _headerStyle(), textAlign: TextAlign.center)),
                  Expanded(flex: 3, child: Text('HR', style: _headerStyle(), textAlign: TextAlign.right)),
                ],
              ),
            ),
            Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: finalSplits.length,
              itemBuilder: (context, i) {
                final paceVal = finalSplits[i];
                final double currentMins = splitMinsList[i];
                // Relative progress (fastest pace gets 1.0, slower pace gets less)
                final double progress = (fastestMins / currentMins).clamp(0.1, 1.0);

                // Elevation change dummy (+/-)
                final int elevDiff = (i % 3 - 1) * 3;
                final String elevSign = elevDiff >= 0 ? "+$elevDiff" : "$elevDiff";

                // Avg Heart Rate dummy
                final int avgHr = 142 + (i % 4 - 2) * 4;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      // Nomor KM
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      // Waktu Pace
                      Expanded(
                        flex: 3,
                        child: Text(
                          paceVal,
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      // Split progress horizontal bar
                      Expanded(
                        flex: 5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: AppTheme.border,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                          ),
                        ),
                      ),
                      // Selisih Elevasi
                      Expanded(
                        flex: 3,
                        child: Text(
                          "${elevSign}m",
                          style: TextStyle(
                            color: elevDiff >= 0 ? Colors.green : Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Avg Heart Rate
                      Expanded(
                        flex: 3,
                        child: Text(
                          "$avgHr bpm",
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _headerStyle() {
    return TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.bold,
    );
  }

  List<String> _generateSplitsList() {
    final double dist = workout.distance ?? 3.0;
    final int count = dist.ceil();
    final double avgP = workout.duration / (dist > 0 ? dist : 1.0);
    return List.generate(count, (i) {
      final p = avgP + (i % 3 - 1) * 0.2;
      final m = p.truncate();
      final s = ((p - m) * 60).round().toString().padLeft(2, '0');
      return '$m:$s';
    });
  }
}
