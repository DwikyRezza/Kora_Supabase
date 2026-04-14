import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import '../models/workout.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../services/profile_service.dart';
import '../services/strava_service.dart';
import 'running_tracker_screen.dart';
import 'weightlifting_screen.dart';
import 'workout_detail_screen.dart';
import 'profile_screen.dart';
import 'setting_screen.dart';

class WorkoutScreen extends StatefulWidget {
  WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper();
  List<Workout> _workouts = [];
  Map<String, double> _weeklyStats = {};
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
    final weekly = await _db.getWeeklyWorkoutStats(_activeTypeFilter);
    final profile = await ProfileService.getProfile();
    if (mounted) {
      setState(() {
        _workouts = workouts;
        _weeklyStats = weekly;
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
        title: Text('Athlete Sync', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.background,
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.surfaceVariant,
              child: Text('👤'),
            ),
          ),
          IconButton(icon: Icon(Icons.sync, color: AppTheme.textPrimary), tooltip: 'Import Strava', onPressed: () => _importFromStrava(context)),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: AppTheme.textPrimary),
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'workoutFab',
        onPressed: () => _showWorkoutSelectionSheet(context),
        backgroundColor: Color(0xFFFC5200),
        child: Icon(Icons.add, color: Colors.white, size: 30),
      ),
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
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterChip('🏃 Run', 'running'),
                _filterChip('🚶 Walk', 'walking'),
                _filterChip('🏋️ Workout', 'weightlifting'),
              ],
            ),
          ),
          SizedBox(height: 24),

          // Summary Section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last 30 Days', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                SizedBox(height: 16),
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

          SizedBox(height: 32),

          // Chart Section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Past 7 Days (km)', style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                SizedBox(height: 24),
                Container(
                  height: 200,
                  width: double.infinity,
                  child: LineChart(_buildChartData()),
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
    return Column(
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
                    CircleAvatar(backgroundColor: AppTheme.surfaceVariant, child: Text(workout.typeEmoji)),
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
              Text('🔥', style: TextStyle(fontSize: 18)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _shareButton() {
    return InkWell(
      onTap: () {
        Share.share('Check out my activity progress on AthleteSync! I have a 10 week streak! 🔥');
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

  LineChartData _buildChartData() {
    List<FlSpot> spots = [];
    int i = 0;
    _weeklyStats.forEach((date, val) {
      spots.add(FlSpot(i.toDouble(), val));
      i++;
    });

    return LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 5, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey[900]!, strokeWidth: 1)),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: TextStyle(color: Colors.grey, fontSize: 10)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, m) {
              if (v.toInt() % 3 == 0) return Padding(padding: EdgeInsets.only(top: 8), child: Text('Day ${v.toInt()}', style: TextStyle(color: Colors.grey, fontSize: 10)));
              return SizedBox();
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Color(0xFFFC5200),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: Color(0xFFFC5200).withOpacity(0.2)),
        ),
      ],
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
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(children: [
          Text('🔗', style: TextStyle(fontSize: 36)),
          SizedBox(height: 8),
          Text('Hubungkan Strava', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFFC5200).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Color(0xFFFC5200).withOpacity(0.3)),
              ),
              child: Text(
                '1. Buka strava.com/settings/api\n2. Cari "Token Muat Ulang" (bukan Token Akses!)\n3. Salin & tempel di bawah ini',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.6),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: tokenController,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Tempel Refresh Token di sini...',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Batal', style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFC5200), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Simpan & Sinkron', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || tokenController.text.trim().isEmpty) return;

    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      content: Row(children: [
        CircularProgressIndicator(color: Color(0xFFFC5200)),
        SizedBox(width: 16),
        Text('Memvalidasi token...', style: TextStyle(color: AppTheme.textPrimary)),
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
          content: Text('❌ Token tidak valid! Salin "Token Muat Ulang", BUKAN "Token Akses" dari strava.com/settings/api'),
          backgroundColor: AppTheme.accentRed,
          duration: Duration(seconds: 6),
        ),
      );
    }
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
          content: Text('🔄 Sesi Strava habis. Coba Import lagi dan masukkan Refresh Token baru dari strava.com/settings/api'),
          backgroundColor: AppTheme.accentOrange,
          duration: Duration(seconds: 7),
        ),
      );
    }
  }

  void _showWorkoutSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(bottom: 30, top: 20, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
              SizedBox(height: 24),
              Text('Pilih Jenis Latihan', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
              SizedBox(height: 32),
              _menuItem(context, 'Lari (GPS Tracker)', 'Pantau rute dan jarak tempuh aslimu', '🏃', AppTheme.runningColor, () async {
                Navigator.pop(context);
                final profile = await ProfileService.getProfile();
                final weight = profile[ProfileService.keyWeight] ?? 70.0;
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => RunningTrackerScreen(userWeight: weight))).then((_) => _loadData());
              }),

              SizedBox(height: 16),
              _menuItem(context, 'Angkat Beban', 'Catat Reps, Sets, Beban', '🏋️', AppTheme.weightliftingColor, () async {
                Navigator.pop(context);
                final profile = await ProfileService.getProfile();
                final weight = profile[ProfileService.keyWeight] ?? 70.0;
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => WeightliftingScreen(userWeight: weight))).then((_) => _loadData());
              }),
              SizedBox(height: 16),
              _menuItem(context, 'Import dari Strava', 'Sinkronkan data lari/sepeda dari cloud', '🔗', Color(0xFFFC5200), () async {
                Navigator.pop(context);
                _importFromStrava(context);
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _menuItem(BuildContext context, String title, String subtitle, String emoji, Color accent, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
        child: Row(
          children: [
            Container(
              width: 55, height: 55,
              decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(emoji, style: TextStyle(fontSize: 28))),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.border, size: 20),
          ],
        ),
      ),
    );
  }
}
