import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout.dart';
import '../models/protein_entry.dart';
import '../models/schedule_event.dart';
import '../services/database_helper.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/common_widgets.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onGoToWorkout;
  final VoidCallback onGoToProtein;
  final VoidCallback onGoToSchedule;
  final VoidCallback onGoToBodyStats;

  const HomeScreen({
    super.key,
    required this.onGoToWorkout,
    required this.onGoToProtein,
    required this.onGoToSchedule,
    required this.onGoToBodyStats,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper();
  List<Workout> _todayWorkouts = [];
  List<ProteinEntry> _todayProtein = [];
  List<ScheduleEvent> _upcomingEvents = [];
  bool _isLoading = true;
  String _userName = '';
  double _baseTargetProtein = 0.0;

  double get _totalProteinToday =>
      _todayProtein.fold(0, (sum, e) => sum + e.proteinGrams);
  double get _totalProteinNeeded => _baseTargetProtein;
  int get _totalCaloriesToday =>
      _todayWorkouts.fold(0, (sum, w) => sum + w.caloriesBurned);
  int get _totalWorkoutMinutes =>
      _todayWorkouts.fold(0, (sum, w) => sum + w.duration.round());

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final today = DateTime.now();
    try {
      final workouts = await _db.getWorkoutsByDate(today);
      final protein = await _db.getProteinEntriesByDate(today);
      final events = await _db.getUpcomingEvents();
      final profile = await ProfileService.getProfile();
      
      if (mounted) {
        setState(() {
          _todayWorkouts = workouts;
          _todayProtein = protein;
          _upcomingEvents = events;
          _userName = profile[ProfileService.keyName] ?? '';
          _baseTargetProtein = profile[ProfileService.keyTargetProtein] ?? 0.0;
        });
      }
    } catch (e) {
      debugPrint("Error loading home data: \$e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Selamat Pagi'
        : now.hour < 17
            ? 'Selamat Siang'
            : 'Selamat Malam';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.neonGreen,
        backgroundColor: AppTheme.surface,
        child: CustomScrollView(
          slivers: [
            // ---- APP BAR ----
            SliverAppBar(
              expandedHeight: 170,
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.background,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  padding: EdgeInsets.fromLTRB(context.spaceLG, 60, context.spaceLG, context.spaceMD),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$greeting, ${_userName.isNotEmpty ? _userName : "Atlet"}! 👋',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: context.fontSM,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      AppTheme.neonGreenGrad.createShader(bounds),
                                  child: Text(
                                    'Corefit',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: context.font2XL,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              AppTheme.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              color: AppTheme.textSecondary,
                              size: 22,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            onPressed: () {
                              setState(() {
                                AppTheme.toggleTheme();
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: widget.onGoToBodyStats,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.monitor_weight_rounded, color: AppTheme.electricBlue, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Cek Tubuh',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_isLoading)
              SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.neonGreen),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(context.spaceLG, 0, context.spaceLG, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ---- PROTEIN SYNC BANNER ----
                    _buildProteinSyncBanner(),
                    const SizedBox(height: 20),

                    // ---- STATS GRID ----
                    const SectionHeader(title: 'Ringkasan Hari Ini'),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                label: 'Nutrisi Dikonsumsi',
                                value: _totalProteinToday.toStringAsFixed(1),
                                unit: 'g',
                                icon: Icons.restaurant_menu_rounded,
                                gradient: AppTheme.neonGreenGrad,
                                subtitle: 'Target: ${_totalProteinNeeded.toStringAsFixed(1)}g',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                label: 'Kalori Terbakar',
                                value: _totalCaloriesToday.toString(),
                                unit: 'kal',
                                icon: Icons.local_fire_department_rounded,
                                gradient: AppTheme.orangeGrad,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                label: 'Durasi Latihan',
                                value: _totalWorkoutMinutes.toString(),
                                unit: 'menit',
                                icon: Icons.timer_rounded,
                                gradient: AppTheme.electricBlueGrad,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                label: 'Sesi Latihan',
                                value: _todayWorkouts.length.toString(),
                                unit: 'sesi',
                                icon: Icons.fitness_center_rounded,
                                gradient: AppTheme.purpleGrad,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ---- QUICK ACTIONS ----
                    const SectionHeader(title: 'Aksi Cepat'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickAction(
                            icon: Icons.directions_run,
                            label: 'Catat\nLatihan',
                            color: AppTheme.electricBlue,
                            onTap: widget.onGoToWorkout,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildQuickAction(
                            icon: Icons.restaurant,
                            label: 'Catat\nNutrisi',
                            color: AppTheme.neonGreen,
                            onTap: widget.onGoToProtein,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildQuickAction(
                            icon: Icons.calendar_today,
                            label: 'Tambah\nJadwal',
                            color: AppTheme.accentPurple,
                            onTap: widget.onGoToSchedule,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ---- UPCOMING EVENTS ----
                    SectionHeader(
                      title: 'Jadwal Mendatang',
                      action: 'Lihat Semua',
                      onAction: widget.onGoToSchedule,
                    ),
                    const SizedBox(height: 12),
                    if (_upcomingEvents.isEmpty)
                      _buildEmptyState(
                        'Belum ada jadwal',
                        'Tambahkan jadwal latihan atau makan',
                        Icons.event_note_rounded,
                      )
                    else
                      ...(_upcomingEvents.take(3).map((e) => _buildEventTile(e))),
                    const SizedBox(height: 24),

                    // ---- TODAY WORKOUTS ----
                    SectionHeader(
                      title: 'Latihan Hari Ini',
                      action: 'Tambah',
                      onAction: widget.onGoToWorkout,
                    ),
                    const SizedBox(height: 12),
                    if (_todayWorkouts.isEmpty)
                      _buildEmptyState(
                        'Belum ada latihan',
                        'Mulai catat sesi latihan kamu!',
                        Icons.fitness_center_rounded,
                      )
                    else
                      ...(_todayWorkouts.map((w) => _buildWorkoutTile(w))),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProteinSyncBanner() {
    final deficit = _totalProteinNeeded - _totalProteinToday;
    final isSufficient = deficit <= 0;
    final progress = _totalProteinNeeded > 0
        ? (_totalProteinToday / _totalProteinNeeded).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSufficient 
            ? (AppTheme.isDarkMode ? const Color(0xFF0D3320) : const Color(0xFFE8F5E9))
            : (AppTheme.isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFE3F2FD)),
        gradient: AppTheme.isDarkMode ? LinearGradient(
          colors: isSufficient
              ? [const Color(0xFF0D3320), const Color(0xFF0A2918)]
              : [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ) : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSufficient
              ? AppTheme.neonGreen.withOpacity(0.4)
              : AppTheme.electricBlue.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isSufficient ? AppTheme.neonGreen : AppTheme.electricBlue)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isSufficient ? Icons.check_circle : Icons.bolt,
                  size: 20,
                  color: isSufficient ? AppTheme.neonGreen : AppTheme.electricBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSufficient
                          ? 'Protein Tercukupi!'
                          : 'Sinkronisasi Protein',
                      style: TextStyle(
                        color: AppTheme.isDarkMode ? Colors.white : (isSufficient ? Colors.green[800] : Colors.blue[900]),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isSufficient
                          ? 'Protein harian terpenuhi '
                          : 'Butuh ${deficit.toStringAsFixed(1)}g protein lagi',
                      style: TextStyle(
                        color: isSufficient
                            ? AppTheme.neonGreen
                            : AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: isSufficient 
                      ? (AppTheme.isDarkMode ? AppTheme.neonGreen : Colors.green[700])
                      : (AppTheme.isDarkMode ? AppTheme.electricBlue : Colors.blue[800]),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                isSufficient ? AppTheme.neonGreen : AppTheme.electricBlue,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${_totalProteinToday.toStringAsFixed(1)}g dikonsumsi',
                style: TextStyle(
                    color: AppTheme.textMuted, fontSize: 11),
              ),
              const Spacer(),
              Text(
                'Target: ${_totalProteinNeeded.toStringAsFixed(1)}g',
                style: TextStyle(
                    color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: context.spaceLG),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(context.radiusMD),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: context.iconMD, color: color),
            SizedBox(height: context.spaceXS),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: context.fontXS,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTile(ScheduleEvent event) {
    final isToday = event.dateTime.day == DateTime.now().day;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(event.typeIcon, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isToday ? 'Hari ini' : DateFormat('d MMM', 'id').format(event.dateTime)}, ${DateFormat('HH:mm').format(event.dateTime)} • ${event.durationMinutes} menit',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.neonGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.neonGreen.withOpacity(0.3)),
            ),
            child: Text(
              isToday ? 'Hari ini' : 'Segera',
              style: TextStyle(
                color: AppTheme.neonGreen,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutTile(Workout w) {
    Color typeColor;
    switch (w.type) {
      case 'running':
        typeColor = AppTheme.runningColor;
        break;
      case 'basketball':
        typeColor = AppTheme.basketballColor;
        break;
      default:
        typeColor = AppTheme.weightliftingColor;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: typeColor.withOpacity(0.3)),
            ),
            child: Center(
              child: Icon(w.typeIcon, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  w.typeLabel,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${w.duration.round()} menit • ${w.caloriesBurned} kal',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${w.proteinNeeded.toStringAsFixed(1)}g',
                style: TextStyle(
                  color: typeColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'protein needed',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 40),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
