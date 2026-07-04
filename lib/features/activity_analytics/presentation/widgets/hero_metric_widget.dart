import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/enums/activity_enums.dart';
import '../../../../theme/app_theme.dart';
import '../../bloc/activity_analytics_bloc.dart';
import '../../bloc/activity_analytics_state.dart';

class HeroMetricWidget extends StatelessWidget {
  const HeroMetricWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityAnalyticsBloc, ActivityAnalyticsState>(
      buildWhen: (previous, current) => 
          previous.heroNumber != current.heroNumber ||
          previous.trendPercentage != current.trendPercentage ||
          previous.selectedMetric != current.selectedMetric ||
          previous.status != current.status,
      builder: (context, state) {
        if (state.status == ActivityAnalyticsStatus.loading && state.heroNumber == 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
          );
        }

        final isPositive = state.trendPercentage >= 0;
        final trendColor = isPositive ? Colors.green : Colors.red;
        final trendIcon = isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
        
        String unit = _getUnit(state.selectedMetric);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // We can use a tween animation builder for counting effect
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: state.heroNumber),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      String formattedValue = value.toStringAsFixed(
                          state.selectedMetric == ActivityMetric.distance ? 1 : 0);
                      return Text(
                        formattedValue,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                          height: 1.0,
                          letterSpacing: -1.0,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: trendColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      children: [
                        Icon(trendIcon, size: 14, color: trendColor),
                        const SizedBox(width: 4),
                        Text(
                          "${state.trendPercentage.abs().toStringAsFixed(1)}%",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: trendColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "vs previous period",
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  String _getUnit(ActivityMetric metric) {
    switch (metric) {
      case ActivityMetric.intake: return "kcal";
      case ActivityMetric.calories: return "kcal";
      case ActivityMetric.duration: return "mins";
      case ActivityMetric.distance: return "km";
    }
  }
}
