import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../models/exercise_definition.dart';
import '../../../../screens/workout_summary_screen.dart'; // We can refactor summary later
import '../../bloc/active_workout/active_workout_bloc.dart';
import '../../bloc/active_workout/active_workout_event.dart';
import '../../bloc/active_workout/active_workout_state.dart';

import '../widgets/active_workout/workout_header.dart';
import '../widgets/active_workout/workout_hero_section.dart';
import '../widgets/active_workout/workout_log_card.dart';
import '../widgets/active_workout/workout_rest_overlay.dart';

class ActiveWorkoutScreen extends StatelessWidget {
  final List<ExerciseDefinition> exercises;
  final double userWeight;
  final Map<String, int> exerciseSets;

  const ActiveWorkoutScreen({
    super.key,
    required this.exercises,
    required this.userWeight,
    required this.exerciseSets,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ActiveWorkoutBloc()
        ..add(ActiveWorkoutInit(exercises, exerciseSets)),
      child: ActiveWorkoutView(userWeight: userWeight),
    );
  }
}

class ActiveWorkoutView extends StatefulWidget {
  final double userWeight;
  const ActiveWorkoutView({super.key, required this.userWeight});

  @override
  State<ActiveWorkoutView> createState() => _ActiveWorkoutViewState();
}

class _ActiveWorkoutViewState extends State<ActiveWorkoutView> {
  late PageController _heroPageController;

  @override
  void initState() {
    super.initState();
    _heroPageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _heroPageController.dispose();
    super.dispose();
  }

  void _showExitDialog(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Icon(Icons.warning_amber_rounded,
                color: AppTheme.accentRed, size: 48),
            const SizedBox(height: 16),
            Text('Yakin mau berhenti sekarang?',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Progress set ini akan hilang.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Lanjut Latihan',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // close sheet
                    Navigator.pop(context); // exit screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Keluar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ActiveWorkoutBloc, ActiveWorkoutState>(
      listenWhen: (previous, current) =>
          previous.isFinished != current.isFinished ||
          previous.currentExerciseIndex != current.currentExerciseIndex,
      listener: (context, state) {
        if (state.isFinished) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => WorkoutSummaryScreen(
                exercises: state.exercises,
                allLogs: state.allLogs,
                sessionSeconds: state.sessionSeconds,
                userWeight: widget.userWeight,
              ),
            ),
          );
        } else {
          // Animate PageView when exercise index changes
          if (_heroPageController.hasClients) {
            _heroPageController.animateToPage(
              state.currentExerciseIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    WorkoutHeader(onExit: () => _showExitDialog(context)),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            WorkoutHeroSection(pageController: _heroPageController),
                            const SizedBox(height: 24),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: WorkoutLogCard(),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const WorkoutRestOverlay(),
            ],
          ),
        );
      },
    );
  }
}
