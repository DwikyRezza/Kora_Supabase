import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/workout.dart';
import '../../theme/app_theme.dart';

class WorkoutChartsContainer extends StatefulWidget {
  final Workout workout;
  final ValueNotifier<LatLng?> trackingPinPositionNotifier;

  const WorkoutChartsContainer({
    super.key,
    required this.workout,
    required this.trackingPinPositionNotifier,
  });

  @override
  State<WorkoutChartsContainer> createState() => _WorkoutChartsContainerState();
}

class _WorkoutChartsContainerState extends State<WorkoutChartsContainer> {
  late final ValueNotifier<double?> _hoverDistanceNotifier;
  late final List<_ChartsSeriesPoint> _series;
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _hoverDistanceNotifier = ValueNotifier<double?>(null);
    final double workoutDistance = widget.workout.distance ?? 0.0;
    final double avgPaceMins = workoutDistance > 0 ? (widget.workout.duration / workoutDistance) : 0.0;
    _series = _generateSeriesData(workoutDistance, avgPaceMins);
    _parseRoutePoints();
  }

  @override
  void dispose() {
    _hoverDistanceNotifier.dispose();
    super.dispose();
  }

  void _parseRoutePoints() {
    if (widget.workout.polyline != null && widget.workout.polyline!.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(widget.workout.polyline!);
        _routePoints = decoded.map((p) => LatLng(
          (p[0] as num).toDouble(),
          (p[1] as num).toDouble(),
        )).toList();
      } catch (e) {
        // ignore
      }
    }
  }

  void _handleTouch(FlTouchEvent event, LineTouchResponse? response) {
    if (!event.isInterestedForInteractions || response == null || response.lineBarSpots == null || response.lineBarSpots!.isEmpty) {
      _hoverDistanceNotifier.value = null;
      widget.trackingPinPositionNotifier.value = null;
      return;
    }

    final spot = response.lineBarSpots!.first;
    final double touchedKm = spot.x;
    _hoverDistanceNotifier.value = touchedKm;

    if (_routePoints.isNotEmpty) {
      final totalDist = widget.workout.distance ?? 5.0;
      if (totalDist > 0) {
        double progress = (touchedKm / totalDist).clamp(0.0, 1.0);
        int index = (progress * (_routePoints.length - 1)).round();
        widget.trackingPinPositionNotifier.value = _routePoints[index];
      }
    }
  }

  int _findClosestSpotIndex(double hoverDistance) {
    double minDiff = double.maxFinite;
    int closestIdx = 0;
    for (int i = 0; i < _series.length; i++) {
      final diff = (_series[i].distance - hoverDistance).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIdx = i;
      }
    }
    return closestIdx;
  }

  @override
  Widget build(BuildContext context) {
    final double workoutDistance = widget.workout.distance ?? 0.0;
    final double avgPaceMins = workoutDistance > 0 ? (widget.workout.duration / workoutDistance) : 0.0;

    return ValueListenableBuilder<double?>(
      valueListenable: _hoverDistanceNotifier,
      builder: (context, hoverDist, _) {
        final int? activeIndex = hoverDist != null ? _findClosestSpotIndex(hoverDist) : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── SECTION: PACE CHART ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pace',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  IconButton(
                    icon: Icon(Icons.info_outline_rounded, color: AppTheme.textSecondary, size: 20),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            _buildChartFrame(
              chart: _buildPaceChart(activeIndex, avgPaceMins),
              stats: _buildPaceStats(avgPaceMins),
            ),
            const SizedBox(height: 24),

            // ── SECTION: GRADE ADJUSTED PACE ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppTheme.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Grade Adjusted Pace',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildChartFrame(
              chart: _buildGapChart(activeIndex, avgPaceMins),
              stats: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statLabelValue('Avg GAP', '${_formatPaceVal(avgPaceMins * 0.97)} /km'),
                    const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── SECTION: PACE ZONES ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppTheme.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Pace Zones',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Based on your predicted 5K time of 19:18',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            _buildPaceZonesWidget(avgPaceMins),
            const SizedBox(height: 24),
          ],
        );
      }
    );
  }

  Widget _buildChartFrame({required Widget chart, Widget? stats}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            SizedBox(height: 180, child: chart),
            if (stats != null) ...[
              const SizedBox(height: 12),
              stats,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaceChart(int? activeIndex, double avgPaceMins) {
    final paceSpots = _series.map((s) => FlSpot(s.distance, 15.0 - s.pace)).toList();

    // Map elevation values linearly to [5.2, 7.8] so they look like a clean background silhouette
    double minElev = double.maxFinite;
    double maxElev = -double.maxFinite;
    for (final s in _series) {
      if (s.elevation < minElev) minElev = s.elevation;
      if (s.elevation > maxElev) maxElev = s.elevation;
    }
    final double elevRange = (maxElev - minElev) == 0 ? 1.0 : (maxElev - minElev);
    
    final elevationSpots = _series.map((s) {
      final double normalizedElev = 5.2 + ((s.elevation - minElev) / elevRange) * 2.6;
      return FlSpot(s.distance, normalizedElev);
    }).toList();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: widget.workout.distance ?? 5.0,
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
        titlesData: const FlTitlesData(show: false),
        lineTouchData: LineTouchData(
          touchCallback: _handleTouch,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => AppTheme.accent,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((s) {
                // If it is the elevation curve, ignore tooltip
                if (s.barIndex == 1) return null;
                final double origPace = 15.0 - s.y;
                final m = origPace.truncate();
                final sec = ((origPace - m) * 60).round().toString().padLeft(2, '0');
                return LineTooltipItem(
                  "$m:$sec /km\n${s.x.toStringAsFixed(2)} km",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
        showingTooltipIndicators: activeIndex != null ? [
          ShowingTooltipIndicators([
            LineBarSpot(
              LineChartBarData(spots: paceSpots),
              0,
              paceSpots[activeIndex],
            ),
          ]),
        ] : [],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 15.0 - avgPaceMins,
              color: AppTheme.textMuted.withOpacity(0.5),
              strokeWidth: 1.5,
              dashArray: [5, 5],
            ),
          ],
          verticalLines: [
            if (activeIndex != null)
              VerticalLine(
                x: _series[activeIndex].distance,
                color: AppTheme.textMuted.withOpacity(0.8),
                strokeWidth: 1.5,
                dashArray: [5, 5],
              ),
          ],
        ),
        lineBarsData: [
          // ── Bar Index 1: Background Elevation Silhouette
          LineChartBarData(
            spots: elevationSpots,
            isCurved: true,
            color: AppTheme.isDarkMode ? AppTheme.surfaceVariant.withOpacity(0.3) : AppTheme.border.withOpacity(0.5),
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.isDarkMode ? AppTheme.surfaceVariant.withOpacity(0.2) : AppTheme.border.withOpacity(0.4),
            ),
          ),
          // ── Bar Index 0: Foreground Pace Line
          LineChartBarData(
            spots: paceSpots,
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
                  AppTheme.accent.withOpacity(0.2),
                  AppTheme.accent.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGapChart(int? activeIndex, double avgPaceMins) {
    final spots = _series.map((s) => FlSpot(s.distance, 15.0 - s.gap)).toList();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: widget.workout.distance ?? 5.0,
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
        titlesData: const FlTitlesData(show: false),
        lineTouchData: LineTouchData(
          touchCallback: _handleTouch,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => AppTheme.accent,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((s) {
                final double origPace = 15.0 - s.y;
                final m = origPace.truncate();
                final sec = ((origPace - m) * 60).round().toString().padLeft(2, '0');
                return LineTooltipItem(
                  "$m:$sec /km\n${s.x.toStringAsFixed(2)} km",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
        showingTooltipIndicators: activeIndex != null ? [
          ShowingTooltipIndicators([
            LineBarSpot(
              LineChartBarData(spots: spots),
              0,
              spots[activeIndex],
            ),
          ]),
        ] : [],
        extraLinesData: ExtraLinesData(
          verticalLines: [
            if (activeIndex != null)
              VerticalLine(
                x: _series[activeIndex].distance,
                color: AppTheme.textMuted.withOpacity(0.8),
                strokeWidth: 1.5,
                dashArray: [5, 5],
              ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.isDarkMode ? Colors.white : AppTheme.accent.withOpacity(0.8),
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  (AppTheme.isDarkMode ? Colors.white : AppTheme.accent).withOpacity(0.2),
                  (AppTheme.isDarkMode ? Colors.white : AppTheme.accent).withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaceStats(double avgPaceMins) {
    final totalSeconds = (widget.workout.duration * 60).round();
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    final movingTimeStr = h > 0
        ? "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}"
        : "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          _statRow('Avg Pace', '${_formatPaceVal(avgPaceMins)} /km'),
          _statRow('Moving Time', movingTimeStr),
          _statRow('Avg Elapsed Pace', '${_formatPaceVal(avgPaceMins * 1.05)} /km'),
          _statRow('Elapsed Time', '${(widget.workout.duration * 1.02).round()}m'),
          _statRow('Fastest Split', '5:14 /km'),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPaceZonesWidget(double avgPace) {
    final zones = _generatePaceZones(avgPace);
    final zLabels = ['Z6', 'Z5', 'Z4', 'Z3', 'Z2', 'Z1'];
    final zRanges = ['< 3:41', '3:41-3:55', '3:55-4:11', '4:11-4:40', '4:40-5:25', '> 5:25'];
    final zColors = [
      AppTheme.accent,
      const Color(0xFFFF9966),
      const Color(0xFF4DCC60),
      AppTheme.accent,
      const Color(0xFF006623),
      Colors.black87,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: List.generate(6, (i) {
            final key = zLabels[i];
            final val = zones[key] ?? 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 24, child: Text(key, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: val / 100,
                        minHeight: 12,
                        backgroundColor: AppTheme.border,
                        valueColor: AlwaysStoppedAnimation<Color>(zColors[i]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${val.round()}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: Text(
                      zRanges[i],
                      textAlign: TextAlign.right,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Map<String, double> _generatePaceZones(double avgPace) {
    double z1 = 0, z2 = 0, z3 = 0, z4 = 0, z5 = 0, z6 = 0;
    if (avgPace >= 5.5) {
      z1 = 92; z2 = 7; z3 = 1;
    } else if (avgPace >= 4.7) {
      z1 = 18; z2 = 64; z3 = 15; z4 = 3;
    } else if (avgPace >= 4.2) {
      z2 = 12; z3 = 62; z4 = 21; z5 = 5;
    } else {
      z3 = 8; z4 = 38; z5 = 44; z6 = 10;
    }
    return {'Z1': z1, 'Z2': z2, 'Z3': z3, 'Z4': z4, 'Z5': z5, 'Z6': z6};
  }

  Widget _statLabelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        Text(value, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  String _formatPaceVal(double paceVal) {
    final m = paceVal.truncate();
    final s = ((paceVal - m) * 60).round().toString().padLeft(2, '0');
    return '$m:$s';
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
      final power = 210.0 + 30.0 * (i % 3 - 1) + (slope * 5);

      list.add(_ChartsSeriesPoint(
        distance: d,
        pace: p.clamp(3.0, 15.0),
        gap: gap.clamp(3.0, 15.0),
        cadence: cad.clamp(140.0, 200.0),
        elevation: elev.clamp(0.0, 200.0),
        heartRate: hr.clamp(100.0, 190.0),
        power: power.clamp(100.0, 450.0),
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
  final double power;

  _ChartsSeriesPoint({
    required this.distance,
    required this.pace,
    required this.gap,
    required this.cadence,
    required this.elevation,
    required this.heartRate,
    required this.power,
  });
}
