import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/enums/activity_enums.dart';
import '../../../../theme/app_theme.dart';
import '../../bloc/activity_analytics_bloc.dart';
import '../../bloc/activity_analytics_event.dart';
import '../../bloc/activity_analytics_state.dart';

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              "Today's Activity",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _buildTimeframeSelector(),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return BlocBuilder<ActivityAnalyticsBloc, ActivityAnalyticsState>(
      buildWhen: (previous, current) => previous.selectedTimeframe != current.selectedTimeframe,
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(100),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TimeframeCapsule(
                label: '1H',
                isActive: state.selectedTimeframe == ActivityTimeframe.oneHour,
                onTap: () => context.read<ActivityAnalyticsBloc>().add(const ChangeTimeframe(ActivityTimeframe.oneHour)),
              ),
              _TimeframeCapsule(
                label: '6H',
                isActive: state.selectedTimeframe == ActivityTimeframe.sixHours,
                onTap: () => context.read<ActivityAnalyticsBloc>().add(const ChangeTimeframe(ActivityTimeframe.sixHours)),
              ),
              _TimeframeCapsule(
                label: '24H',
                isActive: state.selectedTimeframe == ActivityTimeframe.oneDay,
                onTap: () => context.read<ActivityAnalyticsBloc>().add(const ChangeTimeframe(ActivityTimeframe.oneDay)),
              ),
              _TimeframeCapsule(
                label: '7D',
                isActive: state.selectedTimeframe == ActivityTimeframe.sevenDays,
                onTap: () => context.read<ActivityAnalyticsBloc>().add(const ChangeTimeframe(ActivityTimeframe.sevenDays)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimeframeCapsule extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TimeframeCapsule({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
