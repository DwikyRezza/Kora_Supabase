import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/enums/activity_enums.dart';
import '../../../../theme/app_theme.dart';
import '../../bloc/activity_analytics_bloc.dart';
import '../../bloc/activity_analytics_state.dart';

class ActivityChartWidget extends StatelessWidget {
  const ActivityChartWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityAnalyticsBloc, ActivityAnalyticsState>(
      buildWhen: (previous, current) => 
          previous.chartData != current.chartData ||
          previous.selectedMetric != current.selectedMetric ||
          previous.status != current.status,
      builder: (context, state) {
        if (state.status == ActivityAnalyticsStatus.loading && state.chartData.isEmpty) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.chartData.isEmpty) {
          return const SizedBox(
            height: 160,
            child: Center(child: Text("Tidak ada data untuk periode ini")),
          );
        }

        final Color chartColor = _getColorForMetric(state.selectedMetric);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getInterval(state.chartData.map((e) => e.y).reduce((a, b) => a > b ? a : b)),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppTheme.border.withOpacity(0.5),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < state.chartData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              state.chartData[index].label,
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: state.chartData.map((d) => FlSpot(d.x, d.y)).toList(),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: chartColor,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          chartColor.withOpacity(0.3),
                          chartColor.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => AppTheme.isDarkMode ? Colors.grey[800]! : Colors.white,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          spot.y.toStringAsFixed(1),
                          TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        FlLine(color: chartColor.withOpacity(0.5), strokeWidth: 2, dashArray: [4, 4]),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 6,
                              color: chartColor,
                              strokeWidth: 3,
                              strokeColor: AppTheme.surface,
                            );
                          },
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            ),
          ),
        );
      },
    );
  }

  Color _getColorForMetric(ActivityMetric metric) {
    switch (metric) {
      case ActivityMetric.intake: return Colors.orange;
      case ActivityMetric.calories: return Colors.green;
      case ActivityMetric.duration: return Colors.blue;
      case ActivityMetric.distance: return Colors.purple;
    }
  }

  double _getInterval(double maxVal) {
    if (maxVal == 0) return 1.0;
    return maxVal / 3; // roughly 3 grid lines
  }
}
