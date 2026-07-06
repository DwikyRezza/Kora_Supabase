import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_theme.dart';
import '../../bloc/analytics_bloc.dart';
import '../../bloc/analytics_event.dart';

class CalendarSection extends StatelessWidget {
  final DateTime currentMonth;
  final Set<int> workoutDays;

  const CalendarSection({
    super.key,
    required this.currentMonth,
    required this.workoutDays,
  });

  @override
  Widget build(BuildContext context) {
    int daysInMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    int firstWeekday = DateTime(currentMonth.year, currentMonth.month, 1).weekday;
    List<String> weekdays = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('MMMM yyyy').format(currentMonth),
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Row(children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: AppTheme.textPrimary),
                onPressed: () {
                  final newMonth = DateTime(currentMonth.year, currentMonth.month - 1);
                  context.read<AnalyticsBloc>().add(AnalyticsMonthChanged(newMonth));
                },
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: AppTheme.textPrimary),
                onPressed: () {
                  final now = DateTime.now();
                  if (currentMonth.month == now.month && currentMonth.year == now.year) return;
                  final newMonth = DateTime(currentMonth.year, currentMonth.month + 1);
                  context.read<AnalyticsBloc>().add(AnalyticsMonthChanged(newMonth));
                },
              ),
            ])
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekdays
              .map((w) => SizedBox(
                  width: 30,
                  child: Text(w,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 14))))
              .toList(),
        ),
        const SizedBox(height: 12),
        GridView.builder(
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

            bool hasWorkout = workoutDays.contains(day);
            bool isToday = currentMonth.month == DateTime.now().month && 
                           currentMonth.year == DateTime.now().year && 
                           day == DateTime.now().day;

            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: hasWorkout
                        ? AppTheme.accent.withValues(alpha: 0.15)
                        : AppTheme.surfaceVariant,
                    shape: BoxShape.circle,
                    border: isToday 
                        ? Border.all(color: AppTheme.accent, width: 2) 
                        : null,
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (hasWorkout)
                          const Opacity(
                            opacity: 0.35,
                            child: Text('🔥', style: TextStyle(fontSize: 26)),
                          ),
                        Text(
                          '$day',
                          style: TextStyle(
                            color: hasWorkout
                                ? AppTheme.accent
                                : AppTheme.textMuted,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
