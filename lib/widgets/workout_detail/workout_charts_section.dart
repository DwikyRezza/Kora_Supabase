import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/workout.dart';
import '../../theme/app_theme.dart';

class WorkoutChartsSection extends StatelessWidget {
  final Workout workout;

  const WorkoutChartsSection({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    final double workoutDistance = workout.distance ?? 0.0;
    final double avgPaceMins = workoutDistance > 0 ? (workout.duration / workoutDistance) : 0.0;

    final series = _generateSeriesData(workoutDistance, avgPaceMins);

    List<String> splits = [];
    if (workout.splitsStr != null && workout.splitsStr!.isNotEmpty) {
      try {
        splits = List<String>.from(jsonDecode(workout.splitsStr!));
      } catch (e) {
        // ignore
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Pace'),
        _buildPaceChart(series, avgPaceMins, splits),
        const SizedBox(height: 28),

        _buildSectionHeader('Grade Adjusted Pace (GAP)'),
        _buildGapChart(series, avgPaceMins),
        const SizedBox(height: 28),

        _buildSectionHeader('Cadence'),
        _buildCadenceChart(series),
        const SizedBox(height: 28),

        _buildSectionHeader('Elevation'),
        _buildElevationChart(series),
        _buildElevationSummary(),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        title,
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -0.3),
      ),
    );
  }

  Widget _buildPaceChart(List<_ChartsSeriesPoint> series, double avgPaceMins, List<String> splits) {
    final spots = series.map((s) => FlSpot(s.distance, 15.0 - s.pace)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Expanded(
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: workout.distance ?? 5.0,
                  minY: 5.0,
                  maxY: 12.0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 2.0,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppTheme.textPrimary.withOpacity(0.06),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    show: false,
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 15.0 - avgPaceMins,
                        color: AppTheme.textMuted.withOpacity(0.5),
                        strokeWidth: 1.5,
                        dashArray: [5, 5],
                      ),
                    ],
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppTheme.accent,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.accent.withOpacity(0.25),
                            AppTheme.accent.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniSubStat('Avg Elapsed Pace', _calculatePace()),
                _miniSubStat('Fastest Split', '${splits.isNotEmpty ? splits.first : "5:32"} /km'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGapChart(List<_ChartsSeriesPoint> series, double avgPaceMins) {
    final spots = series.map((s) => FlSpot(s.distance, 15.0 - s.gap)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(24),
        ),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: workout.distance ?? 5.0,
            minY: 5.0,
            maxY: 12.0,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppTheme.textPrimary.withOpacity(0.06),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(
              show: false,
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: const Color(0xFFE28900),
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE28900).withOpacity(0.2),
                      const Color(0xFFE28900).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCadenceChart(List<_ChartsSeriesPoint> series) {
    final spots = series.map((s) => FlSpot(s.distance, s.cadence)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Expanded(
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: workout.distance ?? 5.0,
                  minY: 130.0,
                  maxY: 195.0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppTheme.textPrimary.withOpacity(0.06),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    show: false,
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: const Color(0xFFBD4BE5),
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFFBD4BE5).withOpacity(0.25),
                            const Color(0xFFBD4BE5).withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniSubStat('Avg Cadence', '174 spm'),
                _miniSubStat('Max Cadence', '182 spm'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElevationChart(List<_ChartsSeriesPoint> series) {
    final spots = series.map((s) => FlSpot(s.distance, s.elevation)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(24),
        ),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: workout.distance ?? 5.0,
            minY: 0.0,
            maxY: 100.0,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppTheme.textPrimary.withOpacity(0.06),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(
              show: false,
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: const Color(0xFF6B7280),
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF6B7280).withOpacity(0.25),
                      const Color(0xFF6B7280).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildElevationSummary() {
    final elevGain = '${(workout.elevationGain ?? 0.0).round()} m';
    final maxElev = '${(workout.maxElevation ?? (workout.elevationGain != null ? workout.elevationGain! * 1.5 : 55.0)).round()} m';
    final minElev = '${workout.elevationGain != null ? (workout.maxElevation != null ? (workout.maxElevation! - workout.elevationGain!).clamp(0.0, 999.0).round() : 12) : 12} m';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _miniSubStat('Elevation Gain', elevGain),
            _miniSubStat('Max Elevation', maxElev),
            _miniSubStat('Min Elevation', minElev),
          ],
        ),
      ),
    );
  }

  Widget _miniSubStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }

  String _calculatePace() {
    if (workout.distance == null || workout.distance == 0) return '0:00';
    final paceMins = workout.duration / workout.distance!;
    final m = paceMins.truncate();
    final s = ((paceMins - m) * 60).truncate().toString().padLeft(2, '0');
    return '$m:$s /km';
  }

  List<_ChartsSeriesPoint> _generateSeriesData(double dist, double avgPace) {
    final double actualDist = dist > 0 ? dist : 5.0;
    final double actualPace = avgPace > 0 ? avgPace : 7.0;
    final List<_ChartsSeriesPoint> list = [];
    const int count = 25;

    for (int i = 0; i <= count; i++) {
      final d = (actualDist / count) * i;
      final factor = 1.0 + 0.05 * (i % 4 - 2);
      final p = actualPace * factor;
      final elev = 35.0 + 15.0 * (i % 6 - 3) + (i % 3) * 2;
      final slope = (i == 0) ? 0.0 : (elev - list.last.elevation);
      final gap = p - (slope * 0.04);
      final cad = 171.0 + 3.0 * (i % 5 - 2);
      final hr = 138.0 + 12.0 * (i / count);

      list.add(_ChartsSeriesPoint(
        distance: d,
        pace: p.clamp(3.0, 15.0),
        gap: gap.clamp(3.0, 15.0),
        cadence: cad.clamp(140.0, 200.0),
        elevation: elev.clamp(0.0, 200.0),
        heartRate: hr.clamp(100.0, 190.0),
      ));
    }
    return list;
  }
}

class _ChartsSeriesPoint {
  final double distance;
  final double pace;
  final double gap;
  final double cadence;
  final double elevation;
  final double heartRate;

  _ChartsSeriesPoint({
    required this.distance,
    required this.pace,
    required this.gap,
    required this.cadence,
    required this.elevation,
    required this.heartRate,
  });
}
