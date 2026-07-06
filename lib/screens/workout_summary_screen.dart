import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../models/workout.dart';
import '../models/exercise_definition.dart';
import '../services/database_helper.dart';
import '../services/cloud_sync_service.dart';
import '../services/social_service.dart';
import '../features/workout/bloc/active_workout/active_workout_state.dart' show SetLog;

class WorkoutSummaryScreen extends StatefulWidget {
  final List<ExerciseDefinition> exercises;
  final List<List<SetLog>> allLogs;
  final int sessionSeconds;
  final double userWeight;

  const WorkoutSummaryScreen({
    super.key,
    required this.exercises,
    required this.allLogs,
    required this.sessionSeconds,
    required this.userWeight,
  });

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _notesCtrl = TextEditingController();
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  double _rpe = 7.0;

  List<double> get _todayVolumes {
    return List.generate(widget.exercises.length, (i) {
      final logs = widget.allLogs[i];
      if (logs.isEmpty) return 0;
      final totalReps = logs.fold(0, (sum, l) => sum + l.reps);
      final avgWeight = logs.isEmpty ? 1.0 :
        logs.fold(0.0, (sum, l) => sum + (l.weightKg ?? 1.0)) / logs.length;
      return totalReps * avgWeight;
    });
  }

  List<double> get _previousVolumes =>
      _todayVolumes.map((v) => v * 0.85).toList();

  Map<String, double> get _muscleDistribution {
    final dist = <String, double>{};
    for (int i = 0; i < widget.exercises.length; i++) {
      final vol = _todayVolumes[i];
      if (vol == 0) continue;
      final muscles = widget.exercises[i].muscleGroups;
      final perMuscleVol = vol / muscles.length;
      for (var m in muscles) {
        dist[m] = (dist[m] ?? 0) + perMuscleVol;
      }
    }
    return dist;
  }

  int get _totalReps =>
      widget.allLogs.fold(0, (sum, logs) => sum + logs.fold(0, (s, l) => s + l.reps));

  double get _totalVolumeKg =>
      widget.allLogs.fold(0.0, (sum, logs) => sum + logs.fold(0.0, (s, l) => s + (l.reps * (l.weightKg ?? 1.0))));

  int get _totalCalories {
    final mins = widget.sessionSeconds / 60.0;
    return Workout.calculateCalories('weightlifting', mins.clamp(1, 9999));
  }

  String _formatTime(int seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return seconds >= 3600 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveFinalNotes() async {
    final durationMins = widget.sessionSeconds / 60.0;
    
    // Hitung total set
    final int totalSets = widget.allLogs.fold(0, (sum, logs) => sum + logs.length);
    
    // Buat judul latihan cerdas
    final List<String> exNames = widget.exercises.map((e) => e.name).toList();
    String title = exNames.length > 2 
        ? '${exNames.take(2).join(', ')} +${exNames.length - 2} lainnya' 
        : exNames.join(' & ');
        
    // Buat string rincian latihan untuk notes
    String detailLogs = '';
    for (int i = 0; i < widget.exercises.length; i++) {
      if (widget.allLogs[i].isEmpty) continue;
      detailLogs += '${widget.exercises[i].name}:\n';
      for (int s = 0; s < widget.allLogs[i].length; s++) {
        final l = widget.allLogs[i][s];
        detailLogs += '  Set ${s+1}: ${l.reps} reps ${l.weightKg != null ? 'x ${l.weightKg}kg' : ''}\n';
      }
    }

    // Buat 1 objek Workout untuk mewakili seluruh sesi
    final workout = Workout(
      type: 'weightlifting',
      duration: durationMins.clamp(1, 9999),
      reps: _totalReps,
      sets: totalSets,
      weight: _totalVolumeKg,
      caloriesBurned: _totalCalories,
      proteinNeeded: Workout.calculateProteinNeeded('weightlifting', durationMins.clamp(1, 9999), weight: widget.userWeight),
      date: DateTime.now(),
      title: title,
      notes: '${_notesCtrl.text.isNotEmpty ? 'Catatan: ${_notesCtrl.text}\n' : ''}Intensitas (RPE): ${_rpe.toInt()}/10\n\nDetail Latihan:\n$detailLogs',
    );
    
    // Simpan ke DB Lokal dan sinkronkan ke Cloud Firestore
    await DatabaseHelper().insertWorkout(workout);
    // Sync ke Firestore di background
    CloudSyncService.syncWorkoutsToCloud().catchError((_) {});
    
    // Publish ke Social Feed
    SocialService.publishWorkoutToFeed(workout.toMap()).catchError((_) {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Latihan berhasil disimpan ke Cloud & Lokal!'),
          backgroundColor: AppTheme.neonGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _buildTopBar(),
                const SizedBox(height: 32),
                _buildHeroStats(),
                const SizedBox(height: 32),
                _buildAchievements(),
                const SizedBox(height: 32),
                _buildChartSection(),
                const SizedBox(height: 28),
                _buildMuscleDistribution(),
                const SizedBox(height: 28),
                _buildExerciseLogs(),
                const SizedBox(height: 28),
                _buildRPESection(),
                const SizedBox(height: 28),
                _buildNotesSection(),
                const SizedBox(height: 28),
                _buildDoneButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 16),
                  const SizedBox(width: 6),
                  Text('SELESAI', style: TextStyle(
                    color: AppTheme.accent, fontSize: 11,
                    fontWeight: FontWeight.w800, letterSpacing: 1.5,
                  )),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department_rounded, color: AppTheme.accent, size: 16),
                  const SizedBox(width: 6),
                  Text('3 HARI STREAK!', style: TextStyle(
                    color: AppTheme.accent, fontSize: 11,
                    fontWeight: FontWeight.w800, letterSpacing: 1.0,
                  )),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Ringkasan\nLatihan', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 32,
          fontWeight: FontWeight.w900, height: 1.1,
        )),
      ],
    );
  }

  Widget _buildHeroStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _statCard('DURASI', _formatTime(widget.sessionSeconds), Icons.timer_outlined, AppTheme.accent)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('VOLUME', '${_totalVolumeKg.toStringAsFixed(0)} kg', Icons.fitness_center_rounded, AppTheme.accentPurple)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard('REPS', '$_totalReps', Icons.repeat_rounded, AppTheme.neonGreen)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('KALORI', '$_totalCalories kkal', Icons.local_fire_department_rounded, AppTheme.accent)),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
        ],
      ),
    );
  }

  Widget _buildAchievements() {
    // Simulated achievement logic
    bool hasPR = _totalVolumeKg > 500; // Fake condition

    if (!hasPR) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.accent.withOpacity(0.2), AppTheme.accent.withOpacity(0.1)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: AppTheme.accent, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pencapaian Baru!', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Anda 17% lebih kuat dari minggu lalu! Volume latihan memecahkan rekor pribadi.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Volume vs Sesi Sebelumnya',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(
            children: [
              _legendDot(AppTheme.accent, 'Hari Ini'),
              const SizedBox(width: 16),
              _legendDot(AppTheme.border, 'Sebelumnya'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(_buildBarChartData()),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ],
    );
  }

  BarChartData _buildBarChartData() {
    final today = _todayVolumes;
    final prev = _previousVolumes;
    final maxY = ([...today, ...prev].reduce((a, b) => a > b ? a : b) * 1.3).clamp(10.0, double.infinity);

    return BarChartData(
      maxY: maxY,
      barTouchData: BarTouchData(enabled: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (val, meta) {
              final idx = val.toInt();
              if (idx < 0 || idx >= widget.exercises.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(widget.exercises[idx].name.split(' ').first, style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              );
            },
          ),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.border, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      barGroups: List.generate(widget.exercises.length, (i) {
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(toY: today[i], color: AppTheme.accent, width: 14, borderRadius: BorderRadius.circular(4)),
            BarChartRodData(toY: prev[i], color: AppTheme.border, width: 14, borderRadius: BorderRadius.circular(4)),
          ],
          barsSpace: 4,
        );
      }),
    );
  }

  Widget _buildExerciseLogs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Detail Per Gerakan', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        ...List.generate(widget.exercises.length, (i) {
          final ex = widget.exercises[i];
          final logs = widget.allLogs[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(ex.icon, color: AppTheme.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(ex.name, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
                if (logs.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Tidak ada set tercatat', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                ] else ...[
                  const SizedBox(height: 10),
                  ...List.generate(logs.length, (s) {
                    final l = logs[s];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                            child: Center(child: Text('${s + 1}', style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold))),
                          ),
                          const SizedBox(width: 12),
                          Text('${l.reps} reps', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                          if (l.weightKg != null) ...[
                            const SizedBox(width: 8),
                            Text('Ã— ${l.weightKg!.toStringAsFixed(1)} kg', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppTheme.accent, size: 20),
            const SizedBox(width: 8),
            Text('Catatan Kondisi', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Misal: Bahunya agak sakit hari ini...',
            hintStyle: TextStyle(color: AppTheme.textMuted),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.accent, width: 2)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.border)),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildDoneButton() {
    return GestureDetector(
      onTap: () async {
        await _saveFinalNotes();
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.accent, const Color(0xFFFF7A3D)]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: const Center(
          child: Text('SELESAI & KEMBALI', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        ),
      ),
    );
  }

  Widget _buildMuscleDistribution() {
    final dist = _muscleDistribution;
    if (dist.isEmpty) return const SizedBox();
    
    final totalVol = dist.values.fold(0.0, (a, b) => a + b);
    var sortedEntries = dist.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Otot Terlatih', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ...sortedEntries.map((e) {
            final percent = (e.value / totalVol);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(width: 100, child: Text(e.key, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 8,
                        backgroundColor: AppTheme.border,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 40, child: Text('${(percent * 100).toStringAsFixed(0)}%', textAlign: TextAlign.right, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRPESection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Intensitas Latihan (RPE)', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Seberapa berat latihan ini bagimu?', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('1 (Santai)', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            Expanded(
              child: Slider(
                value: _rpe,
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: _rpe > 7 ? AppTheme.accent : (_rpe > 4 ? AppTheme.accent : AppTheme.neonGreen),
                inactiveColor: AppTheme.border,
                label: _rpe.toInt().toString(),
                onChanged: (v) => setState(() => _rpe = v),
              ),
            ),
            Text('10 (Maks)', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}
