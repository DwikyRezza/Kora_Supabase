import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/workout.dart';
import '../services/database_helper.dart';
import '../services/profile_service.dart';
import '../widgets/activity/training_volume_chart.dart';

class WeeklyReportScreen extends StatefulWidget {
  final bool embedMode;
  const WeeklyReportScreen({super.key, this.embedMode = false});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  final _db = DatabaseHelper();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScreenshotController _screenshotController = ScreenshotController();

  // ── Existing streak / protein state ──────────────────────────────────────
  bool _isLoading = true;
  int _currentStreak = 0;
  int _bestStreak = 0;
  double _consistencyScore = 0.0;
  List<int> _frozenDays = [];
  double _targetProtein = 150.0;
  DateTime _currentMonth = DateTime.now();
  Map<int, Map<String, dynamic>> _dailyStats = {};

  // ── New workout-analysis state ───────────────────────────────────────────
  String _selectedFilter = 'all'; // all | running | walking | weightlifting
  Map<int, List<Workout>> _weekWorkouts = {}; // day-of-month → workouts
  int _totalWorkoutsMonth = 0;
  Set<int> _workoutDaysMonth = {};

  static const _filterLabels = {
    'all': 'Semua',
    'running': 'Lari',
    'walking': 'Jalan',
    'weightlifting': 'Workout',
  };

  static final _filterColors = {
    'all': AppTheme.textPrimary,
    'running': AppTheme.accent,
    'walking': Color(0xFF0099F9),
    'weightlifting': AppTheme.accent,
  };

  // ── Apple Fitness-style progress section state ───────────────────────────
  // 'run' | 'walk' | 'lift'
  String _progressFilter = 'run';
  // Dynamic chart data — either 4 weekly (1-month) or 3 monthly (3-month) points
  List<_ChartPoint> _chartData = [];
  bool _twelveWeekLoading = true;
  bool _isMonthlyScale = false; // false = 1-month/weekly, true = 3-month/monthly
  int? _selectedChartIndex; // null = show latest point

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _playFireSound();
    _loadData();
    _loadWorkoutData();
    _loadChartData();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playFireSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/fire.mp3'));
    } catch (e) {
      debugPrint('Fire sound not found or failed to play: $e');
    }
  }

  // ── Data loading ─────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final profile = await ProfileService.getProfile();
    _targetProtein = profile[ProfileService.keyTargetProtein] ?? 150.0;
    if (_targetProtein == 0) _targetProtein = 150.0;

    final entries = await _db.getProteinEntriesByMonth(
        _currentMonth.year, _currentMonth.month);

    Map<int, Map<String, dynamic>> stats = {};
    int daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

    for (int i = 1; i <= daysInMonth; i++) {
      stats[i] = {
        'protein': 0.0,
        'calories': 0.0,
        'sugar': 0.0,
        'salt': 0.0,
        'fat': 0.0,
      };
    }

    for (var e in entries) {
      if (e.date.year == _currentMonth.year &&
          e.date.month == _currentMonth.month) {
        int day = e.date.day;
        stats[day]!['protein'] += e.proteinGrams;
        stats[day]!['calories'] += e.calories;
        stats[day]!['sugar'] += e.sugarGrams;
        stats[day]!['salt'] += e.saltGrams;
        stats[day]!['fat'] += e.fatGrams;
      }
    }

    final globalWorkoutStreak = await _db.getCalculateWorkoutStreak();
    int currentStreak = globalWorkoutStreak['current'] ?? 0;
    int bestStreak = globalWorkoutStreak['best'] ?? 0;
    
    // We keep frozenDays empty for now since freeze logic for workouts isn't implemented yet
    List<int> frozenDays = [];

    // Monthly total workouts
    final monthWorkouts = await _db.getWorkoutsByDateRange(
      start: DateTime(_currentMonth.year, _currentMonth.month, 1),
      end: DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59),
    );
    
    Set<int> workoutDays = {};
    for (var w in monthWorkouts) {
      workoutDays.add(w.date.day);
    }

    // Consistency score is based on workout days this month
    int daysPassed = DateTime.now().day;
    if (_currentMonth.month != DateTime.now().month ||
        _currentMonth.year != DateTime.now().year) {
      daysPassed = daysInMonth;
    }
    
    if (mounted) {
      setState(() {
        _dailyStats = stats;
        _currentStreak = currentStreak;
        _bestStreak = bestStreak;
        _frozenDays = frozenDays;
        _consistencyScore =
            daysPassed > 0 ? (workoutDays.length / daysPassed) * 100 : 0.0;
        _totalWorkoutsMonth = monthWorkouts.length;
        _workoutDaysMonth = workoutDays;
        _isLoading = false;
      });
    }
  }

  // ── Dynamic chart data loader ─────────────────────────────────────────────
  Future<void> _loadChartData() async {
    setState(() {
      _twelveWeekLoading = true;
      _selectedChartIndex = null;
    });
    final now = DateTime.now();
    final dbType = (_progressFilter == 'lift')
        ? 'weightlifting'
        : ((_progressFilter == 'walk') ? null : 'running');

    final List<_ChartPoint> points = [];
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final thisMonday = todayMidnight.subtract(Duration(days: (todayMidnight.weekday - 1) % 7));
    
    // SELALU gunakan 12 titik mingguan (past 12 weeks) untuk Strava-style
    for (int w = 11; w >= 0; w--) {
      final weekStart = thisMonday.subtract(Duration(days: w * 7));
      final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      final workouts = await _db.getWorkoutsByDateRange(start: weekStart, end: weekEnd, type: dbType);
      final metrics = _computeMetricsFromWorkouts(workouts);
      points.add(_ChartPoint(rangeStart: weekStart, rangeEnd: weekEnd, metrics: metrics));
    }

    if (mounted) {
      setState(() {
        _chartData = points;
        _isMonthlyScale = false;
        _twelveWeekLoading = false;
      });
    }
  }

  _WeekMetrics _computeMetricsFromWorkouts(List<Workout> workouts) {
    double distance = 0, duration = 0, elevation = 0, volume = 0, sets = 0;
    for (final wk in workouts) {
      if (_progressFilter == 'walk') {
        if (wk.type != 'running' || (wk.distance ?? 0) > 2.0) continue;
      } else if (_progressFilter == 'run') {
        if (wk.type != 'running' || (wk.distance ?? 0) <= 2.0) continue;
      } else if (_progressFilter == 'lift') {
        if (wk.type != 'weightlifting') continue;
      }
      distance += wk.distance ?? 0;
      duration += wk.duration;
      elevation += wk.elevationGain ?? 0;
      double vol = (wk.weight ?? 0) * (wk.reps ?? 0) * (wk.sets ?? 1);
      if (vol == 0) vol = wk.weight ?? 0;
      volume += vol;
      sets += wk.sets ?? 0;
    }
    return _WeekMetrics(distance: distance, duration: duration, elevation: elevation, volume: volume, sets: sets.round());
  }

  void _onProgressFilterChanged(String f) {
    if (_progressFilter == f) return;
    setState(() => _progressFilter = f);
    _loadChartData();
  }

  Future<void> _loadWorkoutData() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - 6);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    String? dbType;
    if (_selectedFilter == 'running' || _selectedFilter == 'walking') {
      dbType = 'running';
    } else if (_selectedFilter == 'weightlifting') {
      dbType = 'weightlifting';
    }

    final workouts = await _db.getWorkoutsByDateRange(
      start: start,
      end: end,
      type: dbType,
    );

    final Map<int, List<Workout>> weekMap = {};
    for (int i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i)).day;
      weekMap[day] = [];
    }
    for (final w in workouts) {
      if (_selectedFilter == 'walking' &&
          w.type == 'running' &&
          (w.distance ?? 0) > 2.0) {
        continue; // Exclude long-distance runs from "walking" filter
      }
      weekMap[w.date.day]?.add(w);
    }

    if (mounted) setState(() => _weekWorkouts = weekMap);
  }

  void _onFilterChanged(String filter) {
    if (_selectedFilter == filter) return;
    setState(() => _selectedFilter = filter);
    _loadWorkoutData();
  }

  // ── Share ────────────────────────────────────────────────────────────────
  Future<void> _shareReport() async {
    try {
      final image = await _screenshotController.capture(
          pixelRatio: 2.0,
          delay: const Duration(milliseconds: 100));
      if (image == null || !mounted) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/kora_report.png');
      await file.writeAsBytes(image);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Laporan latihan saya dari Kora! 🔥');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membagikan laporan: $e')),
        );
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  List<DateTime> get _last7Days {
    final now = DateTime.now();
    return List.generate(7, (i) => DateTime(now.year, now.month, now.day - 6 + i));
  }

  _WeekMetrics _computeWeekMetrics() {
    double distance = 0, duration = 0, elevation = 0;
    double volume = 0, sets = 0;
    for (final list in _weekWorkouts.values) {
      for (final w in list) {
        distance += w.distance ?? 0;
        duration += w.duration;
        elevation += w.elevationGain ?? 0;
        volume += (w.weight ?? 0) * (w.reps ?? 0) * (w.sets ?? 1);
        sets += w.sets ?? 0;
      }
    }
    return _WeekMetrics(
        distance: distance,
        duration: duration,
        elevation: elevation,
        volume: volume,
        sets: sets.round());
  }

  // _computeProgressWeekMetrics removed — metrics now computed via _computeMetricsFromWorkouts

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final bodyWidget = _isLoading
        ? Center(
            child: CircularProgressIndicator(color: AppTheme.accent))
        : SingleChildScrollView(
            padding: EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Apple Fitness-style Progress Section ─────────────────
                _buildAppleFitnessProgressSection(),
                Divider(height: 1, thickness: 1, color: AppTheme.divider),
                SizedBox(height: 24),
                // ── Existing Sections ─────────────────────────────────────
                _buildFilterChips(),
                SizedBox(height: 24),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: _buildDynamicMetrics(),
                ),
                SizedBox(height: 32),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: _buildSummaryCard(),
                ),
                SizedBox(height: 32),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Screenshot(
                    controller: _screenshotController,
                    child: Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Column(
                        children: [
                          _buildStreakHero(),
                          SizedBox(height: 24),
                          _buildAiryFireGrid(),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 32),
                _buildMonthlyLinearChart(),
                SizedBox(height: 32),
                _buildAssistantEvaluation(),
              ],
            ),
          );

    if (widget.embedMode) {
      return bodyWidget;
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Aktivitas Latihan',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.5)),
        actions: [
          IconButton(
            icon: Icon(Icons.ios_share_rounded,
                color: AppTheme.textPrimary, size: 22),
            onPressed: _shareReport,
          ),
          SizedBox(width: 8),
        ],
      ),
      body: bodyWidget,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APPLE FITNESS-STYLE PROGRESS SECTION
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAppleFitnessProgressSection() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, _, __) {
        return Container(
          color: AppTheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Filter pills: Run | Walk | Lift ─────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Row(
                  children: [
                    _buildProgressPill(
                      label: 'Lari',
                      icon: Icons.directions_run_rounded,
                      key: 'run',
                    ),
                    SizedBox(width: 10),
                    _buildProgressPill(
                      label: 'Jalan',
                      icon: Icons.directions_walk_rounded,
                      key: 'walk',
                    ),
                    SizedBox(width: 10),
                    _buildProgressPill(
                      label: 'Workout',
                      icon: Icons.fitness_center_rounded,
                      key: 'lift',
                    ),
                  ],
                ),
                ),
              ),
              SizedBox(height: 18),

              // ── Date range & stats ─────────────────────────────────────
              _buildProgressStats(),

              SizedBox(height: 8),

              // ── 12-week line chart ─────────────────────────────────────
              _buildTwelveWeekChart(),

              // ── See more button ─────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Lihat lebih banyak progres',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressPill({
    required String label,
    required IconData icon,
    required String key,
  }) {
    final isActive = _progressFilter == key;
    return GestureDetector(
      onTap: () => _onProgressFilterChanged(key),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.transparent
              : Colors.transparent,
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
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppTheme.accent : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStats() {
    if (_chartData.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(height: 60),
      );
    }

    // Use selected point or default to the latest (last) point
    final idx = (_selectedChartIndex != null &&
            _selectedChartIndex! >= 0 &&
            _selectedChartIndex! < _chartData.length)
        ? _selectedChartIndex!
        : _chartData.length - 1;
    final point = _chartData[idx];
    final m = point.metrics;

    // Format tanggal berdasarkan skala
    final String dateLabel;
    if (_isMonthlyScale) {
      dateLabel = DateFormat('MMMM yyyy', 'id').format(point.rangeStart);
    } else {
      final start = DateFormat('MMM d').format(point.rangeStart);
      final end = DateFormat('MMM d, yyyy').format(point.rangeEnd);
      dateLabel = '$start - $end';
    }

    // Format metrik Jarak / Volume
    final String firstLabel = _progressFilter == 'lift' ? 'Volume' : 'Distance';
    final String firstVal = _progressFilter == 'lift'
        ? (m.volume > 999 ? '${(m.volume / 1000).toStringAsFixed(1)}k kg' : '${m.volume.round()} kg')
        : (m.distance < 0.01 ? '0 km' : '${m.distance.toStringAsFixed(2)} km');

    // Format Durasi
    final timeStr = m.duration < 1
        ? '0m'
        : m.duration >= 60
            ? '${(m.duration ~/ 60)}h ${(m.duration % 60).round()}m'
            : '${m.duration.round()}m';

    // Format metrik Elevasi / Jumlah Set
    final String thirdLabel = _progressFilter == 'lift' ? 'Total Set' : 'Elev Gain';
    final String thirdVal = _progressFilter == 'lift' ? '${m.sets}' : '${m.elevation.round()} m';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: Duration(milliseconds: 180),
            child: Text(
              dateLabel,
              key: ValueKey(dateLabel),
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _progressStatItem(firstLabel, firstVal),
              _progressStatItem('Time', timeStr),
              _progressStatItem(thirdLabel, thirdVal),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTwelveWeekChart() {
    if (_twelveWeekLoading || _chartData.isEmpty || _chartData.length < 12) {
      return SizedBox(
        height: 200,
        child: Center(
            child: CircularProgressIndicator(
                color: AppTheme.accent, strokeWidth: 2)),
      );
    }

    // Helper untuk format nilai Y
    String formatVal(double v) {
      if (_progressFilter == 'lift') {
        return v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k kg' : '${v.round()} kg';
      }
      return '${v.toStringAsFixed(v == v.truncate() ? 0 : 1)} km';
    }

    // Nilai max untuk skala Y
    final maxVal = _chartData.fold(0.0, (m, p) => p.metrics.distance > m ? p.metrics.distance : m);
    final rawMax = _progressFilter == 'lift'
        ? _chartData.fold(0.0, (m, p) => p.metrics.volume > m ? p.metrics.volume : m)
        : maxVal;
    final yMax = _progressFilter == 'lift'
        ? (rawMax < 10.0 ? 200.0 : (rawMax * 1.35).ceilToDouble())
        : (rawMax < 1.0 ? 2.0 : (rawMax * 1.4).ceilToDouble());
    final yMid = (yMax / 2).roundToDouble();

    // Data 12 titik
    final List<double> chartValues = _chartData.map((p) {
      return _progressFilter == 'lift' ? p.metrics.volume : p.metrics.distance;
    }).toList();

    // Sumbu X labels
    final List<String> xLabels = List.generate(12, (i) {
      if (i == 0 || _chartData[i].rangeStart.month != _chartData[i - 1].rangeStart.month) {
        return DateFormat('MMM').format(_chartData[i].rangeStart).toUpperCase();
      }
      return '';
    });

    return Padding(
      padding: EdgeInsets.only(top: 12, bottom: 8),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            // ── Menggunakan Reusable TrainingVolumeChart ──
            Padding(
              padding: EdgeInsets.only(right: 56),
              child: TrainingVolumeChart(
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

            // ── Y-axis labels kanan (Tetap ada di luar chart) ──
            Positioned(
              right: 0,
              top: 0,
              bottom: 28,
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

  // Static helper — fl_chart requires a static/top-level function for getTooltipItems
  static List<LineTooltipItem?> _emptyTooltip(List<LineBarSpot> spots) =>
      spots.map((_) => null).toList();

  // ── 1. Filter Chips ──────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: _filterLabels.entries.map((e) {
          final isSelected = _selectedFilter == e.key;
          final color = _filterColors[e.key]!;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => _onFilterChanged(e.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Text(e.value,
                    style: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 2. Dynamic Metrics ───────────────────────────────────────────────────
  Widget _buildDynamicMetrics() {
    final m = _computeWeekMetrics();
    final isAll = _selectedFilter == 'all';
    final isCardio =
        _selectedFilter == 'running' || _selectedFilter == 'walking';
    final accent = isAll ? AppTheme.accent : _filterColors[_selectedFilter]!;

    if (isAll) {
      // "Semua" — aggregate global metrics
      final totalSessions =
          _weekWorkouts.values.fold(0, (s, list) => s + list.length);
      final activeDays =
          _weekWorkouts.values.where((list) => list.isNotEmpty).length;
      return Row(children: [
        Expanded(
            child: _metricBox('Total Sesi', '$totalSessions',
                Icons.fitness_center, accent)),
        SizedBox(width: 12),
        Expanded(
            child: _metricBox('Durasi', '${m.duration.round()} m',
                Icons.timer_outlined, accent)),
        SizedBox(width: 12),
        Expanded(
            child: _metricBox('Hari Aktif', '$activeDays / 7',
                Icons.calendar_today_outlined, accent)),
      ]);
    } else if (isCardio) {
      return Row(children: [
        Expanded(
            child: _metricBox('Jarak', '${m.distance.toStringAsFixed(2)} km',
                Icons.straighten, accent)),
        SizedBox(width: 12),
        Expanded(
            child: _metricBox('Durasi', '${m.duration.round()} m',
                Icons.timer_outlined, accent)),
        SizedBox(width: 12),
        Expanded(
            child: _metricBox('Elevasi', '${m.elevation.round()} m',
                Icons.terrain, accent)),
      ]);
    } else {
      return Row(children: [
        Expanded(
            child: _metricBox('Volume',
                '${m.volume > 999 ? '${(m.volume / 1000).toStringAsFixed(1)}k' : m.volume.round().toString()} kg',
                Icons.fitness_center, accent)),
        SizedBox(width: 12),
        Expanded(
            child: _metricBox('Durasi', '${m.duration.round()} m',
                Icons.timer_outlined, accent)),
        SizedBox(width: 12),
        Expanded(
            child: _metricBox(
                'Total Set', '${m.sets}', Icons.layers_outlined, accent)),
      ]);
    }
  }

  Widget _metricBox(String label, String value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 18),
          SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary)),
          SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }

  // ── 3. Seven-Day Bar Chart ───────────────────────────────────────────────
  Widget _build7DayBarChart() {
    final days = _last7Days;
    final isCardio =
        _selectedFilter == 'running' || _selectedFilter == 'walking';
    final isAll = _selectedFilter == 'all';
    final accent = isAll ? AppTheme.accent : _filterColors[_selectedFilter]!;

    // Build per-day values
    List<double> values = [];
    double maxVal = 1;
    for (final d in days) {
      final workouts = _weekWorkouts[d.day] ?? [];
      double v = 0;
      if (isAll) {
        v = workouts.fold(0.0, (s, w) => s + w.duration);
      } else if (isCardio) {
        v = workouts.fold(0.0, (s, w) => s + (w.distance ?? 0));
      } else {
        v = workouts.fold(
            0.0, (s, w) => s + (w.weight ?? 0) * (w.reps ?? 0) * (w.sets ?? 1));
      }
      values.add(v);
      if (v > maxVal) maxVal = v;
    }
    maxVal *= 1.25; // headroom for top labels

    final barGroups = List.generate(7, (i) {
      final v = values[i];
      final normalised = v / maxVal;
      return BarChartGroupData(
        x: i,
        showingTooltipIndicators: [0],
        barRods: [
          BarChartRodData(
            toY: normalised,
            color: v > 0 ? accent : Colors.transparent,
            width: 14,
            borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 1.0,
              color: AppTheme.textMuted.withOpacity(0.08),
            ),
          ),
        ],
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
              'Aktivitas 7 Hari Terakhir',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ),
        SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 1.0,
                barTouchData: BarTouchData(
                  enabled: true,
                  handleBuiltInTouches: false,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.transparent,
                    tooltipMargin: 6,
                    getTooltipItem: (group, gIdx, rod, rIdx) {
                      final v = values[group.x];
                      if (v <= 0) {
                        return BarTooltipItem('', TextStyle());
                      }
                      String label;
                      if (isAll) {
                        label = '${v.round()}m';
                      } else if (isCardio) {
                        label = '${v.toStringAsFixed(1)}km';
                      } else {
                        label = v > 999
                            ? '${(v / 1000).toStringAsFixed(1)}k'
                            : '${v.round()}';
                      }
                      return BarTooltipItem(label,
                          TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w800));
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final d = days[value.toInt()];
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                              DateFormat('E', 'id')
                                  .format(d)
                                  .substring(0, 2)
                                  .toUpperCase(),
                              style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 4. Summary Card ──────────────────────────────────────────────────────
  Widget _buildSummaryCard() {
    final m = _computeWeekMetrics();
    final isAll = _selectedFilter == 'all';
    final totalSessions =
        _weekWorkouts.values.fold(0, (s, list) => s + list.length);

    if (isAll) {
      // 3-column layout for "Semua"
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _summaryMetric(
                label: 'Streak',
                value: '$_currentStreak',
                suffix: 'Hari 🔥',
                color: AppTheme.accent,
              ),
            ),
            Container(width: 1, height: 50, color: const Color(0xFFE8E8E8)),
            Expanded(
              child: _summaryMetric(
                label: 'Aktivitas',
                value: '$totalSessions',
                suffix: 'sesi',
                color: AppTheme.accent,
                align: TextAlign.center,
              ),
            ),
            Container(width: 1, height: 50, color: const Color(0xFFE8E8E8)),
            Expanded(
              child: _summaryMetric(
                label: 'Durasi',
                value: '${m.duration.round()}',
                suffix: 'menit',
                color: const Color(0xFF0099F9),
                align: TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }

    // Default 2-column layout for filtered types
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryMetric(
              label: 'Konsistensi',
              value: '$_currentStreak',
              suffix: 'Hari 🔥',
              color: AppTheme.accent,
            ),
          ),
          Container(width: 1, height: 50, color: const Color(0xFFE8E8E8)),
          Expanded(
            child: _summaryMetric(
              label: 'Total Aktivitas',
              value: '$_totalWorkoutsMonth',
              suffix: 'sesi',
              color: AppTheme.accent,
              align: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric({
    required String label,
    required String value,
    required String suffix,
    required Color color,
    TextAlign align = TextAlign.left,
  }) {
    CrossAxisAlignment crossAxis;
    MainAxisAlignment mainAxis;
    if (align == TextAlign.right) {
      crossAxis = CrossAxisAlignment.end;
      mainAxis = MainAxisAlignment.end;
    } else if (align == TextAlign.center) {
      crossAxis = CrossAxisAlignment.center;
      mainAxis = MainAxisAlignment.center;
    } else {
      crossAxis = CrossAxisAlignment.start;
      mainAxis = MainAxisAlignment.start;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: crossAxis,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.2)),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: mainAxis,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1)),
              SizedBox(width: 3),
              Flexible(
                child: Text(suffix,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color.withOpacity(0.75)),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 5. Streak Hero (inside screenshot) ───────────────────────────────────
  Widget _buildStreakHero() {
    return Column(
      children: [
        Text('CURRENT STREAK',
            style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5)),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Lottie.asset('assets/lottie/fire_streak.json',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Text('🔥', style: TextStyle(fontSize: 40))),
            ),
            SizedBox(width: 8),
            Text('$_currentStreak',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2)),
          ],
        ),
        SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                Text('Best Streak',
                    style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('$_bestStreak',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
              ]),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                Text('Konsistensi',
                    style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('${_consistencyScore.toStringAsFixed(0)}%',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
              ]),
            ),
          ),
        ]),
      ],
    );
  }

  // ── 6. Calendar Grid (existing, adapted) ─────────────────────────────────
  Widget _buildAiryFireGrid() {
    int daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    int firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    List<String> weekdays = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('MMMM yyyy').format(_currentMonth),
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Row(children: [
              IconButton(
                icon: Icon(Icons.chevron_left,
                    color: AppTheme.textPrimary),
                onPressed: () {
                  setState(() {
                    _currentMonth =
                        DateTime(_currentMonth.year, _currentMonth.month - 1);
                    _loadData();
                  });
                },
              ),
              IconButton(
                icon: Icon(Icons.chevron_right,
                    color: AppTheme.textPrimary),
                onPressed: () {
                  if (_currentMonth.month == DateTime.now().month &&
                      _currentMonth.year == DateTime.now().year) return;
                  setState(() {
                    _currentMonth =
                        DateTime(_currentMonth.year, _currentMonth.month + 1);
                    _loadData();
                  });
                },
              ),
            ])
          ],
        ),
        SizedBox(height: 16),
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
        SizedBox(height: 12),
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
            if (day < 1 || day > daysInMonth) return SizedBox();

            final stat = _dailyStats[day]!;
            final progress = stat['protein'] / _targetProtein;
            final isSuccess = progress >= 0.9;
            final isFrozen = _frozenDays.contains(day);
            final gglWarn =
                stat['sugar'] > 50 || stat['salt'] > 5 || stat['fat'] > 67;

            return GestureDetector(
              onTap: () => _showDayDetail(day, stat),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isSuccess || isFrozen)
                    Container(
                      decoration: BoxDecoration(
                        color: (isFrozen
                                ? const Color(0xFF00A9DD)
                                : AppTheme.accent)
                            .withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(isFrozen ? '🧊' : '🔥',
                            style: TextStyle(fontSize: 22)),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant, shape: BoxShape.circle),
                      child: Center(
                        child: Text('$day',
                            style: TextStyle(
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                    ),
                  
                  // Tanda api (🔥) kecil di bagian bawah-kanan jika ada latihan di hari tsb
                  if (_workoutDaysMonth.contains(day))
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.surface, // Supaya tidak tertimpa background
                          shape: BoxShape.circle,
                        ),
                        child: const Text('🔥', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                  if (isSuccess && gglWarn)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                            color: Color(0xFFFF3400), shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ── 7. Monthly Protein Trend (Line Chart style) ─────────────────────────
  Widget _buildMonthlyLinearChart() {
    int daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    
    final List<FlSpot> spots = [];
    for (int i = 1; i <= daysInMonth; i++) {
      final stat = _dailyStats[i] ?? {'protein': 0.0};
      spots.add(FlSpot(i.toDouble(), stat['protein']));
    }

    final double yMax = _targetProtein * 1.4;
    final double yMid = _targetProtein;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text('Tren Protein Bulanan',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ),
        SizedBox(height: 24),
        SizedBox(
          height: 200,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: daysInMonth * 26.0,
              child: LineChart(
                LineChartData(
                  minX: 1,
                  maxX: daysInMonth.toDouble(),
                  minY: 0,
                  maxY: yMax,
                  clipData: const FlClipData.all(),
                  backgroundColor: AppTheme.surface,
                  
                  // Grid
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yMid / 2,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppTheme.textPrimary.withOpacity(0.06),
                      strokeWidth: 1,
                    ),
                  ),

                  borderData: FlBorderData(show: false),

                  // Tooltip/Touch data
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppTheme.surfaceVariant,
                      getTooltipItems: (spots) => spots.map((s) {
                        return LineTooltipItem(
                          'Tgl ${s.x.toInt()}\n${s.y.toStringAsFixed(1)}g',
                          TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        );
                      }).toList(),
                    ),
                  ),

                  // Axis Titles
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final day = value.toInt();
                          // Hanya tampilkan label hari ke-1, 5, 10, 15, 20, 25, atau hari terakhir
                          if (day % 5 != 0 && day != 1 && day != daysInMonth) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              day.toString(),
                              style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Horizontal dashed line for Target Protein
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: _targetProtein,
                        color: AppTheme.accent.withOpacity(0.6),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 8, bottom: 4),
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            backgroundColor: AppTheme.surface.withOpacity(0.8),
                          ),
                          labelResolver: (line) => 'Target: ${_targetProtein.round()}g',
                        ),
                      ),
                    ],
                  ),

                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: AppTheme.accent,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, pct, bar, idx) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: AppTheme.accent,
                          strokeWidth: 0,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.accent.withOpacity(0.3),
                            AppTheme.accent.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 8. Assistant Evaluation (existing) ───────────────────────────────────
  Widget _buildAssistantEvaluation() {
    int gglFails = 0;
    for (int i = 1; i <= 31; i++) {
      if (_dailyStats.containsKey(i)) {
        var s = _dailyStats[i]!;
        if (s['sugar'] > 50 || s['salt'] > 5 || s['fat'] > 67) gglFails++;
      }
    }

    String msg;
    IconData icon;
    Color color;

    if (_currentStreak >= 15) {
      msg =
          '$_currentStreak hari tanpa putus! Kamu sedang di jalur yang benar. Jangan biarkan godaan akhir pekan memadamkan apimu!';
      icon = Icons.local_fire_department;
      color = AppTheme.accent;
    } else if (_consistencyScore < 50 && _currentStreak < 3) {
      msg =
          'Apimu padam beberapa kali belakangan ini. Jangan biarkan satu hari malas merusak progres sebulan. Bangkit lagi!';
      icon = Icons.warning_amber_rounded;
      color = const Color(0xFFFF3400);
    } else if (gglFails > 5) {
      msg =
          'Streak harianmu cukup aman, tapi konsumsi GGL-mu bulan ini tinggi ($gglFails hari jebol). Perbaiki kualitas makananmu.';
      icon = Icons.health_and_safety_rounded;
      color = Colors.yellow[700]!;
    } else {
      msg =
          'Konsistensimu terjaga dengan baik di ${_consistencyScore.toStringAsFixed(0)}%. Tetap pertahankan ritme ini!';
      icon = Icons.thumb_up_alt_rounded;
      color = AppTheme.accent;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
            color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 32),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('The Intelligent Coach',
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(msg,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Day Detail Sheet ─────────────────────────────────────────────────────
  void _showDayDetail(int day, Map<String, dynamic> stat) {
    bool sugarWarn = stat['sugar'] > 50.0;
    bool saltWarn = stat['salt'] > 5.0;
    bool fatWarn = stat['fat'] > 67.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 24),
            Text(
                '${day} ${DateFormat('MMMM yyyy').format(_currentMonth)}',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 24),
            _statRow('Protein', '${stat['protein'].toStringAsFixed(1)}g',
                const Color(0xFFBD4BE5)),
            _statRow('Kalori', '${stat['calories'].toStringAsFixed(0)} kcal',
                const Color(0xFFFF3400)),
            SizedBox(height: 16),
            Divider(color: AppTheme.surfaceVariant, thickness: 2),
            SizedBox(height: 16),
            _statRow('Gula', '${stat['sugar'].toStringAsFixed(1)}g',
                sugarWarn ? const Color(0xFFFF3400) : AppTheme.textMuted,
                isWarning: sugarWarn),
            _statRow('Garam', '${stat['salt'].toStringAsFixed(1)}g',
                saltWarn ? const Color(0xFFFF3400) : AppTheme.textMuted,
                isWarning: saltWarn),
            _statRow('Lemak', '${stat['fat'].toStringAsFixed(1)}g',
                fatWarn ? const Color(0xFFFF3400) : AppTheme.textMuted,
                isWarning: fatWarn),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, Color color,
      {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text(label,
                style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            if (isWarning) ...[
              SizedBox(width: 8),
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFF3400), size: 18),
            ]
          ]),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Data point untuk dynamic chart — bisa mingguan (4 titik) atau bulanan (3 titik).
class _ChartPoint {
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final _WeekMetrics metrics;

  const _ChartPoint({
    required this.rangeStart,
    required this.rangeEnd,
    required this.metrics,
  });
}

/// Simple data holder for weekly workout metrics.
class _WeekMetrics {
  final double distance;
  final double duration;
  final double elevation;
  final double volume;
  final int sets;

  const _WeekMetrics({
    required this.distance,
    required this.duration,
    required this.elevation,
    required this.volume,
    required this.sets,
  });
}
