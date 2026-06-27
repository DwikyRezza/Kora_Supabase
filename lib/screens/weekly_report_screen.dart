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

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

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

  static const _filterLabels = {
    'all': 'Semua',
    'running': 'Lari',
    'walking': 'Jalan',
    'weightlifting': 'Angkat Beban',
  };

  static final _filterColors = {
    'all': AppTheme.textPrimary,
    'running': Color(0xFF00B33F),
    'walking': Color(0xFF0099F9),
    'weightlifting': Color(0xFFFF5406),
  };

  // ── Apple Fitness-style progress section state ───────────────────────────
  // 'run' | 'walk'
  String _progressFilter = 'run';
  // 12 data points — satu per minggu, 12 minggu ke belakang
  List<_WeekPoint> _twelveWeekData = [];
  bool _twelveWeekLoading = true;

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _playFireSound();
    _loadData();
    _loadWorkoutData();
    _loadTwelveWeekData();
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

    // Streak calculation
    int currentStreak = 0, bestStreak = 0, successDays = 0;
    int availableFreeze =
        profile[ProfileService.keyStreakFreezeCount] ?? 0;
    List<int> frozenDays = [];

    daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    int daysPassed = DateTime.now().day;
    if (_currentMonth.month != DateTime.now().month ||
        _currentMonth.year != DateTime.now().year) {
      daysPassed = daysInMonth;
    }

    for (int i = 1; i <= daysPassed; i++) {
      double p = stats[i]!['protein'];
      if (p >= _targetProtein * 0.9) {
        currentStreak++;
        successDays++;
        if (currentStreak > bestStreak) bestStreak = currentStreak;
      } else {
        if (availableFreeze > 0 && i < daysPassed) {
          availableFreeze--;
          frozenDays.add(i);
          currentStreak++;
          if (currentStreak > bestStreak) bestStreak = currentStreak;
        } else {
          if (i < DateTime.now().day ||
              _currentMonth.month != DateTime.now().month) {
            currentStreak = 0;
          }
        }
      }
    }

    // Monthly total workouts
    final monthWorkouts = await _db.getWorkoutsByDateRange(
      start: DateTime(_currentMonth.year, _currentMonth.month, 1),
      end: DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59),
    );

    if (mounted) {
      setState(() {
        _dailyStats = stats;
        _currentStreak = currentStreak;
        _bestStreak = bestStreak;
        _frozenDays = frozenDays;
        _consistencyScore =
            daysPassed > 0 ? (successDays / daysPassed) * 100 : 0.0;
        _totalWorkoutsMonth = monthWorkouts.length;
        _isLoading = false;
      });
    }
  }

  // ── 12-week data loader ──────────────────────────────────────────────────
  Future<void> _loadTwelveWeekData() async {
    setState(() => _twelveWeekLoading = true);
    final now = DateTime.now();
    // Mulai dari awal minggu saat ini (Senin)
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final thisMonday = todayMidnight.subtract(
        Duration(days: (todayMidnight.weekday - 1) % 7));

    final List<_WeekPoint> points = [];
    for (int w = 11; w >= 0; w--) {
      final weekStart = thisMonday.subtract(Duration(days: w * 7));
      final weekEnd = weekStart
          .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      final dbType = (_progressFilter == 'walk') ? null : 'running';
      final workouts = await _db.getWorkoutsByDateRange(
        start: weekStart,
        end: weekEnd,
        type: dbType,
      );

      double distKm = 0;
      for (final wk in workouts) {
        if (_progressFilter == 'walk') {
          // Hanya hitung sesi running berjarak pendek sebagai walking
          if (wk.type == 'running' && (wk.distance ?? 0) <= 2.0) {
            distKm += wk.distance ?? 0;
          }
        } else {
          distKm += wk.distance ?? 0;
        }
      }

      points.add(_WeekPoint(weekStart: weekStart, distanceKm: distKm));
    }

    if (mounted) {
      setState(() {
        _twelveWeekData = points;
        _twelveWeekLoading = false;
      });
    }
  }

  void _onProgressFilterChanged(String f) {
    if (_progressFilter == f) return;
    setState(() => _progressFilter = f);
    _loadTwelveWeekData();
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

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
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
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5406)))
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildDynamicMetrics(),
                  ),
                  SizedBox(height: 32),
                  _build7DayBarChart(),
                  SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildSummaryCard(),
                  ),
                  SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Screenshot(
                      controller: _screenshotController,
                      child: Container(
                        padding: const EdgeInsets.all(24),
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
            ),
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
              // ── Filter pills: Run | Walk ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    _buildProgressPill(
                      label: 'Lari',
                      icon: Icons.directions_run_rounded,
                      key: 'run',
                    ),
                    const SizedBox(width: 10),
                    _buildProgressPill(
                      label: 'Jalan',
                      icon: Icons.directions_walk_rounded,
                      key: 'walk',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── Date range & stats ─────────────────────────────────────
              _buildProgressStats(),

              const SizedBox(height: 8),

              // ── 12-week line chart ─────────────────────────────────────
              _buildTwelveWeekChart(),

              // ── See more button ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5406),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50)),
                      elevation: 0,
                    ),
                    child: const Text(
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.transparent
              : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isActive ? const Color(0xFFFF5406) : AppTheme.border,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? const Color(0xFFFF5406) : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFFFF5406) : AppTheme.textSecondary,
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
    // Hitung stats untuk minggu yang sedang dipilih (minggu ini)
    final currentWeekPoint = _twelveWeekData.isNotEmpty
        ? _twelveWeekData.last
        : null;
    final now = DateTime.now();
    final thisMonday = now.subtract(Duration(days: (now.weekday - 1) % 7));
    final thisSunday = thisMonday.add(const Duration(days: 6));

    // Format tanggal range
    final monthStart = DateFormat('MMM d').format(thisMonday);
    final yearEnd = DateFormat('MMM d, yyyy').format(thisSunday);

    // Hitung total jarak & durasi minggu ini dari _weekWorkouts
    final m = _computeWeekMetrics();
    final distStr = m.distance < 0.01
        ? '0 km'
        : '${m.distance.toStringAsFixed(2)} km';
    final timeStr = m.duration < 1
        ? '0m'
        : m.duration >= 60
            ? '${(m.duration ~/ 60)}h ${(m.duration % 60).round()}m'
            : '${m.duration.round()}m';
    final elevStr = '${m.elevation.round()} m';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$monthStart - $yearEnd',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _progressStatItem('Distance', distStr),
              const SizedBox(width: 24),
              _progressStatItem('Time', timeStr),
              const SizedBox(width: 24),
              _progressStatItem('Elev Gain', elevStr),
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
        const SizedBox(height: 2),
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
    if (_twelveWeekLoading || _twelveWeekData.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
            child: CircularProgressIndicator(
                color: Color(0xFFFF5406), strokeWidth: 2)),
      );
    }

    // Nilai max untuk skala Y
    final maxKm = _twelveWeekData.fold(0.0,
        (m, p) => p.distanceKm > m ? p.distanceKm : m);
    final yMax = maxKm < 1.0 ? 2.0 : (maxKm * 1.4).ceilToDouble();
    // Y-axis labels: 0, yMax/2, yMax — dibulatkan ke 0.5 terdekat
    final yMid = (yMax / 2).roundToDouble();

    // Buat spot untuk LineChart
    final spots = List.generate(
      _twelveWeekData.length,
      (i) => FlSpot(i.toDouble(), _twelveWeekData[i].distanceKm),
    );

    // Indeks minggu saat ini (index ke-11, terakhir)
    const currentWeekX = 11.0;

    // Cari bulan-bulan yang muncul di 12 minggu ini (untuk label X)
    final Set<int> shownMonths = {};
    final Map<int, String> monthLabels = {};
    for (int i = 0; i < _twelveWeekData.length; i++) {
      final month = _twelveWeekData[i].weekStart.month;
      if (!shownMonths.contains(month)) {
        shownMonths.add(month);
        monthLabels[i] = DateFormat('MMM').format(_twelveWeekData[i].weekStart).toUpperCase();
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            // ── LineChart ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(right: 44),
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 11,
                  minY: 0,
                  maxY: yMax,
                  clipData: const FlClipData.all(),
                  backgroundColor: AppTheme.surface,

                  // Grid — hanya 2 garis horizontal
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yMid,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppTheme.textPrimary.withOpacity(0.08),
                      strokeWidth: 1,
                    ),
                  ),

                  borderData: FlBorderData(show: false),

                  // Titles
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
                          final idx = value.toInt();
                          if (!monthLabels.containsKey(idx)) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              monthLabels[idx]!,
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Extra lines: garis vertikal untuk "minggu ini"
                  extraLinesData: ExtraLinesData(
                    verticalLines: [
                      VerticalLine(
                        x: currentWeekX,
                        color: AppTheme.textPrimary.withOpacity(0.45),
                        strokeWidth: 1.5,
                        dashArray: null,
                      ),
                    ],
                  ),

                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppTheme.surfaceVariant,
                      getTooltipItems: (spots) => spots.map((s) {
                        return LineTooltipItem(
                          '${s.y.toStringAsFixed(2)} km',
                          const TextStyle(
                              color: Color(0xFFFF5406),
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        );
                      }).toList(),
                    ),
                  ),

                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: const Color(0xFFFF5406),
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, pct, bar, idx) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFFFF5406),
                          strokeWidth: 0,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFFFF5406).withOpacity(0.35),
                            const Color(0xFFFF5406).withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Y-axis labels di kanan (0 km, yMid km, yMax km) ──────────
            Positioned(
              right: 0,
              top: 0,
              bottom: 28,
              width: 48,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${yMax.toStringAsFixed(yMax == yMax.truncate() ? 0 : 1)} km',
                    style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${yMid.toStringAsFixed(yMid == yMid.truncate() ? 0 : 1)} km',
                    style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '0 km',
                    style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    final accent = isAll ? const Color(0xFFFF5406) : _filterColors[_selectedFilter]!;

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
                  color: Colors.grey,
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
    final accent = isAll ? const Color(0xFFFF5406) : _filterColors[_selectedFilter]!;

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
              color: Colors.grey.withOpacity(0.08),
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
                                  color: Colors.grey,
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
                color: const Color(0xFFFF5406),
              ),
            ),
            Container(width: 1, height: 50, color: const Color(0xFFE8E8E8)),
            Expanded(
              child: _summaryMetric(
                label: 'Aktivitas',
                value: '$totalSessions',
                suffix: 'sesi',
                color: const Color(0xFF00B33F),
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
              color: const Color(0xFFFF5406),
            ),
          ),
          Container(width: 1, height: 50, color: const Color(0xFFE8E8E8)),
          Expanded(
            child: _summaryMetric(
              label: 'Total Aktivitas',
              value: '$_totalWorkoutsMonth',
              suffix: 'sesi',
              color: const Color(0xFF00B33F),
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
                  color: Colors.grey,
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
                color: Colors.grey,
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
                        color: Colors.grey,
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
                        color: Colors.grey,
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
                          color: Colors.grey,
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
                                : const Color(0xFFFF5406))
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
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
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

  // ── 7. Monthly Protein Trend (existing, kept) ────────────────────────────
  Widget _buildMonthlyLinearChart() {
    int daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    List<BarChartGroupData> barGroups = [];

    for (int i = 1; i <= daysInMonth; i++) {
      final stat = _dailyStats[i]!;
      final progress = (stat['protein'] / _targetProtein).clamp(0.0, 1.2);
      final gglWarn =
          stat['sugar'] > 50 || stat['salt'] > 5 || stat['fat'] > 67;

      Color barColor;
      if (progress < 0.9 || gglWarn) {
        barColor = const Color(0xFFFF3400);
      } else if (progress >= 1.0) {
        barColor = const Color(0xFF00B33F);
      } else {
        barColor = Colors.yellow[600]!;
      }

      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: progress,
            color: barColor,
            width: 12,
            borderRadius: BorderRadius.circular(6),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 1.2,
              color: AppTheme.surfaceVariant,
            ),
          ),
        ],
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text('Tren Protein Bulanan',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ),
        SizedBox(height: 24),
        SizedBox(
          height: 180,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: daysInMonth * 24.0,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppTheme.textPrimary,
                      getTooltipItem: (group, gi, rod, ri) {
                        return BarTooltipItem(
                          'Tgl ${group.x}\n${(rod.toY * 100).toInt()}%',
                          TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value % 5 != 0 &&
                              value != 1 &&
                              value != daysInMonth) return SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(value.toInt().toString(),
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
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
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 0.9,
                        color: Colors.grey.withOpacity(0.3),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 4, bottom: 4),
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                          labelResolver: (_) => 'Target',
                        ),
                      ),
                    ],
                  ),
                  barGroups: barGroups,
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
      color = const Color(0xFFFF5406);
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
      color = const Color(0xFF00B33F);
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
                sugarWarn ? const Color(0xFFFF3400) : Colors.grey,
                isWarning: sugarWarn),
            _statRow('Garam', '${stat['salt'].toStringAsFixed(1)}g',
                saltWarn ? const Color(0xFFFF3400) : Colors.grey,
                isWarning: saltWarn),
            _statRow('Lemak', '${stat['fat'].toStringAsFixed(1)}g',
                fatWarn ? const Color(0xFFFF3400) : Colors.grey,
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
                    color: Colors.grey,
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

/// Data point untuk 12-week line chart — satu per minggu.
class _WeekPoint {
  final DateTime weekStart;
  final double distanceKm;

  const _WeekPoint({required this.weekStart, required this.distanceKm});
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
