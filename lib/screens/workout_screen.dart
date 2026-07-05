import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import '../models/workout.dart';
import '../services/database_helper.dart';
import '../services/profile_service.dart';
import '../services/cloud_sync_service.dart';
import '../features/running/presentation/screens/running_screen.dart';
import 'workout_setup_screen.dart';
import 'weekly_report_screen.dart';
import '../services/social_service.dart';
import '../services/auth_service.dart';
import '../widgets/feed_post_card.dart';
import '../utils/responsive.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => WorkoutScreenState();
}

class WorkoutScreenState extends State<WorkoutScreen> with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper();
  List<Workout> _workouts = [];
  Map<String, double> _weeklyStats = {};
  Map<String, int> _weeklySets = {};
  Map<String, double> _weeklyPace = {};
  bool _isLoading = true;
  late TabController _tabController;
  String _activeTypeFilter = 'running';
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    try {
      await CloudSyncService.syncWorkoutsToCloud();
    } catch (_) {}
    await _loadData();
  }

  List<Map<String, dynamic>> _userPosts = [];

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    
    // Gunakan getAllWorkouts agar perhitungan streak tidak terputus di 50 aktivitas terakhir
    final workouts = await _db.getAllWorkouts();
    final profile = await ProfileService.getProfile();
    
    List<Map<String, dynamic>> userPosts = [];
    if (AuthService.isLoggedIn) {
      userPosts = await SocialService.getUserPosts(AuthService.uid);
    }
    
    final now = DateTime.now();
    Map<String, double> weekly = {};
    Map<String, int> weeklySets = {};
    Map<String, double> weeklyPace = {};
    Map<String, int> weeklyCount = {};
    
    for (int i = 6; i >= 0; i--) {
      final dateStr = now.subtract(Duration(days: i)).toIso8601String().split('T')[0];
      weekly[dateStr] = 0.0;
      weeklySets[dateStr] = 0;
      weeklyPace[dateStr] = 0.0;
      weeklyCount[dateStr] = 0;
    }
    
    for (var w in workouts) {
      if (w.type == _activeTypeFilter) {
        final dStr = w.date.toIso8601String().split('T')[0];
        if (weekly.containsKey(dStr)) {
          weeklyCount[dStr] = weeklyCount[dStr]! + 1;
          if (_activeTypeFilter == 'weightlifting') {
             double vol = (w.weight ?? 0) * (w.sets ?? 0) * (w.reps ?? 0);
             if (vol == 0) vol = w.weight ?? 0;
             weekly[dStr] = weekly[dStr]! + vol;
             weeklySets[dStr] = weeklySets[dStr]! + (w.sets ?? 0);
          } else {
             weekly[dStr] = weekly[dStr]! + (w.distance ?? 0);
             if (w.distance != null && w.distance! > 0) {
               weeklyPace[dStr] = weeklyPace[dStr]! + (w.duration / w.distance!);
             }
          }
        }
      }
    }
    
    for (var key in weeklyPace.keys) {
      if (weeklyCount[key]! > 0) {
         weeklyPace[key] = weeklyPace[key]! / weeklyCount[key]!;
      }
    }

    if (mounted) {
      setState(() {
        _workouts = workouts;
        _userPosts = userPosts;
        _weeklyStats = weekly;
        _weeklySets = weeklySets;
        _weeklyPace = weeklyPace;
        _userName = profile[ProfileService.keyName] as String? ?? '';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Text('Aktivitas ', style: TextStyle(fontSize: context.font3XL, fontWeight: FontWeight.w900, color: AppTheme.accent, letterSpacing: -1)),
            Text('Latihan', style: TextStyle(fontSize: context.font3XL, fontWeight: FontWeight.w900, color: AppTheme.textPrimary, letterSpacing: -1)),
          ],
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.accent,
                indicatorWeight: 4,
                labelColor: AppTheme.textPrimary,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: context.fontMD),
                tabs: const [
                  Tab(text: 'Progress'),
                  Tab(text: 'Aktivitas'),
                ],
              ),
              Container(height: 1, color: AppTheme.surfaceVariant),
            ],
          ),
        ),
      ),
      floatingActionButton: null,
      body: TabBarView(
        controller: _tabController,
        children: [
          const WeeklyReportScreen(embedMode: true),
          _buildActivitiesTab(),
        ],
      ),
    );
  }

  Widget _buildProgressTab() {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: AppTheme.accent));

    double totalDist = 0;
    double totalTime = 0;
    double totalElev = 0;

    final filteredWorkouts = _workouts.where((w) => w.type == _activeTypeFilter).toList();
    for (var w in filteredWorkouts) {
       totalDist += w.distance ?? 0;
       totalTime += w.duration;
       totalElev += w.elevationGain ?? 0;
    }

    final h = (totalTime / 60).truncate();
    final m = totalTime.truncate() % 60;
    final timeStr = h > 0 ? '${h}j ${m}m' : '${m}m';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _filterChip('Lari', 'running'),
                _filterChip('Jalan', 'walking'),
                _filterChip('Workout', 'weightlifting'),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('30 Hari Terakhir', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _miniStat('Jarak', '${totalDist.toStringAsFixed(1)} km'),
                    _miniStat('Durasi', timeStr),
                    _miniStat('Elevasi', '${totalElev.round()} m'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activeTypeFilter == 'weightlifting' ? '7 Hari Terakhir (Volume kg)' : '7 Hari Terakhir (Jarak km)',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 24),
                Container(
                  height: 240,
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: _buildBarChart(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Container(height: 8, color: AppTheme.surfaceVariant),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('MMMM yyyy').format(DateTime.now()), style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    _shareButton(),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _streakStat('Konsistensi', '${_calculateCurrentStreak()} Hari', showFire: true),
                    const SizedBox(width: 48),
                    _streakStat('Total Aktivitas', _workouts.length.toString()),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildActivitiesTab() {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: AppTheme.accent));
    
    final filteredPosts = _userPosts.where((post) {
      final wData = post['workoutData'] as Map<String, dynamic>? ?? {};
      final type = wData['type']?.toString().toLowerCase() ?? 'running';
      return type == _activeTypeFilter;
    }).toList();

    if (filteredPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_run_rounded, size: 64, color: AppTheme.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('Belum ada aktivitas', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text('Mulai berlari atau latihan untuk melihat feed-mu!', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppTheme.accent,
      backgroundColor: AppTheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: filteredPosts.length,
        itemBuilder: (context, index) {
          return FeedPostCard(
            post: filteredPosts[index],
            onDataChanged: () => _loadData(silent: true),
          );
        },
      ),
    );
  }



  List<LatLng> _parsePolyline(String polylineStr) {
    try {
      final List<dynamic> decoded = jsonDecode(polylineStr);
      return decoded.map((p) => LatLng(
        (p[0] as num).toDouble(),
        (p[1] as num).toDouble(),
      )).toList();
    } catch (_) {
      return [];
    }
  }

  Widget _miniCardStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: context.fontXS, fontWeight: FontWeight.w600)),
        SizedBox(height: context.spaceXS),
        Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: context.fontSM, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _actStat(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(right: context.space2XL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: context.fontSM * 0.9, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: context.fontMD, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _calcPace(Workout w) {
    if (w.distance == null || w.distance == 0) return '0:00';
    final paceMins = w.duration / w.distance!;
    final m = paceMins.truncate();
    final s = ((paceMins - m) * 60).truncate().toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatMins(double m) {
    final hr = (m / 60).truncate();
    final mn = m.truncate() % 60;
    if (hr > 0) return '${hr}j ${mn}m';
    return '${mn}m';
  }

  Widget _filterChip(String label, String type) {
    final isSelected = _activeTypeFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          setState(() => _activeTypeFilter = type);
          _loadData();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent.withOpacity(0.1) : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.accent : AppTheme.textPrimary, 
              fontWeight: FontWeight.bold, 
              fontSize: 14
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: context.fontSM, fontWeight: FontWeight.bold)),
        SizedBox(height: context.spaceXS),
        Text(value, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w900, fontSize: context.fontLG)),
      ],
    );
  }

  int _calculateCurrentStreak() {
    if (_workouts.isEmpty) return 0;
    
    final dates = _workouts.map((w) => DateTime(w.date.year, w.date.month, w.date.day)).toSet().toList();
    dates.sort((a, b) => b.compareTo(a));
    
    int streak = 0;
    DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    DateTime yesterday = today.subtract(const Duration(days: 1));
    
    bool hasToday = dates.contains(today);
    bool hasYesterday = dates.contains(yesterday);
    
    if (!hasToday && !hasYesterday) return 0;
    
    DateTime checkDate = hasToday ? today : yesterday;
    
    for (int i = 0; i < dates.length; i++) {
      // Gunakan konstruktor DateTime untuk menghindari bug daylight saving (DST) 
      // yang timbul jika menggunakan subtract(Duration(days: i)).
      DateTime expectedDate = DateTime(checkDate.year, checkDate.month, checkDate.day - i);
      if (dates.contains(expectedDate)) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  Widget _streakStat(String label, String value, {bool showFire = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
        Row(
          children: [
            Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            if (showFire) ...[
              const SizedBox(width: 4),
              const Text('🔥', style: TextStyle(fontSize: 18)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _shareButton() {
    return InkWell(
      onTap: () {
        Share.share('Check out my activity progress on Kora!');
      },
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(26)),
        child: Row(
          children: [
            Icon(Icons.share_rounded, size: 16, color: AppTheme.textPrimary),
            const SizedBox(width: 6),
            Text('Bagikan', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    List<BarChartGroupData> barGroups = [];
    int i = 0;
    double maxVal = 0;
    _weeklyStats.forEach((_, val) {
      if (val > maxVal) maxVal = val;
    });
    
    double target = _activeTypeFilter == 'weightlifting' ? 2000.0 : 5.0;
    double chartMaxY = maxVal > target ? maxVal * 1.2 : target * 1.2;
    
    _weeklyStats.forEach((dateStr, val) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: AppTheme.accent,
              width: 16,
              borderRadius: BorderRadius.circular(8),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: chartMaxY,
                color: const Color(0xFFE0E0E0), // Abu-abu agar terlihat track-nya
              ),
            ),
          ],
        ),
      );
      i++;
    });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: chartMaxY,
        barGroups: barGroups, // <-- Ini yang terlupa
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => AppTheme.textPrimary,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
               return BarTooltipItem(
                 rod.toY.toStringAsFixed(1),
                 const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
               );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30, // Ditambahkan agar teks hari tidak terpotong
              getTitlesWidget: (v, m) {
                final dateStr = _weeklyStats.keys.elementAt(v.toInt());
                final dt = DateTime.parse(dateStr);
                final dayName = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'][dt.weekday - 1];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(dayName, style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
      swapAnimationDuration: const Duration(milliseconds: 300),
      swapAnimationCurve: Curves.easeInOut,
    );
  }

  void showWorkoutSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 32, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 32),
              Text('Mulai Latihan', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              
              _buildBoldGatewayCard(
                context,
                title: 'Lari / Jalan (GPS)',
                subtitle: 'Lacak rute & pace',
                icon: Icons.directions_run_rounded,
                accentColor: AppTheme.accent,
                onTap: () async {
                  Navigator.pop(context);
                  final profile = await ProfileService.getProfile();
                  final weight = profile[ProfileService.keyWeight] ?? 70.0;
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => RunningTrackerScreen(userWeight: weight))).then((_) => _loadData());
                },
              ),
              const SizedBox(height: 16),
              
              _buildBoldGatewayCard(
                context,
                title: 'Workout',
                subtitle: 'Gym log',
                icon: Icons.fitness_center_rounded,
                accentColor: AppTheme.accent,
                onTap: () async {
                  Navigator.pop(context);
                  final profile = await ProfileService.getProfile();
                  final weight = profile[ProfileService.keyWeight] ?? 70.0;
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkoutSetupScreen(userWeight: weight))).then((_) => _loadData());
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBoldGatewayCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
              ),
              child: Center(child: Icon(icon, color: accentColor, size: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: accentColor, size: 24),
          ],
        ),
      ),
    );
  }
}

class MiniRoutePainter extends CustomPainter {
  final List<LatLng> points;
  final Color? _routeColor;

  MiniRoutePainter(this.points, {Color? routeColor}) : _routeColor = routeColor;

  Color get routeColor => _routeColor ?? AppTheme.accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;

    if (latRange == 0 || lngRange == 0) return;

    const padding = 8.0;
    final usableWidth = size.width - (padding * 2);
    final usableHeight = size.height - (padding * 2);

    final scale = usableWidth / lngRange < usableHeight / latRange
        ? usableWidth / lngRange
        : usableHeight / latRange;

    final xOffset = padding + (usableWidth - lngRange * scale) / 2;
    final yOffset = padding + (usableHeight - latRange * scale) / 2;

    Offset getOffset(LatLng p) {
      final x = xOffset + (p.longitude - minLng) * scale;
      final y = size.height - (yOffset + (p.latitude - minLat) * scale);
      return Offset(x, y);
    }

    final paint = Paint()
      ..color = routeColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(getOffset(points.first).dx, getOffset(points.first).dy);
    for (int i = 1; i < points.length; i++) {
      final off = getOffset(points[i]);
      path.lineTo(off.dx, off.dy);
    }
    canvas.drawPath(path, paint);

    final startPaint = Paint()
      ..color = AppTheme.accent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(getOffset(points.first), 4.5, startPaint);

    if (points.length > 1) {
      final endPaint = Paint()
        ..color = AppTheme.accent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(getOffset(points.last), 4.5, endPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MiniRoutePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.routeColor != routeColor;
  }
}
