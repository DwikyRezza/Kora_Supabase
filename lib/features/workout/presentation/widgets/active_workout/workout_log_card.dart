import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../theme/app_theme.dart';
import '../../../bloc/active_workout/active_workout_bloc.dart';
import '../../../bloc/active_workout/active_workout_event.dart';
import '../../../bloc/active_workout/active_workout_state.dart';

class WorkoutLogCard extends StatefulWidget {
  const WorkoutLogCard({super.key});

  @override
  State<WorkoutLogCard> createState() => _WorkoutLogCardState();
}

class _WorkoutLogCardState extends State<WorkoutLogCard> {
  int _reps = 10;
  late TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: '20');
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  void _changeReps(int change) {
    setState(() {
      _reps = (_reps + change).clamp(1, 100);
    });
  }

  void _logSet(BuildContext context, ActiveWorkoutState state) {
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    context.read<ActiveWorkoutBloc>().add(ActiveWorkoutLogSet(_reps, weight));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveWorkoutBloc, ActiveWorkoutState>(
      builder: (context, state) {
        if (state.exercises.isEmpty) return const SizedBox();

        final logs = state.allLogs.isNotEmpty ? state.allLogs[state.currentExerciseIndex] : [];
        int targetReps = logs.isNotEmpty ? logs.last.reps : 12;

        final isLastSet = state.currentSet >= state.totalSetsPerExercise;
        final isLastExercise = state.currentExerciseIndex >= state.exercises.length - 1;
        final isFinishing = isLastSet && isLastExercise;

        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
                  ),
                  child: Column(
                    children: [
                      Text('Target: $targetReps Reps',
                          style: TextStyle(
                              color: AppTheme.electricBlue,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _stepperButton(Icons.remove_rounded, () => _changeReps(-1)),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 100,
                            child: Text(
                              '$_reps',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 56,
                                fontWeight: FontWeight.w900,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          _stepperButton(Icons.add_rounded, () => _changeReps(1)),
                        ],
                      ),
                      if (state.isWeightlifting) ...[
                        const SizedBox(height: 20),
                        Divider(color: AppTheme.border),
                        const SizedBox(height: 16),
                        Text('BEBAN (kg)',
                            style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.fitness_center_rounded,
                                color: AppTheme.electricBlue, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _weightController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: '0',
                                  hintStyle: TextStyle(color: AppTheme.textMuted),
                                  suffixText: 'kg',
                                  suffixStyle: TextStyle(
                                      color: AppTheme.textSecondary, fontSize: 16),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: AppTheme.electricBlue, width: 2)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: AppTheme.border)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _logSet(context, state),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 62,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isFinishing
                        ? [AppTheme.neonGreen, const Color(0xFF00CC6A)]
                        : [AppTheme.accent, const Color(0xFFFF7A3D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: (isFinishing ? AppTheme.neonGreen : AppTheme.electricBlue).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isFinishing ? Icons.flag_rounded : Icons.check_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        isFinishing ? 'SELESAI LATIHAN' : 'SELESAI SET ${state.currentSet}',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 28),
      ),
    );
  }
}
