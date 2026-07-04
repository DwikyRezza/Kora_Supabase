import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/enums/activity_enums.dart';
import '../../../../theme/app_theme.dart';
import '../../bloc/activity_analytics_bloc.dart';
import '../../bloc/activity_analytics_event.dart';
import '../../bloc/activity_analytics_state.dart';

class MetricSelectorWidget extends StatelessWidget {
  const MetricSelectorWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityAnalyticsBloc, ActivityAnalyticsState>(
      buildWhen: (previous, current) => previous.selectedMetric != current.selectedMetric,
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MetricChip(
                  label: 'Asupan',
                  icon: '🔥',
                  isActive: state.selectedMetric == ActivityMetric.intake,
                  activeColor: Colors.orange,
                  onTap: () => context.read<ActivityAnalyticsBloc>().add(const ChangeMetric(ActivityMetric.intake)),
                ),
                const SizedBox(width: 8),
                _MetricChip(
                  label: 'Energi',
                  icon: '⚡',
                  isActive: state.selectedMetric == ActivityMetric.calories,
                  activeColor: Colors.green,
                  onTap: () => context.read<ActivityAnalyticsBloc>().add(const ChangeMetric(ActivityMetric.calories)),
                ),
                const SizedBox(width: 8),
                _MetricChip(
                  label: 'Durasi',
                  icon: '⏱',
                  isActive: state.selectedMetric == ActivityMetric.duration,
                  activeColor: Colors.blue,
                  onTap: () => context.read<ActivityAnalyticsBloc>().add(const ChangeMetric(ActivityMetric.duration)),
                ),
                const SizedBox(width: 8),
                _MetricChip(
                  label: 'Jarak',
                  icon: '📍',
                  isActive: state.selectedMetric == ActivityMetric.distance,
                  activeColor: Colors.purple,
                  onTap: () => context.read<ActivityAnalyticsBloc>().add(const ChangeMetric(ActivityMetric.distance)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _MetricChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isActive 
        ? activeColor 
        : (AppTheme.isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F5));
    final textColor = isActive 
        ? Colors.white 
        : AppTheme.textMuted;
        
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(100),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
