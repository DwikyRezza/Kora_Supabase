import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../theme/app_theme.dart';
import '../../bloc/activity_analytics_bloc.dart';
import '../../bloc/activity_analytics_state.dart';

class SummarySectionWidget extends StatelessWidget {
  const SummarySectionWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityAnalyticsBloc, ActivityAnalyticsState>(
      buildWhen: (previous, current) => 
          previous.heroNumber != current.heroNumber ||
          previous.selectedMetric != current.selectedMetric,
      builder: (context, state) {
        if (state.heroNumber == 0 && state.status == ActivityAnalyticsStatus.loading) {
          return const SizedBox.shrink();
        }

        // Just an example of summary. In a real app, this could be target values etc.
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.isDarkMode ? const Color(0xFF252525) : const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.border.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Rata-rata",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${(state.heroNumber * 0.8).toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Tertinggi",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${(state.heroNumber * 1.2).toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Total",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${(state.heroNumber).toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
