import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../theme/app_theme.dart';
import '../../../bloc/workout_setup/workout_setup_bloc.dart';
import '../../../bloc/workout_setup/workout_setup_event.dart';
import '../../../bloc/workout_setup/workout_setup_state.dart';

class SetupStepMode extends StatelessWidget {
  const SetupStepMode({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutSetupBloc, WorkoutSetupState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tahap 1: Mode Latihan',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 8),
              Text('Pilih gaya latihanmu',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Text(
                  'Ini akan menyesuaikan jenis gerakan yang akan disarankan.',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14)),
              const SizedBox(height: 32),
              _ModeCard(
                mode: 'bodyweight',
                title: 'Bodyweight Mode',
                subtitle: 'Fokus pada kalistenik & ketahanan tubuh tanpa alat',
                icon: Icons.accessibility_new_rounded,
                isSelected: state.selectedMode == 'bodyweight',
              ),
              const SizedBox(height: 16),
              _ModeCard(
                mode: 'weighted',
                title: 'Weighted Mode',
                subtitle: 'Fokus hipertrofi dengan dumbbell atau barbell',
                icon: Icons.fitness_center_rounded,
                isSelected: state.selectedMode == 'weighted',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String mode;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;

  const _ModeCard({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<WorkoutSetupBloc>().add(WorkoutSetupModeSelected(mode));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.15)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? AppTheme.accent : AppTheme.border,
              width: isSelected ? 3 : 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accent : AppTheme.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
