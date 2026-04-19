import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  final _db = DatabaseHelper();
  bool _isLoading = true;
  
  List<double> _runningDistances = List.filled(7, 0.0);
  List<double> _proteinRatios = List.filled(7, 0.0);
  List<DateTime> _days = [];

  double _avgProteinRatio = 0.0;
  double _totalDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  Future<void> _loadWeeklyData() async {
    setState(() => _isLoading = true);
    final profile = await ProfileService.getProfile();
    final target = profile[ProfileService.keyTargetProtein] ?? 150.0;
    
    final now = DateTime.now();
    List<DateTime> days = [];
    List<double> distances = [];
    List<double> proteinRatios = [];

    double sumProteinRatios = 0;
    double sumDistances = 0;

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      days.add(day);

      // Fetch Workouts
      final workouts = await _db.getWorkoutsByDate(day);
      double dist = 0;
      for (var w in workouts) {
        if (w.type == 'running' && w.distance != null) {
          dist += w.distance!;
        }
      }
      distances.add(dist);
      sumDistances += dist;

      // Fetch Protein
      final proteins = await _db.getProteinEntriesByDate(day);
      double protConsumed = 0;
      for (var p in proteins) {
        protConsumed += p.proteinGrams;
      }
      double ratio = target > 0 ? (protConsumed / target).clamp(0.0, 1.0) : 0.0;
      proteinRatios.add(ratio);
      sumProteinRatios += ratio;
    }

    if (mounted) {
      setState(() {
        _days = days;
        _runningDistances = distances;
        _proteinRatios = proteinRatios;
        _avgProteinRatio = sumProteinRatios / 7.0;
        _totalDistance = sumDistances;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(' Weekly Performance'),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSummaryHeader(),
                const SizedBox(height: 32),
                
                Text(' Lari 7 Hari Terakhir (km)', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildRunningChart(),

                const SizedBox(height: 32),
                Text('🥩 Kepatuhan Protein 7 Hari Terakhir', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildProteinChart(),
                const SizedBox(height: 100), // spacing
              ],
            ),
          ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Text('Rata-rata Kepatuhan Protein', style: TextStyle(color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          Text('${(_avgProteinRatio * 100).toInt()}%', style: TextStyle(color: _avgProteinRatio >= 0.8 ? AppTheme.neonGreen : AppTheme.accentOrange, fontSize: 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('Total Jarak Lari', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${_totalDistance.toStringAsFixed(1)} km', style: TextStyle(color: AppTheme.electricBlue, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                children: [
                  Text('Hari Terbaik', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Sabtu', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildRunningChart() {
    double maxDist = _runningDistances.reduce((a, b) => a > b ? a : b);
    if (maxDist == 0) maxDist = 5.0; // fallback

    return AspectRatio(
      aspectRatio: 1.6,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxDist * 1.2, // add some headroom
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  int idx = val.toInt();
                  if (idx < 0 || idx >= 7) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(DateFormat('E', 'id').format(_days[idx]), style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(7, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: _runningDistances[i],
                  color: AppTheme.electricBlue,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                )
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildProteinChart() {
    return AspectRatio(
      aspectRatio: 1.6,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 1.1, 
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  int idx = val.toInt();
                  if (idx < 0 || idx >= 7) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(DateFormat('E', 'id').format(_days[idx]), style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(7, (i) {
            final val = _proteinRatios[i];
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: val,
                  color: val >= 1.0 ? AppTheme.neonGreen : AppTheme.accentRed,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                )
              ],
            );
          }),
        ),
      ),
    );
  }
}
