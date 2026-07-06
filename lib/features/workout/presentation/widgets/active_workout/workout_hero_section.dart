import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../theme/app_theme.dart';
import '../../../bloc/active_workout/active_workout_bloc.dart';
import '../../../bloc/active_workout/active_workout_state.dart';

class WorkoutHeroSection extends StatelessWidget {
  final PageController pageController;

  const WorkoutHeroSection({
    super.key,
    required this.pageController,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveWorkoutBloc, ActiveWorkoutState>(
      builder: (context, state) {
        final screenHeight = MediaQuery.of(context).size.height;
        final imageHeight = screenHeight * 0.4;

        if (state.exercises.isEmpty) return const SizedBox();

        return SizedBox(
          height: imageHeight + 160,
          child: PageView.builder(
            controller: pageController,
            physics: const NeverScrollableScrollPhysics(), // Managed by BLoC now, not swipeable
            itemCount: state.exercises.length,
            itemBuilder: (context, index) {
              final ex = state.exercises[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      height: imageHeight,
                      width: double.infinity,
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.electricBlue.withValues(alpha: 0.12),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ex.gifPath != null
                          ? Image.asset(
                              ex.gifPath!,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Center(
                              child: Icon(
                                ex.icon,
                                size: 80,
                                color: AppTheme.accent.withValues(alpha: 0.5),
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      ex.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        ex.muscleGroups.join(', '),
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
