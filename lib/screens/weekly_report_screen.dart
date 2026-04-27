import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../models/protein_entry.dart';
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
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isLoading = true;
  int _currentStreak = 0;
  int _bestStreak = 0;
  double _consistencyScore = 0.0;
  int _streakFreezeCount = 0;
  List<int> _frozenDays = [];
  
  double _targetProtein = 150.0;

  DateTime _currentMonth = DateTime.now();
  Map<int, Map<String, dynamic>> _dailyStats = {};

  @override
  void initState() {
    super.initState();
    _playFireSound();
    _loadData();
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final profile = await ProfileService.getProfile();
    _targetProtein = profile[ProfileService.keyTargetProtein] ?? 150.0;
    if (_targetProtein == 0) _targetProtein = 150.0;

    final entries = await _db.getProteinEntriesByMonth(_currentMonth.year, _currentMonth.month);
    
    Map<int, Map<String, dynamic>> stats = {};
    int daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    
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
      if (e.date.year == _currentMonth.year && e.date.month == _currentMonth.month) {
        int day = e.date.day;
        stats[day]!['protein'] += e.proteinGrams;
        stats[day]!['calories'] += e.calories;
        stats[day]!['sugar'] += e.sugarGrams;
        stats[day]!['salt'] += e.saltGrams;
        stats[day]!['fat'] += e.fatGrams;
      }
    }

    // Streak calculation with Freeze logic
    int currentStreak = 0;
    int bestStreak = 0;
    int successDays = 0;
    int availableFreeze = profile[ProfileService.keyStreakFreezeCount] ?? 0;
    List<int> frozenDays = [];

    daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    int daysPassed = DateTime.now().day;
    if (_currentMonth.month != DateTime.now().month || _currentMonth.year != DateTime.now().year) {
      daysPassed = daysInMonth;
    }

    for (int i = 1; i <= daysPassed; i++) {
      double p = stats[i]!['protein'];
      if (p >= _targetProtein * 0.9) {
        currentStreak++;
        successDays++;
        if (currentStreak > bestStreak) bestStreak = currentStreak;
      } else {
        // Cek apakah bisa pakai Es Batu
        if (availableFreeze > 0 && i < daysPassed) {
          availableFreeze--;
          frozenDays.add(i);
          currentStreak++; // Streak tetap lanjut
          if (currentStreak > bestStreak) bestStreak = currentStreak;
        } else {
          if (i < DateTime.now().day || _currentMonth.month != DateTime.now().month) {
            currentStreak = 0; // reset
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _dailyStats = stats;
        _currentStreak = currentStreak;
        _bestStreak = bestStreak;
        _streakFreezeCount = availableFreeze;
        _frozenDays = frozenDays;
        _consistencyScore = daysPassed > 0 ? (successDays / daysPassed) * 100 : 0.0;
        _isLoading = false;
      });
    }
  }

  void _showDayDetail(int day, Map<String, dynamic> stat) {
    bool sugarWarn = stat['sugar'] > 50.0;
    bool saltWarn = stat['salt'] > 5.0;
    bool fatWarn = stat['fat'] > 67.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(
              '${day} ${DateFormat('MMMM yyyy').format(_currentMonth)}',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _statRow('Protein', '${stat['protein'].toStringAsFixed(1)}g', AppTheme.neonGreen),
            _statRow('Kalori', '${stat['calories'].toStringAsFixed(0)} kcal', AppTheme.accentOrange),
            const SizedBox(height: 16),
            Divider(color: AppTheme.border),
            const SizedBox(height: 16),
            _statRow('Gula', '${stat['sugar'].toStringAsFixed(1)}g', sugarWarn ? AppTheme.accentRed : AppTheme.textMuted, isWarning: sugarWarn),
            _statRow('Garam', '${stat['salt'].toStringAsFixed(1)}g', saltWarn ? AppTheme.accentRed : AppTheme.textMuted, isWarning: saltWarn),
            _statRow('Lemak', '${stat['fat'].toStringAsFixed(1)}g', fatWarn ? AppTheme.accentRed : AppTheme.textMuted, isWarning: fatWarn),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, Color color, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
              if (isWarning) ...[
                const SizedBox(width: 8),
                Icon(Icons.warning_amber_rounded, color: AppTheme.accentRed, size: 16),
              ]
            ],
          ),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text('The Hall of Consistency', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            color: AppTheme.electricBlue,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('Exporting report...'), backgroundColor: AppTheme.electricBlue),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.accentOrange))
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderStats(),
                  const SizedBox(height: 32),
                  _buildAiryFireGrid(),
                  const SizedBox(height: 32),
                  _buildMonthlyLinearChart(),
                  const SizedBox(height: 24),
                  _buildAssistantEvaluation(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text('CURRENT STREAK', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Lottie.asset(
                  'assets/lottie/fire_streak.json',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Text('🔥', style: TextStyle(fontSize: 48)),
                ),
              ),
              const SizedBox(width: 12),
              Text('$_currentStreak', style: TextStyle(color: AppTheme.textPrimary, fontSize: 64, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      Text('Best Streak', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('$_bestStreak', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      Text('Consistency', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('${_consistencyScore.toStringAsFixed(0)}%', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiryFireGrid() {
    int daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    int firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; // 1=Mon, 7=Sun

    List<String> weekdays = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: AppTheme.textMuted),
                    onPressed: () {
                      setState(() {
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                        _loadData();
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: AppTheme.textMuted),
                    onPressed: () {
                      if (_currentMonth.month == DateTime.now().month && _currentMonth.year == DateTime.now().year) return;
                      setState(() {
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                        _loadData();
                      });
                    },
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdays.map((w) => SizedBox(width: 30, child: Text(w, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600)))).toList(),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 16,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              int day = index - firstWeekday + 2;
              if (day < 1 || day > daysInMonth) {
                return const SizedBox();
              }

              final stat = _dailyStats[day]!;
              final progress = stat['protein'] / _targetProtein;
              final isSuccess = progress >= 0.9;
              final isFrozen = _frozenDays.contains(day);
              final gglWarn = stat['sugar'] > 50 || stat['salt'] > 5 || stat['fat'] > 67;

              return GestureDetector(
                onTap: () => _showDayDetail(day, stat),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isSuccess || isFrozen)
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isFrozen ? Colors.lightBlueAccent : AppTheme.accentOrange).withOpacity(0.4),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          isFrozen ? '🧊' : '🔥',
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    Text(
                      '$day',
                      style: TextStyle(
                        color: isSuccess ? Colors.white : AppTheme.textMuted.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (isSuccess && gglWarn)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyLinearChart() {
    int daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    List<BarChartGroupData> barGroups = [];

    for (int i = 1; i <= daysInMonth; i++) {
      final stat = _dailyStats[i]!;
      final progress = (stat['protein'] / _targetProtein).clamp(0.0, 1.2); // Cap visually at 120%
      final gglWarn = stat['sugar'] > 50 || stat['salt'] > 5 || stat['fat'] > 67;

      Color barColor;
      if (progress < 0.9 || gglWarn) {
        barColor = AppTheme.accentRed; // Failed or GGL Warning
      } else if (progress >= 1.0) {
        barColor = AppTheme.neonGreen; // Perfect
      } else {
        barColor = Colors.yellow[600]!; // Toleransi 90-99%
      }

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: progress,
              color: barColor,
              width: 8,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: 1.2,
                color: AppTheme.surfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Tren Bulanan', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 150,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: daysInMonth * 20.0,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => AppTheme.surface,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          'Tgl ${group.x}\n${(rod.toY * 100).toInt()}%',
                          TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
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
                          if (value % 5 != 0 && value != 1 && value != daysInMonth) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(value.toInt().toString(), style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
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
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 0.9,
                        color: Colors.white.withOpacity(0.3),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 4, bottom: 4),
                          style: const TextStyle(color: Colors.white, fontSize: 9),
                          labelResolver: (_) => 'Target 90%',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssistantEvaluation() {
    int gglFails = 0;
    for (int i = 1; i <= 31; i++) {
      if (_dailyStats.containsKey(i)) {
        var s = _dailyStats[i]!;
        if (s['sugar'] > 50 || s['salt'] > 5 || s['fat'] > 67) gglFails++;
      }
    }

    String msg = '';
    IconData icon = Icons.sentiment_neutral;
    Color color = AppTheme.electricBlue;

    if (_currentStreak >= 15) {
      msg = '$_currentStreak hari tanpa putus! Kamu sedang di jalur yang benar, Rezza. Jangan biarkan godaan akhir pekan memadamkan apimu!';
      icon = Icons.local_fire_department;
      color = AppTheme.accentOrange;
    } else if (_consistencyScore < 50 && _currentStreak < 3) {
      msg = 'Apimu padam beberapa kali belakangan ini. Jangan biarkan satu hari malas merusak progres sebulan. Bangkit lagi!';
      icon = Icons.warning_amber_rounded;
      color = AppTheme.accentRed;
    } else if (gglFails > 5) {
      msg = 'Streak harianmu cukup aman, tapi konsumsi GGL-mu bulan ini tinggi ($gglFails hari jebol). Perbaiki kualitas makananmu di bulan depan.';
      icon = Icons.health_and_safety_rounded;
      color = Colors.yellow[700]!;
    } else {
      msg = 'Konsistensimu terjaga dengan baik di ${_consistencyScore.toStringAsFixed(0)}%. Tetap pertahankan ritme ini!';
      icon = Icons.thumb_up_alt_rounded;
      color = AppTheme.neonGreen;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('The Intelligent Coach', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(msg, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
