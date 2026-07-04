import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../theme/app_theme.dart';
import '../../bloc/activity_analytics_bloc.dart';
import '../../bloc/activity_analytics_event.dart';
import '../../bloc/activity_analytics_state.dart';
import '../../data/datasources/mock_activity_analytics_datasource.dart';
import '../../data/repositories/activity_analytics_repository.dart';
import '../../domain/rules/insight_generator.dart';
import 'activity_chart_widget.dart';
import 'empty_state_widget.dart';
import 'header_widget.dart';
import 'hero_metric_widget.dart';
import 'insight_section_widget.dart';
import 'metric_selector_widget.dart';
import 'summary_section_widget.dart';

class ActivityAnalyticsCard extends StatelessWidget {
  const ActivityAnalyticsCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        // Dependencies can be injected via get_it or similar in a real app
        final repository = ActivityAnalyticsRepository(MockActivityAnalyticsDataSource());
        final insightGenerator = InsightGenerator();
        return ActivityAnalyticsBloc(
          repository: repository,
          insightGenerator: insightGenerator,
        )..add(const LoadActivityAnalyticsData());
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            if (!AppTheme.isDarkMode)
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
          ],
        ),
        child: BlocBuilder<ActivityAnalyticsBloc, ActivityAnalyticsState>(
          buildWhen: (previous, current) => 
              previous.status != current.status && 
              (current.status == ActivityAnalyticsStatus.initial || 
               current.status == ActivityAnalyticsStatus.loading && current.chartData.isEmpty),
          builder: (context, state) {
            // Check for empty state logic
            // For now, if mock data returns completely empty and we aren't loading
            bool isEmpty = state.status == ActivityAnalyticsStatus.success && state.heroNumber == 0;
            
            if (isEmpty) {
              return EmptyStateWidget(
                onStartWorkout: () {
                  // Navigate to workout
                },
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                HeaderWidget(),
                HeroMetricWidget(),
                ActivityChartWidget(),
                MetricSelectorWidget(),
                SummarySectionWidget(),
                InsightSectionWidget(),
              ],
            );
          },
        ),
      ),
    );
  }
}
