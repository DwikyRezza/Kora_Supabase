import os

content = '''import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../theme/app_theme.dart';
import '../../bloc/analytics_bloc.dart';
import '../../bloc/analytics_event.dart';
import '../../bloc/analytics_state.dart';

class WeeklyReportScreen extends StatelessWidget {
  final bool embedMode;
  const WeeklyReportScreen({super.key, this.embedMode = false});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AnalyticsBloc()..add(AnalyticsLoadData(DateTime.now(), 'all')),
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
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnalyticsBloc, AnalyticsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: widget.embedMode ? null : AppBar(
            title: const Text('Analisis Mingguan', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            backgroundColor: AppTheme.surface,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppTheme.textPrimary),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAiCoachCard(state),
                  const SizedBox(height: 24),
                  _buildMonthlyCalendar(context, state),
                  const SizedBox(height: 24),
                  _buildVolumeChart(state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAiCoachCard(AnalyticsState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: state.lottieAnimationUrl.isNotEmpty
                ? Lottie.network(
                    state.lottieAnimationUrl,
                    fit: BoxFit.cover,
                  )
                : const SizedBox(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Coach', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  state.coachMessage,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCalendar(BuildContext context, AnalyticsState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy', 'id_ID').format(state.currentMonth),
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: AppTheme.textPrimary),
                    onPressed: () {
                      context.read<AnalyticsBloc>().add(
                        AnalyticsMonthChanged(DateTime(state.currentMonth.year, state.currentMonth.month - 1))
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: AppTheme.textPrimary),
                    onPressed: () {
                      if (state.currentMonth.month == DateTime.now().month &&
                          state.currentMonth.year == DateTime.now().year) return;
                      context.read<AnalyticsBloc>().add(
                        AnalyticsMonthChanged(DateTime(state.currentMonth.year, state.currentMonth.month + 1))
                      );
                    },
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          _buildCalendarGrid(state),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(AnalyticsState state) {
    int daysInMonth = DateTime(state.currentMonth.year, state.currentMonth.month + 1, 0).day;
    int firstWeekday = DateTime(state.currentMonth.year, state.currentMonth.month, 1).weekday;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 12,
      ),
      itemCount: 42,
      itemBuilder: (context, index) {
        int day = index - firstWeekday + 2;
        if (day < 1 || day > daysInMonth) return const SizedBox();

        final hasWorkout = state.workoutDaysMonth.contains(day);

        return Container(
          decoration: BoxDecoration(
            color: hasWorkout ? AppTheme.accent : AppTheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: hasWorkout ? AppTheme.accent : AppTheme.border),
          ),
          child: Center(
            child: Text(
              '',
              style: TextStyle(
                color: hasWorkout ? Colors.white : AppTheme.textMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVolumeChart(AnalyticsState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Volume Latihan (Bulan Ini)', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Center(
              child: Text(
                'Total:  Workouts',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
    );
  }
}
'''

with open('lib/features/analytics/presentation/screens/weekly_report_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Weekly Report Screen rewritten successfully!")
