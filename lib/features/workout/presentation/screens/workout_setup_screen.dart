import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/exercise_definition.dart';
import '../widgets/workout_setup/setup_step_mode.dart';
import '../widgets/workout_setup/setup_step_muscles.dart';
import '../widgets/workout_setup/setup_step_exercises.dart';
import '../widgets/workout_setup/setup_step_summary.dart';
import '../../bloc/workout_setup/workout_setup_bloc.dart';
import '../../bloc/workout_setup/workout_setup_event.dart';
import '../../bloc/workout_setup/workout_setup_state.dart';
import 'active_workout_screen.dart';

class WorkoutSetupScreen extends StatefulWidget {
  final double userWeight;

  const WorkoutSetupScreen({super.key, required this.userWeight});

  @override
  State<WorkoutSetupScreen> createState() => _WorkoutSetupScreenState();
}

class _WorkoutSetupScreenState extends State<WorkoutSetupScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _syncPageController(int pageIndex) {
    if (_pageController.hasClients &&
        _pageController.page?.round() != pageIndex) {
      _pageController.animateToPage(
        pageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WorkoutSetupBloc(),
      child: BlocConsumer<WorkoutSetupBloc, WorkoutSetupState>(
        listenWhen: (previous, current) => previous.currentPage != current.currentPage,
        listener: (context, state) {
          _syncPageController(state.currentPage);
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: AppTheme.background,
            appBar: AppBar(
              backgroundColor: AppTheme.background,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    color: AppTheme.textPrimary),
                onPressed: () {
                  if (state.currentPage > 0) {
                    context
                        .read<WorkoutSetupBloc>()
                        .add(WorkoutSetupPrevPageRequested());
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              title: _buildProgressIndicators(state.currentPage),
              centerTitle: true,
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (idx) {
                        context
                            .read<WorkoutSetupBloc>()
                            .add(WorkoutSetupPageChanged(idx));
                      },
                      children: const [
                        SetupStepMode(),
                        SetupStepMuscles(),
                        SetupStepExercises(),
                        SetupStepSummary(),
                      ],
                    ),
                  ),
                  _buildBottomBar(context, state),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressIndicators(int currentPage) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final isActive = index == currentPage;
        final isDone = index < currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: isActive ? 24 : 12,
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.accent
                : (isDone
                    ? AppTheme.accent.withValues(alpha: 0.5)
                    : AppTheme.border),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildBottomBar(BuildContext context, WorkoutSetupState state) {
    final canProceed = state.canProceedToNext;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        decoration: state.currentPage == 3
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              )
            : null,
        child: ElevatedButton(
          onPressed: canProceed
              ? () {
                  if (state.currentPage < 3) {
                    context
                        .read<WorkoutSetupBloc>()
                        .add(WorkoutSetupNextPageRequested());
                  } else {
                    // Start workout
                    final selectedExercises = state.selectedExerciseIds
                        .map((id) => exerciseDatabase
                            .firstWhere((e) => e.id == id))
                        .toList();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActiveWorkoutScreen(
                          exercises: selectedExercises,
                          userWeight: widget.userWeight,
                          exerciseSets: state.exerciseSets,
                        ),
                      ),
                    );
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                AppTheme.surfaceVariant.withValues(alpha: 0.6),
            disabledForegroundColor: AppTheme.textMuted,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            state.currentPage == 3 ? 'MULAI LATIHAN' : 'LANJUTKAN',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
        ),
      ),
    );
  }
}
