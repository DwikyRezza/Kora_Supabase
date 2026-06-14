import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import '../models/workout.dart';
import '../services/database_helper.dart';
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

  Future<void> _refreshData() async {
    try {
      await CloudSyncService.restoreAllFromCloud();
    } catch (_) {} 
    await _loadData();
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: const [
            Text('Aktivitas ', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF00B33F), letterSpacing: -1)),
            Text('Latihan', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF2F2F2F), letterSpacing: -1)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.sync, color: Color(0xFF2F2F2F), size: 28), tooltip: 'Import Strava', onPressed: () => _importFromStrava(context)),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF2F2F2F), size: 28),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingScreen())),
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF00B33F),
                indicatorWeight: 4,
                labelColor: const Color(0xFF2F2F2F),
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                tabs: const [
                  Tab(text: 'Progress'),
                  Tab(text: 'Riwayat'),
                ],
              ),
              Container(height: 1, color: const Color(0xFFF5F5F5)),
            ],
          ),
        ),
      ),
      floatingActionButton: null,
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
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00B33F)));

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
                _filterChip('Angkat Beban', 'weightlifting'),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('30 Hari Terakhir', style: TextStyle(color: Color(0xFF2F2F2F), fontWeight: FontWeight.bold, fontSize: 20)),
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
                  style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 24),
                Container(
                  height: 240,
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: _buildBarChart(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Container(height: 8, color: const Color(0xFFF5F5F5)),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('MMMM yyyy').format(DateTime.now()), style: const TextStyle(color: Color(0xFF2F2F2F), fontSize: 18, fontWeight: FontWeight.bold)),
                    _shareButton(),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _streakStat('Konsistensi', '10 Minggu', showFire: true),
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
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00B33F)));
    if (_workouts.isEmpty) return const Center(child: Text('Belum ada aktivitas.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF00B33F),
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100, top: 16),
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
        margin: const EdgeInsets.only(bottom: 16, right: 24, left: 24),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFF3400),
          borderRadius: BorderRadius.circular(26),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 30),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            title: const Text('Hapus Aktivitas?', style: TextStyle(color: Color(0xFF2F2F2F), fontWeight: FontWeight.bold)),
            content: const Text('Aktivitas ini akan dihapus secara permanen.', style: TextStyle(color: Colors.grey)),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Hapus', style: TextStyle(color: Color(0xFFFF3400), fontWeight: FontWeight.bold))),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        if (workout.id != null) {
          await _db.deleteWorkout(workout.id!);
          await CloudSyncService.deleteWorkout(workout.id!);
          _loadData();
        }
      },
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutDetailScreen(workout: workout))).then((_) => _loadData());
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(workout.typeIcon, size: 20, color: const Color(0xFF00B33F)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userName.isNotEmpty ? _userName : 'Atlet', style: const TextStyle(color: Color(0xFF2F2F2F), fontWeight: FontWeight.bold)),
                      Text(
                        '${DateFormat('dd MMM yyyy').format(workout.date)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 20),
              Text(workout.type.substring(0, 1).toUpperCase() + workout.type.substring(1), style: const TextStyle(color: Color(0xFF2F2F2F), fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (workout.distance != null && workout.distance! > 0) _actStat('Jarak', '${workout.distance!.toStringAsFixed(2)} km'),
                  if (workout.type == 'running') _actStat('Pace', '${_calcPace(workout)} /km'),
                  _actStat('Waktu', _formatMins(workout.duration)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(color: Color(0xFF2F2F2F), fontSize: 16, fontWeight: FontWeight.bold)),
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
            color: isSelected ? const Color(0xFF00B33F).withOpacity(0.1) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF00B33F) : const Color(0xFF2F2F2F), 
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
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Color(0xFF2F2F2F), fontWeight: FontWeight.w900, fontSize: 18)),
      ],
    );
  }

  Widget _streakStat(String label, String value, {bool showFire = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
        Row(
          children: [
            Text(value, style: const TextStyle(color: Color(0xFF2F2F2F), fontSize: 20, fontWeight: FontWeight.bold)),
            if (showFire) ...const [
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
        Share.share('Check out my activity progress on Kora!');
      },
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(26)),
        child: Row(
          children: const [
            Icon(Icons.share_rounded, size: 16, color: Color(0xFF2F2F2F)),
            SizedBox(width: 6),
            Text('Bagikan', style: TextStyle(color: Color(0xFF2F2F2F), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    List<BarChartGroupData> barGroups = [];
    int i = 0;
    
    double target = _activeTypeFilter == 'weightlifting' ? 2000.0 : 5.0;
    
    _weeklyStats.forEach((dateStr, val) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: const Color(0xFF00B33F),
              width: 16,
              borderRadius: BorderRadius.circular(8),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: target * 1.5 > val ? target * 1.5 : val * 1.2,
                color: Colors.white, // background track for bar
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
        barGroups: barGroups, // <-- Ini yang terlupa
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => const Color(0xFF2F2F2F),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
               return BarTooltipItem(
                 '${rod.toY.toStringAsFixed(1)}',
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
              getTitlesWidget: (v, m) {
                final dateStr = _weeklyStats.keys.elementAt(v.toInt());
                final dt = DateTime.parse(dateStr);
                final dayName = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'][dt.weekday - 1];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(dayName, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFC5200),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.link_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 24),
              const Text('Strava Sync', style: TextStyle(color: Color(0xFF2F2F2F), fontWeight: FontWeight.bold, fontSize: 22)),
              const SizedBox(height: 8),
              const Text(
                'Hubungkan aplikasi dengan token Strava.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: TextField(
                  controller: tokenController,
                  style: const TextStyle(color: Color(0xFF2F2F2F), fontSize: 14),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Tempel Refresh Token...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                    prefixIcon: Icon(Icons.vpn_key_rounded, color: Color(0xFFFC5200), size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFC5200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: const Text('Hubungkan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || tokenController.text.trim().isEmpty) return;

    try {
      await StravaService.saveRefreshToken(tokenController.text.trim());
      if (!mounted) return;
      await _doStravaSync(context);
    } catch (e) {
      await StravaService.clearAllTokens();
    }
  }

  Future<void> _doStravaSync(BuildContext context) async {
    try {
      await StravaService.importRecentActivities();
      _loadData();
    } catch (e) {
      await StravaService.clearAllTokens();
    }
  }

  void showWorkoutSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 32, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 32),
              const Text('Mulai Latihan', style: TextStyle(color: Color(0xFF2F2F2F), fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              
              _buildBoldGatewayCard(
                context,
                title: 'Lari / Jalan (GPS)',
                subtitle: 'Lacak rute & pace',
                icon: Icons.directions_run_rounded,
                accentColor: const Color(0xFF00B33F),
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
                title: 'Angkat Beban',
                subtitle: 'Gym log',
                icon: Icons.fitness_center_rounded,
                accentColor: const Color(0xFFFF5406),
                onTap: () async {
                  Navigator.pop(context);
                  final profile = await ProfileService.getProfile();
                  final weight = profile[ProfileService.keyWeight] ?? 70.0;
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkoutSetupScreen(userWeight: weight))).then((_) => _loadData());
                },
              ),
              const SizedBox(height: 16),
              
              _buildBoldGatewayCard(
                context,
                title: 'Import Strava',
                subtitle: 'Sinkronisasi otomatis',
                icon: Icons.sync_rounded,
                accentColor: const Color(0xFF00A9DD),
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(child: Icon(icon, color: accentColor, size: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Color(0xFF2F2F2F), fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
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
