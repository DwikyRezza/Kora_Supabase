import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_theme.dart';
import '../../bloc/analytics_bloc.dart';
import '../../bloc/analytics_state.dart';
import '../../../../widgets/activity/training_volume_chart.dart';
import '../../../../models/workout.dart';

class _WeekMetrics {
  final double distance;
  final double duration;
  final double elevation;
  final double volume;
  final int sets;
  _WeekMetrics(this.distance, this.duration, this.elevation, this.volume, this.sets);
}

class _ChartPoint {
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final _WeekMetrics metrics;
  _ChartPoint({required this.rangeStart, required this.rangeEnd, required this.metrics});
}

class ProgressSection extends StatefulWidget {
  const ProgressSection({super.key});

  @override
  State<ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends State<ProgressSection> {
  String _progressFilter = 'running';
  int? _selectedChartIndex;

  List<_ChartPoint> _calculate12WeekData(List<Workout> allWorkouts) {
    List<_ChartPoint> points = [];
    final now = DateTime.now();
    final thisMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));

    for (int w = 11; w >= 0; w--) {
      final weekStart = thisMonday.subtract(Duration(days: w * 7));
      final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      
      final workouts = allWorkouts.where((w) {
        return w.date.isAfter(weekStart.subtract(const Duration(seconds: 1))) && 
               w.date.isBefore(weekEnd.add(const Duration(seconds: 1))) &&
               w.type == _progressFilter;
      }).toList();

      double distance = 0, duration = 0, elevation = 0, volume = 0, sets = 0;
      for (final wk in workouts) {
        if (_progressFilter == 'walking') {
          distance += wk.distance ?? 0;
          duration += wk.duration;
          elevation += wk.elevationGain ?? 0;
        } else if (_progressFilter == 'running') {
          distance += wk.distance ?? 0;
          duration += wk.duration;
          elevation += wk.elevationGain ?? 0;
        } else if (_progressFilter == 'weightlifting') {
          double vol = (wk.weight ?? 0) * (wk.sets ?? 0) * (wk.reps ?? 0);
          if (vol == 0) vol = wk.weight ?? 0;
          volume += vol;
          sets += (wk.sets ?? 0);
          duration += wk.duration;
        }
      }
      points.add(_ChartPoint(rangeStart: weekStart, rangeEnd: weekEnd, metrics: _WeekMetrics(distance, duration, elevation, volume, sets.toInt())));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnalyticsBloc, AnalyticsState>(
      builder: (context, state) {
        final chartData = _calculate12WeekData(state.allWorkouts);
        
        return Container(
          color: AppTheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Row(
                    children: [
                      _buildProgressPill(label: 'Lari', icon: Icons.directions_run_rounded, keyFilter: 'running'),
                      const SizedBox(width: 10),
                      _buildProgressPill(label: 'Jalan', icon: Icons.directions_walk_rounded, keyFilter: 'walking'),
                      const SizedBox(width: 10),
                      _buildProgressPill(label: 'Workout', icon: Icons.fitness_center_rounded, keyFilter: 'weightlifting'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _buildProgressStats(chartData),
              const SizedBox(height: 8),
              _buildTwelveWeekChart(chartData),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressPill({required String label, required IconData icon, required String keyFilter}) {
    final isActive = _progressFilter == keyFilter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _progressFilter = keyFilter;
          _selectedChartIndex = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.transparent : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isActive ? AppTheme.accent : AppTheme.border,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? AppTheme.accent : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppTheme.accent : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStats(List<_ChartPoint> chartData) {
    if (chartData.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(height: 60),
      );
    }

    final idx = (_selectedChartIndex != null && _selectedChartIndex! >= 0 && _selectedChartIndex! < chartData.length)
        ? _selectedChartIndex!
        : chartData.length - 1;
    final point = chartData[idx];
    final m = point.metrics;

    final start = DateFormat('MMM d').format(point.rangeStart);
    final end = DateFormat('MMM d, yyyy').format(point.rangeEnd);
    final dateLabel = '$start - $end';

    final String firstLabel = _progressFilter == 'weightlifting' ? 'Volume' : 'Distance';
    final String firstVal = _progressFilter == 'weightlifting'
        ? (m.volume > 999 ? '${(m.volume / 1000).toStringAsFixed(1)}k kg' : '${m.volume.round()} kg')
        : (m.distance < 0.01 ? '0 km' : '${m.distance.toStringAsFixed(2)} km');

    final timeStr = m.duration < 1
        ? '0m'
        : m.duration >= 60
            ? '${(m.duration ~/ 60)}h ${(m.duration % 60).round()}m'
            : '${m.duration.round()}m';

    final String thirdLabel = _progressFilter == 'weightlifting' ? 'Total Set' : 'Elev Gain';
    final String thirdVal = _progressFilter == 'weightlifting' ? '${m.sets}' : '${m.elevation.round()} m';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat(firstLabel, firstVal),
              _miniStat('Time', timeStr),
              _miniStat(thirdLabel, thirdVal),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildTwelveWeekChart(List<_ChartPoint> chartData) {
    if (chartData.isEmpty || chartData.length < 12) {
      return SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2)),
      );
    }

    String formatVal(double v) {
      if (_progressFilter == 'weightlifting') {
        return v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k kg' : '${v.round()} kg';
      }
      return '${v.toStringAsFixed(v == v.truncate() ? 0 : 1)} km';
    }

    final maxVal = chartData.fold(0.0, (m, p) => p.metrics.distance > m ? p.metrics.distance : m);
    final rawMax = _progressFilter == 'weightlifting'
        ? chartData.fold(0.0, (m, p) => p.metrics.volume > m ? p.metrics.volume : m)
        : maxVal;
    
    final yMax = _progressFilter == 'weightlifting'
        ? (rawMax < 10.0 ? 200.0 : (rawMax * 1.35).ceilToDouble())
        : (rawMax < 1.0 ? 2.0 : (rawMax * 1.4).ceilToDouble());
    final yMid = (yMax / 2).roundToDouble();

    final List<double> chartValues = chartData.map((p) {
      return _progressFilter == 'weightlifting' ? p.metrics.volume : p.metrics.distance;
    }).toList();
    print("CHART VALUES: $chartValues");
    print("MAX Y: $yMax");

    final List<String> xLabels = List.generate(12, (i) {
      if (i == 0 || chartData[i].rangeStart.month != chartData[i - 1].rangeStart.month) {
        return DateFormat('MMM').format(chartData[i].rangeStart).toUpperCase();
      }
      return '';
    });

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TrainingVolumeChart(
                unit: _progressFilter == "weightlifting" ? "kg" : "km",
                weeklyVolumes: chartValues,
                bottomLabels: xLabels,
                maxY: yMax,
                onIndexChanged: (idx) {
                  if (mounted) {
                    setState(() => _selectedChartIndex = idx);
                  }
                },
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 24,
              width: 52,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatVal(yMax), style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
                  Text(formatVal(yMid), style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
                  Text(formatVal(0), style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
