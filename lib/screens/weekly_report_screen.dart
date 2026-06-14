import 'dart:io';
import 'package:flutter/material.dart';
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

  static const _filterColors = {
    'all': Color(0xFF2F2F2F),
    'running': Color(0xFF00B33F),
    'walking': Color(0xFF0099F9),
    'weightlifting': Color(0xFFFF5406),
  };

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _playFireSound();
    _loadData();
    _loadWorkoutData();
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFF2F2F2F)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Aktivitas Latihan',
            style: TextStyle(
                color: Color(0xFF2F2F2F),
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded,
                color: Color(0xFF2F2F2F), size: 22),
            onPressed: _shareReport,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5406)))
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildFilterChips(),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildDynamicMetrics(),
                  ),
                  const SizedBox(height: 32),
                  _build7DayBarChart(),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildSummaryCard(),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Screenshot(
                      controller: _screenshotController,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Column(
                          children: [
                            _buildStreakHero(),
                            const SizedBox(height: 24),
                            _buildAiryFireGrid(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildMonthlyLinearChart(),
                  const SizedBox(height: 32),
                  _buildAssistantEvaluation(),
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
    final isCardio =
        _selectedFilter == 'running' || _selectedFilter == 'walking';
    final accent = _filterColors[_selectedFilter]!;

    if (isCardio) {
      return Row(children: [
        Expanded(
            child: _metricBox('Jarak', '${m.distance.toStringAsFixed(2)} km',
                Icons.straighten, accent)),
        const SizedBox(width: 12),
        Expanded(
            child: _metricBox('Durasi', '${m.duration.round()} m',
                Icons.timer_outlined, accent)),
        const SizedBox(width: 12),
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
        const SizedBox(width: 12),
        Expanded(
            child: _metricBox('Durasi', '${m.duration.round()} m',
                Icons.timer_outlined, accent)),
        const SizedBox(width: 12),
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
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2F2F2F))),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
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
    final accent = _filterColors[_selectedFilter]!;

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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
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
              style: const TextStyle(
                  color: Color(0xFF2F2F2F),
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
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
                        return BarTooltipItem('', const TextStyle());
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
                              style: const TextStyle(
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
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: align == TextAlign.right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: align == TextAlign.right
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1)),
              const SizedBox(width: 4),
              Text(suffix,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color.withOpacity(0.75))),
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
        const Text('CURRENT STREAK',
            style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Lottie.asset('assets/lottie/fire_streak.json',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Text('🔥', style: TextStyle(fontSize: 40))),
            ),
            const SizedBox(width: 8),
            Text('$_currentStreak',
                style: const TextStyle(
                    color: Color(0xFF2F2F2F),
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2)),
          ],
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                const Text('Best Streak',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('$_bestStreak',
                    style: const TextStyle(
                        color: Color(0xFF2F2F2F),
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                const Text('Konsistensi',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('${_consistencyScore.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: Color(0xFF2F2F2F),
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
                style: const TextStyle(
                    color: Color(0xFF2F2F2F),
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Row(children: [
              IconButton(
                icon: const Icon(Icons.chevron_left,
                    color: Color(0xFF2F2F2F)),
                onPressed: () {
                  setState(() {
                    _currentMonth =
                        DateTime(_currentMonth.year, _currentMonth.month - 1);
                    _loadData();
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right,
                    color: Color(0xFF2F2F2F)),
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
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekdays
              .map((w) => SizedBox(
                  width: 30,
                  child: Text(w,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.grey,
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
                            style: const TextStyle(fontSize: 22)),
                      ),
                    )
                  else
                    Container(
                      decoration: const BoxDecoration(
                          color: Color(0xFFF5F5F5), shape: BoxShape.circle),
                      child: Center(
                        child: Text('$day',
                            style: const TextStyle(
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
                        decoration: const BoxDecoration(
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
              color: const Color(0xFFF5F5F5),
            ),
          ),
        ],
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text('Tren Protein Bulanan',
              style: TextStyle(
                  color: Color(0xFF2F2F2F),
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 24),
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
                      getTooltipColor: (_) => const Color(0xFF2F2F2F),
                      getTooltipItem: (group, gi, rod, ri) {
                        return BarTooltipItem(
                          'Tgl ${group.x}\n${(rod.toY * 100).toInt()}%',
                          const TextStyle(
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
                              value != daysInMonth) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(value.toInt().toString(),
                                style: const TextStyle(
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
                          style: const TextStyle(
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
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('The Intelligent Coach',
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(msg,
                    style: const TextStyle(
                        color: Color(0xFF2F2F2F),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
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
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text(
                '${day} ${DateFormat('MMMM yyyy').format(_currentMonth)}',
                style: const TextStyle(
                    color: Color(0xFF2F2F2F),
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _statRow('Protein', '${stat['protein'].toStringAsFixed(1)}g',
                const Color(0xFFBD4BE5)),
            _statRow('Kalori', '${stat['calories'].toStringAsFixed(0)} kcal',
                const Color(0xFFFF3400)),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF5F5F5), thickness: 2),
            const SizedBox(height: 16),
            _statRow('Gula', '${stat['sugar'].toStringAsFixed(1)}g',
                sugarWarn ? const Color(0xFFFF3400) : Colors.grey,
                isWarning: sugarWarn),
            _statRow('Garam', '${stat['salt'].toStringAsFixed(1)}g',
                saltWarn ? const Color(0xFFFF3400) : Colors.grey,
                isWarning: saltWarn),
            _statRow('Lemak', '${stat['fat'].toStringAsFixed(1)}g',
                fatWarn ? const Color(0xFFFF3400) : Colors.grey,
                isWarning: fatWarn),
            const SizedBox(height: 24),
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
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            if (isWarning) ...[
              const SizedBox(width: 8),
              const Icon(Icons.warning_amber_rounded,
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
