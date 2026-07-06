import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../models/exercise_definition.dart';
import '../../../bloc/workout_setup/workout_setup_bloc.dart';
import '../../../bloc/workout_setup/workout_setup_event.dart';
import '../../../bloc/workout_setup/workout_setup_state.dart';

class SetupStepSummary extends StatelessWidget {
  const SetupStepSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutSetupBloc, WorkoutSetupState>(
      builder: (context, state) {
        int totalSets = 0;
        for (var id in state.selectedExerciseIds) {
          totalSets += state.exerciseSets[id] ?? 4;
        }
        final estimatedMins = totalSets * 1;
        final estimatedCalories = estimatedMins * 8;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tahap Final',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 8),
              Text('Today\'s Routine',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        color: AppTheme.accent, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Estimasi Sesi',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                          const SizedBox(height: 4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('~$estimatedMins Menit',
                                  style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 12),
                              Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                      color: AppTheme.textMuted,
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 12),
                              Text('~$estimatedCalories kkal',
                                  style: TextStyle(
                                      color: AppTheme.accent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Daftar Gerakan (${state.selectedExerciseIds.length})',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 12),
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    canvasColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  child: ReorderableListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: state.selectedExerciseIds.length,
                    proxyDecorator:
                        (Widget child, int index, Animation<double> animation) {
                      return Material(
                        elevation: 12,
                        color: Colors.transparent,
                        shadowColor: AppTheme.accent.withValues(alpha: 0.5),
                        child: Container(
                          decoration: BoxDecoration(
                              color: AppTheme.surfaceVariant
                                  .withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppTheme.accent, width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color:
                                        AppTheme.accent.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    spreadRadius: 2),
                              ]),
                          child: child,
                        ),
                      );
                    },
                    onReorderStart: (_) => HapticFeedback.mediumImpact(),
                    onReorder: (oldIndex, newIndex) {
                      HapticFeedback.lightImpact();
                      context
                          .read<WorkoutSetupBloc>()
                          .add(WorkoutSetupExerciseReordered(oldIndex, newIndex));
                    },
                    itemBuilder: (ctx, i) {
                      final exId = state.selectedExerciseIds[i];
                      final ex =
                          exerciseDatabase.firstWhere((e) => e.id == exId);
                      return _ExerciseSetupTile(
                        key: ValueKey(exId),
                        index: i,
                        ex: ex,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExerciseSetupTile extends StatelessWidget {
  final int index;
  final ExerciseDefinition ex;

  const _ExerciseSetupTile({super.key, required this.index, required this.ex});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutSetupBloc, WorkoutSetupState>(
      builder: (context, state) {
        final currentSets = state.exerciseSets[ex.id] ?? 4;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text('${index + 1}.',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(ex.icon, color: AppTheme.accent, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.name,
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(ex.muscleGroups.join(', '),
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (currentSets > 1) {
                            context.read<WorkoutSetupBloc>().add(
                                WorkoutSetupExerciseSetsChanged(
                                    ex.id, currentSets - 1));
                          }
                        },
                        child: Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Icon(Icons.remove,
                              color: AppTheme.textPrimary, size: 16),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _showSetEditDialog(context, ex.id, currentSets);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          child: Text('$currentSets',
                              style: TextStyle(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (currentSets < 99) {
                            context.read<WorkoutSetupBloc>().add(
                                WorkoutSetupExerciseSetsChanged(
                                    ex.id, currentSets + 1));
                          }
                        },
                        child: Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Icon(Icons.add,
                              color: AppTheme.textPrimary, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.drag_handle_rounded,
                        color: AppTheme.textMuted, size: 28),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSetEditDialog(BuildContext context, String exId, int currentSets) {
    final ctrl = TextEditingController(text: '$currentSets');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title:
            Text('Atur Jumlah Set', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.accent, width: 2)),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal',
                  style: TextStyle(color: Colors.white70))),
          TextButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text);
              if (val != null && val > 0 && val < 100) {
                context
                    .read<WorkoutSetupBloc>()
                    .add(WorkoutSetupExerciseSetsChanged(exId, val));
              }
              Navigator.pop(ctx);
            },
            child: Text('Simpan',
                style: TextStyle(
                    color: AppTheme.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
