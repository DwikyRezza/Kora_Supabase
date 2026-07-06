import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../theme/app_theme.dart';
import '../../../bloc/workout_setup/workout_setup_bloc.dart';
import '../../../bloc/workout_setup/workout_setup_event.dart';
import '../../../bloc/workout_setup/workout_setup_state.dart';

class SetupStepMuscles extends StatelessWidget {
  const SetupStepMuscles({super.key});

  static const Map<String, List<String>> _muscleCategories = {
    'Dada (Chest)': ['Dada'],
    'Lengan & Bahu': [
      'Bicep',
      'Tricep',
      'Forearm',
      'Bahu Depan',
      'Bahu Samping',
      'Bahu Belakang'
    ],
    'Kaki (Legs)': [
      'Paha Depan',
      'Paha Belakang',
      'Paha Samping',
      'Paha Dalam',
      'Pantat',
      'Betis'
    ],
    'Punggung & Perut': [
      'Punggung Atas',
      'Punggung Samping',
      'Punggung Bawah',
      'Perut Depan',
      'Perut Samping'
    ],
  };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutSetupBloc, WorkoutSetupState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tahap 2: Pemetaan Otot',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 8),
              Text('Otot apa yang ingin dilatih?',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Text('Pilih area otot spesifik untuk menyusun rutinitas.',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: _muscleCategories.entries.map((entry) {
                    final categoryName = entry.key;
                    final muscles = entry.value;
                    final selectedCount = muscles
                        .where((m) => state.selectedMuscles.contains(m))
                        .length;
                    final isCategoryActive = selectedCount > 0;

                    return Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isCategoryActive
                              ? AppTheme.accent.withValues(alpha: 0.05)
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isCategoryActive
                                  ? AppTheme.accent.withValues(alpha: 0.5)
                                  : AppTheme.border),
                        ),
                        child: ExpansionTile(
                          title: Text(
                            categoryName,
                            style: TextStyle(
                              color: isCategoryActive
                                  ? AppTheme.accent
                                  : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: selectedCount > 0
                              ? Text('$selectedCount otot dipilih',
                                  style: TextStyle(
                                      color: AppTheme.accent, fontSize: 12))
                              : null,
                          iconColor: AppTheme.accent,
                          collapsedIconColor: AppTheme.textSecondary,
                          childrenPadding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.start,
                              children: muscles.map((m) {
                                final isSelected =
                                    state.selectedMuscles.contains(m);
                                return FilterChip(
                                  label: Text(m),
                                  selected: isSelected,
                                  onSelected: (val) {
                                    context
                                        .read<WorkoutSetupBloc>()
                                        .add(WorkoutSetupMuscleToggled(m));
                                  },
                                  backgroundColor: AppTheme.background,
                                  selectedColor:
                                      AppTheme.accent.withValues(alpha: 0.2),
                                  checkmarkColor: AppTheme.accent,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? AppTheme.accent
                                        : AppTheme.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                        color: isSelected
                                            ? AppTheme.accent
                                            : AppTheme.border),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
