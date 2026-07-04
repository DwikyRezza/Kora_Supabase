import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../theme/app_theme.dart';
import '../../bloc/activity_analytics_bloc.dart';
import '../../bloc/activity_analytics_state.dart';

class InsightSectionWidget extends StatelessWidget {
  const InsightSectionWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityAnalyticsBloc, ActivityAnalyticsState>(
      buildWhen: (previous, current) => previous.insight != current.insight,
      builder: (context, state) {
        if (state.insight == null) {
          return const SizedBox.shrink(); // Hide if no insight
        }

        final isPositive = state.insight!.isPositive;
        final iconColor = isPositive ? AppTheme.accent : Colors.red;
        final icon = isPositive ? Icons.auto_awesome : Icons.info_outline;

        return Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.insight!.text,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
