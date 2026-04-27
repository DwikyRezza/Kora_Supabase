import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/workout.dart';
import '../models/protein_entry.dart';
import '../models/schedule_event.dart';
import '../services/database_helper.dart';
import '../services/profile_service.dart';
import '../services/whistleblower_service.dart';
import '../theme/app_theme.dart';
import 'dart:async';
import '../utils/responsive.dart';
import '../widgets/common_widgets.dart';
import 'setting_screen.dart';

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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper();
  List<Workout> _todayWorkouts = [];
  List<ProteinEntry> _todayProtein = [];
  List<ScheduleEvent> _upcomingEvents = [];
  bool _isLoading = true;
  String _userName = '';
  double _baseTargetProtein = 0.0;
  DateTime _selectedScheduleDate = DateTime.now();

  late AnimationController _pulseController;
  Timer? _whistleTimer;

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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _whistleTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkWhistleblower();
    });
    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _whistleTimer?.cancel();
    super.dispose();
  }

  void _checkWhistleblower() async {
    final now = DateTime.now();
    // Fetch specifically today's upcoming to ensure we don't miss if UI is on another date
    final events = await _db.getUpcomingEvents();
    for (var event in events) {
      if (event.status == 'pending' &&
          event.dateTime.year == now.year &&
          event.dateTime.month == now.month &&
          event.dateTime.day == now.day &&
          event.dateTime.hour == now.hour &&
          event.dateTime.minute == now.minute) {
        
        WhistleblowerService.playAlarm();
        
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: Row(
              children: [
                Icon(Icons.sports, color: AppTheme.accentOrange),
                SizedBox(width: 8),
                Text('Waktunya Action!', style: TextStyle(color: AppTheme.textPrimary)),
              ],
            ),
            content: Text(
              'Jadwal "${event.title}" telah tiba. Ayo mulai!',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.vibrate();
                  WhistleblowerService.stopAlarm();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.neonGreen),
                child: Text('OK', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        );
        break; // Only play once per minute
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final today = DateTime.now();
    try {
      await _db.checkLateSchedules();
      final workouts = await _db.getWorkoutsByDate(today);
      final protein = await _db.getProteinEntriesByDate(today);
      // Fetch events for selected date
      final events = await _db.getScheduleEventsByDate(_selectedScheduleDate);
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
      debugPrint("Error loading home data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleEventCompletion(ScheduleEvent event, bool? value) async {
    if (value == null) return;
    HapticFeedback.lightImpact();
    await _db.updateScheduleEventCompletion(event.id!, value);
    _loadData(); // reload
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.neonGreen,
        backgroundColor: AppTheme.surface,
        child: CustomScrollView(
          slivers: [
            _buildHomeHeader(context),
            if (_isLoading)
              _buildSkeletonLoader(context)
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(context.spaceLG, 0, context.spaceLG, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildProteinSummaryCard(),
                    const SizedBox(height: 20),
                    
                    _buildStatGrid(),
                    const SizedBox(height: 24),
                    
                    _buildQuickActionRow(),
                    const SizedBox(height: 24),
                    
                    _buildUpcomingScheduleList(),
                    const SizedBox(height: 24),

                    // ---- TODAY WORKOUTS ----
                    SectionHeader(
                      title: 'Latihan Hari Ini',
                      action: 'Tambah',
                      onAction: widget.onGoToWorkout,
                    ),
                    const SizedBox(height: 12),
                    if (_todayWorkouts.isEmpty) ...[
                      _buildWorkoutRecommendation(),
                      const SizedBox(height: 12),
                      _buildEmptyState(
                        'Belum ada latihan',
                        'Mulai catat sesi latihan kamu!',
                        Icons.fitness_center_rounded,
                      ),
                    ] else
                      ...(_todayWorkouts.map((w) => _buildWorkoutTile(w))),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeHeader(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 11
        ? 'Selamat Pagi'
        : now.hour < 15
            ? 'Selamat Siang'
            : now.hour < 18
                ? 'Selamat Sore'
                : 'Selamat Malam';

    return SliverAppBar(
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
                            'Kora',
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
                  Row(
                    children: [
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProteinSummaryCard() {
    final gap = _totalProteinNeeded - _totalProteinToday;
    final isSufficient = gap <= 0;
    final progress = _totalProteinNeeded > 0
        ? (_totalProteinToday / _totalProteinNeeded).clamp(0.0, 1.0)
        : 0.0;
    
    final eggs = (gap > 0) ? (gap / 6).ceil() : 0;
    
    String motivationText;
    if (isSufficient) {
      motivationText = 'Target protein tercapai! Kamu luar biasa hari ini.';
    } else if (progress >= 0.5) {
      motivationText = 'Sedikit lagi! Hanya butuh $eggs butir telur untuk capai target.';
    } else {
      motivationText = 'Butuh sekitar $eggs butir telur lagi untuk penuhi ototmu hari ini!';
    }

    // Color logic
    Color progressBarColor;
    if (isSufficient || progress > 0.8) {
      progressBarColor = AppTheme.neonGreen;
    } else {
      progressBarColor = AppTheme.electricBlue;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSufficient 
            ? (AppTheme.isDarkMode ? const Color(0xFF0D3320) : const Color(0xFFE8F5E9))
            : (AppTheme.isDarkMode ? const Color(0xFF16213E) : const Color(0xFFE3F2FD)),
        gradient: AppTheme.isDarkMode ? LinearGradient(
          colors: isSufficient
              ? [const Color(0xFF0D3320), const Color(0xFF0A2918)]
              : [const Color(0xFF16213E), const Color(0xFF1A1A2E)], // Dark Blue to Light Blue
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ) : null,
        borderRadius: BorderRadius.circular(20), // premium
        border: Border.all(
          color: isSufficient
              ? AppTheme.neonGreen.withOpacity(0.4)
              : AppTheme.electricBlue.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: (isSufficient ? AppTheme.neonGreen : AppTheme.electricBlue).withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
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
                      motivationText,
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
                  color: progressBarColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(color: AppTheme.border),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: progressBarColor == AppTheme.neonGreen
                          ? [AppTheme.neonGreen.withOpacity(0.7), AppTheme.neonGreen]
                          : [Colors.blue[700]!, Colors.blue[300]!], // Premium dynamic gradient
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
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

  Widget _buildStatGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Ringkasan Hari Ini'),
        const SizedBox(height: 12),
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
                onTap: widget.onGoToProtein,
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
                onTap: widget.onGoToWorkout,
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
    );
  }

  Widget _buildQuickActionRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Aksi Cepat'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickAction(
                icon: Icons.fitness_center_rounded, // Same as Latihan tab
                label: 'Catat\nLatihan',
                color: AppTheme.electricBlue,
                onTap: widget.onGoToWorkout,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickAction(
                icon: Icons.restaurant_menu_rounded, // Same as Nutrisi tab
                label: 'Catat\nNutrisi',
                color: AppTheme.neonGreen,
                onTap: widget.onGoToProtein,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickAction(
                icon: Icons.calendar_month_rounded, // Same as Jadwal tab
                label: 'Tambah\nJadwal',
                color: AppTheme.accentPurple,
                onTap: widget.onGoToSchedule,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: context.spaceLG),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20), // premium
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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

  Widget _buildUpcomingScheduleList() {
    return _buildScheduleDashboard();
  }

  Widget _buildScheduleDashboard() {
    // 1. Interactive Calendar (Horizontal Date Picker)
    final days = List.generate(7, (i) => DateTime.now().add(Duration(days: i - 3))); // 3 days ago to 3 days future
    
    // Sort events
    final sortedEvents = List<ScheduleEvent>.from(_upcomingEvents)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // Get selected date's events
    final selectedDateEvents = sortedEvents.where((e) {
      return e.dateTime.year == _selectedScheduleDate.year &&
             e.dateTime.month == _selectedScheduleDate.month &&
             e.dateTime.day == _selectedScheduleDate.day;
    }).toList();

    // The Hero Card is the first pending event today. If none, the first event.
    final pendingEvents = selectedDateEvents.where((e) => e.status == 'pending').toList();
    final heroEvent = pendingEvents.isNotEmpty ? pendingEvents.first : (selectedDateEvents.isNotEmpty ? selectedDateEvents.first : null);
    
    final carouselEvents = heroEvent != null 
        ? selectedDateEvents.where((e) => e.id != heroEvent.id).toList()
        : <ScheduleEvent>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'The Personal Assistant',
          action: 'Tambah',
          onAction: widget.onGoToSchedule,
        ),
        const SizedBox(height: 16),
        
        // Horizontal Date Picker
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            itemBuilder: (context, index) {
              final date = days[index];
              final isSelected = date.year == _selectedScheduleDate.year && 
                                 date.month == _selectedScheduleDate.month && 
                                 date.day == _selectedScheduleDate.day;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedScheduleDate = date;
                  });
                  _loadData();
                },
                child: Container(
                  width: 50,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.neonGreen : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? AppTheme.neonGreen : AppTheme.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('E', 'id').format(date),
                        style: TextStyle(
                          color: isSelected ? Colors.black : AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isSelected ? Colors.black : AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        
        // Hero Card
        if (heroEvent != null)
          _buildHeroCard(heroEvent)
        else
          _buildEmptyState('Belum ada jadwal', 'Santai dulu, atau tambah jadwal baru.', Icons.event_note_rounded),
          
        const SizedBox(height: 20),
        
        // Horizontal Carousel
        if (carouselEvents.isNotEmpty) ...[
          Text('Selanjutnya Hari Ini', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: carouselEvents.length,
              itemBuilder: (context, index) {
                return _buildCarouselCard(carouselEvents[index]);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeroCard(ScheduleEvent event) {
    final isFailed = event.status == 'failed';
    final isDone = event.status == 'done';
    
    Color cardColor = AppTheme.surface;
    Color accentColor = AppTheme.neonGreen;
    if (isFailed) {
      cardColor = Colors.redAccent.withOpacity(0.1);
      accentColor = Colors.redAccent;
    } else if (isDone) {
      cardColor = AppTheme.neonGreen.withOpacity(0.1);
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isFailed ? Colors.redAccent.withOpacity(0.5) : AppTheme.border),
        gradient: (!isFailed && !isDone) ? (AppTheme.isDarkMode ? const LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ) : null) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  DateFormat('HH:mm').format(event.dateTime),
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
              if (isFailed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                  child: const Text('GAGAL', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              else if (isDone)
                Icon(Icons.check_circle_rounded, color: AppTheme.neonGreen)
              else
                Icon(event.typeIcon, color: AppTheme.textMuted, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text(event.title, style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
          if (event.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(event.notes, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          if (!isDone && !isFailed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                   if (event.type == 'meal') {
                     _showNutritionCompletionModal(event);
                   } else {
                     _toggleEventCompletion(event, true);
                   }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Selesaikan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCarouselCard(ScheduleEvent event) {
    final isFailed = event.status == 'failed';
    final isDone = event.status == 'done';
    
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isFailed ? Colors.redAccent.withOpacity(0.05) : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isFailed ? Colors.redAccent.withOpacity(0.3) : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('HH:mm').format(event.dateTime),
                style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Icon(isDone ? Icons.check_circle_rounded : event.typeIcon, 
                color: isDone ? AppTheme.neonGreen : (isFailed ? Colors.redAccent : AppTheme.textMuted), 
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            event.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _showNutritionCompletionModal(ScheduleEvent event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Selesaikan Jadwal', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(event.title, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _toggleEventCompletion(event, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Konfirmasi (Sudah Dimakan)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
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
        borderRadius: BorderRadius.circular(16), // premium
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

  Widget _buildWorkoutRecommendation() {
    final recommendations = [
      {'icon': Icons.self_improvement_rounded, 'title': 'Peregangan 5 Menit', 'desc': 'Mulai hari dengan gerakan ringan untuk mengaktifkan otot', 'color': AppTheme.neonGreen},
      {'icon': Icons.directions_walk_rounded, 'title': 'Jalan Santai 10 Menit', 'desc': 'Aktivitas ringan yang menjaga kebugaran sehari-hari', 'color': AppTheme.electricBlue},
      {'icon': Icons.airline_seat_legroom_extra_rounded, 'title': 'Squat & Push-up Ringan', 'desc': '3 set × 10 repetisi untuk pemanasan tubuh', 'color': AppTheme.accentOrange},
    ];

    final rec = recommendations[DateTime.now().weekday % recommendations.length] as Map<String, dynamic>;
    final color = rec['color'] as Color;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16), // premium
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(rec['icon'] as IconData, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'REKOMENDASI',
                        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  rec['title'] as String,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  rec['desc'] as String,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.heavyImpact();
              widget.onGoToWorkout();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Mulai', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.textMuted.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.textMuted.withOpacity(0.5), size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.all(context.spaceLG),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _skeletonBox(height: 180), // Protein Summary
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _skeletonBox(height: 120)),
              const SizedBox(width: 12),
              Expanded(child: _skeletonBox(height: 120)),
            ],
          ),
          const SizedBox(height: 24),
          _skeletonBox(height: 150), // Schedule
          const SizedBox(height: 24),
          _skeletonBox(height: 200), // Recommendations
        ]),
      ),
    );
  }

  Widget _skeletonBox({required double height}) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surface,
      highlightColor: AppTheme.border,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
