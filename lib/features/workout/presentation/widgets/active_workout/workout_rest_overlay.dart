import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../theme/app_theme.dart';
import '../../../bloc/active_workout/active_workout_bloc.dart';
import '../../../bloc/active_workout/active_workout_event.dart';
import '../../../bloc/active_workout/active_workout_state.dart';

class WorkoutRestOverlay extends StatelessWidget {
  const WorkoutRestOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveWorkoutBloc, ActiveWorkoutState>(
      builder: (context, state) {
        if (!state.isResting) return const SizedBox();

        final nextIndex = state.currentSet >= state.totalSetsPerExercise
            ? state.currentExerciseIndex + 1
            : state.currentExerciseIndex;
        final nextExerciseName = nextIndex < state.exercises.length
            ? state.exercises[nextIndex].name
            : null;

        final mins = (state.restRemaining ~/ 60).toString().padLeft(2, '0');
        final secs = (state.restRemaining % 60).toString().padLeft(2, '0');

        return Positioned.fill(
          child: Scaffold(
            backgroundColor: AppTheme.isDarkMode ? Colors.black : Colors.white,
            body: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('RECOVERY',
                      style: TextStyle(
                          color: AppTheme.neonGreen,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.0)),
                  const SizedBox(height: 16),
                  if (nextExerciseName != null &&
                      state.currentSet >= state.totalSetsPerExercise)
                    Text(
                        'Set ${state.currentSet} Selesai\nBersiap untuk $nextExerciseName',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            height: 1.4))
                  else
                    Text(
                        'Set ${state.currentSet - 1} Selesai\nBersiap untuk Set ${state.currentSet}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            height: 1.4)),
                  const SizedBox(height: 60),
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 240,
                          height: 240,
                          child: CircularProgressIndicator(
                            value: state.restRemaining / 60.0, // Assuming max 60s
                            strokeWidth: 4,
                            color: AppTheme.neonGreen,
                            backgroundColor: AppTheme.border.withValues(alpha: 0.3),
                          ),
                        ),
                        Text(
                          '$mins:$secs',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 64,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            fontFeatures: const [FontFeature.tabularFigures()],
                            shadows: [
                              Shadow(
                                color: Colors.white.withValues(alpha: AppTheme.isDarkMode ? 0.15 : 0.7),
                                offset: const Offset(0, -1),
                                blurRadius: 0,
                              ),
                              Shadow(
                                color: Colors.black.withValues(alpha: AppTheme.isDarkMode ? 0.9 : 0.3),
                                offset: const Offset(0, 3),
                                blurRadius: 0,
                              ),
                              Shadow(
                                color: Colors.black.withValues(alpha: AppTheme.isDarkMode ? 0.4 : 0.1),
                                offset: const Offset(0, 5),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          // Note: In BLoC we can dispatch SkipRest event
                          context.read<ActiveWorkoutBloc>().add(ActiveWorkoutSkipRest());
                        },
                        icon: Icon(Icons.skip_next_rounded, size: 20),
                        label: Text('Skip Rest',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          side: BorderSide(color: AppTheme.border, width: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
