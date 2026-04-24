import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import '../models/workout.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../services/profile_service.dart';
import '../services/strava_service.dart';
import '../services/cloud_sync_service.dart';
import 'running_tracker_screen.dart';
import 'workout_setup_screen.dart';
import 'workout_detail_screen.dart';
import 'profile_screen.dart';
import 'setting_screen.dart';

class WorkoutScreen extends StatefulWidget {
  WorkoutScreen({super.key});

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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final workouts = await _db.getRecentWorkouts(limit: 50);
    final profile = await ProfileService.getProfile();
    
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Corefit', style: TextStyle(fontSize: context.fontXL, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.background,
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: CircleAvatar(
              radius: context.avatarSM / 2,
              backgroundColor: AppTheme.surfaceVariant,
              child: Text(''),
            ),
          ),
          IconButton(icon: Icon(Icons.sync, color: AppTheme.textPrimary, size: context.iconSM), tooltip: 'Import Strava', onPressed: () => _importFromStrava(context)),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: AppTheme.textPrimary, size: context.iconSM),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingScreen())),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: Color(0xFFFC5200),
                indicatorWeight: 3,
                labelColor: AppTheme.textPrimary,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                tabs: [
                  Tab(text: 'Progress'),
                  Tab(text: 'Activities'),
                ],
              ),
              Divider(height: 1, color: AppTheme.border),
            ],
          ),
        ),
      ),
      floatingActionButton: null, // FAB dipindah ke main.dart
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProgressTab(),
          _buildActivitiesTab(),
        ],
      ),
    );
  }

  Widget _buildProgressTab() {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: Color(0xFFFC5200)));

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
    final timeStr = h > 0 ? '${h}h ${m}m' : '${m}m';

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: context.spaceLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: context.spaceLG),
            child: Row(
              children: [
                _filterChip(' Run', 'running'),
                _filterChip(' Walk', 'walking'),
                _filterChip(' Workout', 'weightlifting'),
              ],
            ),
          ),
          SizedBox(height: context.spaceXL),

          // Summary Section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spaceLG),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last 30 Days', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: context.fontLG)),
                SizedBox(height: context.spaceLG),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _miniStat('Distance', '${totalDist.toStringAsFixed(2)} km'),
                    _miniStat('Time', timeStr),
                    _miniStat('Elev Gain', '${totalElev.round()} m'),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: context.space2XL),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activeTypeFilter == 'weightlifting' ? 'Past 7 Days (Volume kg)' : 'Past 7 Days (Distance km)',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold)
                ),
                SizedBox(height: 24),
                Container(
                  height: 240,
                  width: double.infinity,
                  child: _buildBarChart(),
                ),
              ],
            ),
          ),

          SizedBox(height: 32),

          Center(
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFC5200),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 64, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('See more of your progress', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),

          SizedBox(height: 32),
          Divider(thickness: 8, color: AppTheme.surfaceVariant),

          // Streak Section
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('March 2026', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    _shareButton(),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    _streakStat('Your Streak', '10 Weeks', showFire: true),
                    SizedBox(width: 48),
                    _streakStat('Streak Activities', _workouts.length.toString()),
                  ],
                ),
                SizedBox(height: 24),
                // Calendar Days row (visual placeholder)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) => Text(d, style: TextStyle(color: Colors.grey, fontSize: 12))).toList(),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (i) => Icon(Icons.circle, size: 8, color: i == 3 ? Color(0xFFFC5200) : Colors.grey[800])),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildActivitiesTab() {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: Color(0xFFFC5200)));
    if (_workouts.isEmpty) return Center(child: Text('No activities yet.', style: TextStyle(color: AppTheme.textMuted)));

    return RefreshIndicator(
      onRefresh: _loadData,
      color: Color(0xFFFC5200),
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: 100),
        itemCount: _workouts.length,
        itemBuilder: (context, index) => _activityCard(_workouts[index]),
      ),
    );
  }

  Widget _activityCard(Workout workout) {
    return Dismissible(
      key: Key(workout.id?.toString() ?? UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.accentRed,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 30),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text('Hapus Aktivitas?', style: TextStyle(color: Colors.white)),
            content: const Text('Aktivitas ini akan dihapus secara permanen dari perangkat dan cloud.', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal', style: TextStyle(color: Colors.white70))),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Hapus', style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.bold))),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        if (workout.id != null) {
          await _db.deleteWorkout(workout.id!);
          await CloudSyncService.deleteWorkout(workout.id!);
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Aktivitas berhasil dihapus'),
              backgroundColor: AppTheme.accentRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Column(
        children: [
        InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutDetailScreen(workout: workout))).then((_) => _loadData());
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(backgroundColor: AppTheme.surfaceVariant, child: Icon(workout.typeIcon, size: 24)),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_userName.isNotEmpty ? _userName : 'Athlete', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                        Text(
                          '${DateFormat('MMMM d, yyyy').format(workout.date)} • Strava App',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    )
                  ],
                ),
                SizedBox(height: 16),
                Text(workout.title ?? _workoutTitle(workout), style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
                SizedBox(height: 12),
                Row(
                  children: [
                    if (workout.distance != null) _actStat('Distance', '${workout.distance!.toStringAsFixed(2)} km'),
                    if (workout.type == 'running') _actStat('Pace', '${_calcPace(workout)} /km'),
                    _actStat('Time', _formatMins(workout.duration)),
                  ],
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: AppTheme.border),
      ],
    ),
    );
  }

  Widget _actStat(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(right: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
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
    if (hr > 0) return '${hr}h ${mn}m';
    return '${mn}m';
  }

  /// Generates time-aware fallback title for workouts without a title
  String _workoutTitle(Workout w) {
    final hour = w.date.hour;
    String timeLabel;
    if (hour >= 5 && hour < 10) {
      timeLabel = 'Morning';
    } else if (hour >= 10 && hour < 14) {
      timeLabel = 'Midday';
    } else if (hour >= 14 && hour < 17) {
      timeLabel = 'Afternoon';
    } else if (hour >= 17 && hour < 20) {
      timeLabel = 'Evening';
    } else {
      timeLabel = 'Night';
    }
    switch (w.type) {
      case 'running':       return '$timeLabel Run';
      case 'weightlifting': return '$timeLabel Workout';
      case 'basketball':    return '$timeLabel Basketball';
      case 'walking':       return '$timeLabel Walk';
      default:              return '$timeLabel Activity';
    }
  }

  Widget _filterChip(String label, String type) {
    final isSelected = _activeTypeFilter == type;
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _activeTypeFilter = type);
          _loadData();
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.transparent : AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? Color(0xFFFC5200) : AppTheme.border, width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(color: isSelected ? Color(0xFFFC5200) : AppTheme.textPrimary, fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
        ),
      ],
    );
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
              SizedBox(width: 4),
              Text('', style: TextStyle(fontSize: 18)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _shareButton() {
    return InkWell(
      onTap: () {
        Share.share('Check out my activity progress on AthleteSync! I have a 10 week streak! ');
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Icon(Icons.share_outlined, size: 16, color: AppTheme.textPrimary),
            SizedBox(width: 4),
            Text('Share', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    List<BarChartGroupData> barGroups = [];
    int i = 0;
    
    double target = _activeTypeFilter == 'weightlifting' ? 2000.0 : 5.0; // 2000kg or 5km
    
    final gradientColors = [
      AppTheme.accentOrange, // Bottom (#FF9800)
      AppTheme.accentRed,    // Top (#FF1744)
    ];

    _weeklyStats.forEach((dateStr, val) {
      final dt = DateTime.parse(dateStr);
      final dayName = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'][dt.weekday - 1];
      
      bool hitTarget = val >= target;
      
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              width: 22,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: target * 1.5 > val ? target * 1.5 : val * 1.2,
                color: AppTheme.surfaceVariant,
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
        maxY: target * 1.5,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => AppTheme.surface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
               final dateStr = _weeklyStats.keys.elementAt(group.x);
               final dt = DateTime.parse(dateStr);
               final dayName = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'][dt.weekday - 1];
               
               if (_activeTypeFilter == 'weightlifting') {
                  int sets = _weeklySets[dateStr] ?? 0;
                  return BarTooltipItem(
                    '$dayName\n$sets Set | Volume: ${rod.toY.toInt()} kg',
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  );
               } else {
                  double pace = _weeklyPace[dateStr] ?? 0.0;
                  int pm = pace.truncate();
                  int ps = ((pace - pm) * 60).truncate();
                  String pStr = '$pm:${ps.toString().padLeft(2, '0')}';
                  return BarTooltipItem(
                    '$dayName\n${rod.toY.toStringAsFixed(1)} km | Pace: $pStr',
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  );
               }
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) {
                final dateStr = _weeklyStats.keys.elementAt(v.toInt());
                final dt = DateTime.parse(dateStr);
                final dayName = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'][dt.weekday - 1];
                return Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(dayName, style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: target,
              color: Colors.white.withOpacity(0.4),
              strokeWidth: 1.5,
              dashArray: [5, 5],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                padding: EdgeInsets.only(right: 4, bottom: 4),
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                labelResolver: (_) => 'Target ${target.toInt()} ${_activeTypeFilter == 'weightlifting' ? 'kg' : 'km'}',
              ),
            ),
          ],
        ),
      ),
      swapAnimationDuration: Duration(milliseconds: 300),
      swapAnimationCurve: Curves.easeInOut,
    );
  }

  Future<void> _importFromStrava(BuildContext context) async {
    final hasToken = await StravaService.hasRefreshToken();
    if (!hasToken) {
      await _showRefreshTokenSetupDialog(context);
      return;
    }
    await _doStravaSync(context);
  }

  Future<void> _showRefreshTokenSetupDialog(BuildContext context) async {
    final tokenController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFC5200).withOpacity(0.3)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFC5200).withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFC5200).withOpacity(0.4), width: 2),
                ),
                child: const Icon(Icons.link_rounded, color: Color(0xFFFC5200), size: 32),
              ),
              const SizedBox(height: 16),
              Text('Hubungkan ke Strava', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 20)),
              const SizedBox(height: 8),
              Text(
                'Izinkan Corefit mengakses data aktivitas Strava kamu',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildStravaStep('1', 'Buka strava.com/settings/api di browser'),
              const SizedBox(height: 8),
              _buildStravaStep('2', 'Scroll ke bawah, cari bagian "Your API Application"'),
              const SizedBox(height: 8),
              _buildStravaStep('3', 'Salin nilai "Refresh Token" (BUKAN Access Token)'),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFC5200).withOpacity(0.4)),
                ),
                child: TextField(
                  controller: tokenController,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Tempel Refresh Token di sini...',
                    hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    prefixIcon: const Icon(Icons.vpn_key_rounded, color: Color(0xFFFC5200), size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Batal', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.sync_rounded, color: Colors.white, size: 18),
                      label: const Text('Hubungkan & Sinkron', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFC5200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || tokenController.text.trim().isEmpty) return;

    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Row(children: [
        const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Color(0xFFFC5200), strokeWidth: 2.5)),
        const SizedBox(width: 16),
        Text('Menghubungkan ke Strava...', style: TextStyle(color: AppTheme.textPrimary)),
      ]),
    ));

    try {
      await StravaService.saveRefreshToken(tokenController.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      await _doStravaSync(context);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      await StravaService.clearAllTokens();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ Token tidak valid! Pastikan kamu menyalin "Refresh Token" dari strava.com/settings/api'),
          backgroundColor: AppTheme.accentRed,
          duration: Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildStravaStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFFFC5200).withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFC5200).withOpacity(0.5)),
          ),
          child: Center(
            child: Text(number, style: const TextStyle(color: Color(0xFFFC5200), fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
        ),
      ],
    );
  }

  Future<void> _doStravaSync(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Color(0xFFFC5200), strokeWidth: 2.5)),
          SizedBox(width: 14),
          Text('Menarik data Strava...', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
        ]),
        content: Text('Mengambil aktivitas terbaru dari akun Strava Anda.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      ),
    );

    try {
      final importedCount = await StravaService.importRecentActivities();
      if (!mounted) return;
      Navigator.pop(context);

      if (importedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Semua aktivitas Strava sudah tersinkronkan sebelumnya.'), backgroundColor: AppTheme.accentOrange),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ $importedCount aktivitas Strava baru berhasil disinkronkan!'), backgroundColor: AppTheme.neonGreen, duration: Duration(seconds: 4)),
        );
      }
      _loadData();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      await StravaService.clearAllTokens();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(' Sesi Strava habis. Coba Import lagi dan masukkan Refresh Token baru dari strava.com/settings/api'),
          backgroundColor: AppTheme.accentOrange,
          duration: Duration(seconds: 7),
        ),
      );
    }
  }

  void showWorkoutSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.border, width: 1),
          ),
          padding: EdgeInsets.only(bottom: 30, top: 16, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
              SizedBox(height: 24),
              Text('Pilih Jenis Latihan', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
              SizedBox(height: 32),
              
              // 1. GPS Tracker (Run/Walk)
              _buildBoldGatewayCard(
                context,
                title: 'Outdoor Activity',
                subtitle: 'Lacak rute & pace secara real-time',
                icon: Icons.directions_run_rounded,
                accentColor: AppTheme.neonGreen,
                onTap: () async {
                  Navigator.pop(context);
                  final profile = await ProfileService.getProfile();
                  final weight = profile[ProfileService.keyWeight] ?? 70.0;
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => RunningTrackerScreen(userWeight: weight))).then((_) => _loadData());
                },
              ),
              SizedBox(height: 16),
              
              // 2. Gym Log (Weightlifting)
              _buildBoldGatewayCard(
                context,
                title: 'Strength Training',
                subtitle: 'Pilih Mode, Otot, & Gerakan',
                icon: Icons.fitness_center_rounded,
                accentColor: AppTheme.accentOrange,
                onTap: () async {
                  Navigator.pop(context);
                  final profile = await ProfileService.getProfile();
                  final weight = profile[ProfileService.keyWeight] ?? 70.0;
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkoutSetupScreen(userWeight: weight))).then((_) => _loadData());
                },
              ),
              SizedBox(height: 16),
              
              // 3. Third Party
              _buildBoldGatewayCard(
                context,
                title: 'Import dari Strava',
                subtitle: 'Sinkronkan data dari cloud',
                icon: Icons.sync_rounded,
                accentColor: AppTheme.electricBlue,
                isSmall: true,
                onTap: () {
                  Navigator.pop(context);
                  _importFromStrava(context);
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
    bool isSmall = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(isSmall ? 16 : 24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: isSmall ? 40 : 60,
              height: isSmall ? 40 : 60,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(child: Icon(icon, color: accentColor, size: isSmall ? 20 : 32)),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: AppTheme.textPrimary, fontSize: isSmall ? 16 : 20, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: AppTheme.textMuted, fontSize: isSmall ? 12 : 14)),
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
