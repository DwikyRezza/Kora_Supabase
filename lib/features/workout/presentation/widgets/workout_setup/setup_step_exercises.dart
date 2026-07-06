import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../models/exercise_definition.dart';
import '../../../bloc/workout_setup/workout_setup_bloc.dart';
import '../../../bloc/workout_setup/workout_setup_event.dart';
import '../../../bloc/workout_setup/workout_setup_state.dart';

class SetupStepExercises extends StatelessWidget {
  const SetupStepExercises({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutSetupBloc, WorkoutSetupState>(
      builder: (context, state) {
        final filtered = exerciseDatabase.where((e) {
          if (state.selectedMode != null && e.category != state.selectedMode) {
            return false;
          }

          if (state.selectedMuscles.isNotEmpty) {
            bool match = false;
            for (var m in e.muscleGroups) {
              if (state.selectedMuscles.contains(m)) match = true;
            }
            if (!match) return false;
          }

          if (state.searchQuery.isNotEmpty) {
            if (!e.name
                .toLowerCase()
                .contains(state.searchQuery.toLowerCase())) {
              return false;
            }
          }
          return true;
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tahap 3: Kurasi Gerakan',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 8),
              Text('Pilih gerakanmu',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Text(
                  'Rekomendasi berdasarkan otot yang dipilih. Pilih yang ingin dilakukan.',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14)),
              const SizedBox(height: 16),
              TextField(
                onChanged: (val) {
                  context
                      .read<WorkoutSetupBloc>()
                      .add(WorkoutSetupSearchQueryChanged(val));
                },
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Cari gerakan (mis: Push up)...',
                  hintStyle: TextStyle(color: AppTheme.textMuted),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppTheme.accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('Tidak ada gerakan yang sesuai kriteria.',
                            style: TextStyle(color: AppTheme.textMuted)))
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final ex = filtered[i];
                          final isSelected =
                              state.selectedExerciseIds.contains(ex.id);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (val) {
                              context
                                  .read<WorkoutSetupBloc>()
                                  .add(WorkoutSetupExerciseToggled(ex.id));
                            },
                            title: Text(ex.name,
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '${ex.difficulty} • ${ex.muscleGroups.join(', ')}',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                            secondary: Icon(ex.icon, color: AppTheme.textMuted),
                            activeColor: AppTheme.accent,
                            checkColor: Colors.white,
                            tileColor: AppTheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                  color: isSelected
                                      ? AppTheme.accent
                                      : AppTheme.border),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
