import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../theme/app_theme.dart';
import '../../../../repositories/workout_repository.dart';
import '../../bloc/analytics_bloc.dart';
import '../../bloc/analytics_event.dart';
import '../../bloc/analytics_state.dart';
import '../widgets/calendar_section.dart';
import '../widgets/progress_section.dart';
import '../widgets/summary_section.dart';

class WeeklyReportScreen extends StatelessWidget {
  final bool embedMode;
  const WeeklyReportScreen({super.key, this.embedMode = false});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AnalyticsBloc(
        workoutRepository: context.read<WorkoutRepository>(),
      )..add(AnalyticsLoadData(DateTime.now(), 'all')),
      child: WeeklyReportView(embedMode: embedMode),
    );
  }
}

class WeeklyReportView extends StatefulWidget {
  final bool embedMode;
  const WeeklyReportView({super.key, this.embedMode = false});

  @override
  State<WeeklyReportView> createState() => _WeeklyReportViewState();
}

class _WeeklyReportViewState extends State<WeeklyReportView> {
  final ScreenshotController _screenshotController = ScreenshotController();

  void _shareReport() async {
    // Feature share implementation can be added here
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnalyticsBloc, AnalyticsState>(
      builder: (context, state) {
        final bodyWidget = state.isLoading
            ? Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ProgressSection(),
                    Divider(height: 1, thickness: 1, color: AppTheme.divider),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Screenshot(
                        controller: _screenshotController,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: Column(
                            children: [
                              const SummarySection(),
                              const SizedBox(height: 24),
                              CalendarSection(
                                currentMonth: state.currentMonth,
                                workoutDays: state.workoutDaysMonth,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              );

        if (widget.embedMode) {
          return bodyWidget;
        }

        return Scaffold(
          backgroundColor: AppTheme.surface,
          appBar: AppBar(
            backgroundColor: AppTheme.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Aktivitas Latihan',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.ios_share_rounded, color: AppTheme.textPrimary, size: 22),
                onPressed: _shareReport,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: bodyWidget,
        );
      },
    );
  }
}
