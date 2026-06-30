import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../theme/app_theme.dart';
import '../models/workout.dart';
import '../models/exercise_definition.dart';
import '../services/database_helper.dart';
import 'workout_summary_screen.dart';

class SetLog {
  final int reps;
  final double? weightKg;
  final DateTime loggedAt;
  SetLog({required this.reps, this.weightKg, required this.loggedAt});
}

class ActiveWorkoutScreen extends StatefulWidget {
  final List<ExerciseDefinition> exercises;
  final double userWeight;
  final Map<String, int> exerciseSets;

  const ActiveWorkoutScreen({
    super.key,
    required this.exercises,
    required this.userWeight,
    required this.exerciseSets,
  });

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen>
    with TickerProviderStateMixin {
  int _currentExerciseIndex = 0;
  int _currentSet = 1;

  int get _totalSetsPerExercise =>
      widget.exerciseSets[_currentExercise.id] ?? 4;

  int _reps = 10;
  final TextEditingController _weightController =
      TextEditingController(text: '20');

  int _sessionSeconds = 0;
  Timer? _sessionTimer;

  bool _isResting = false;
  int _restSeconds = 45;
  int _restRemaining = 60;
  Timer? _restTimer;
  bool _restAlertFired = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  late List<List<SetLog>> _allLogs;
  late PageController _heroPageController;

  ExerciseDefinition get _currentExercise =>
      widget.exercises[_currentExerciseIndex];
  bool get _isWeightlifting => _currentExercise.category == 'weighted';

  @override
  void initState() {
    super.initState();
    _allLogs = List.generate(widget.exercises.length, (_) => []);
    _heroPageController = PageController(initialPage: _currentExerciseIndex);

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _sessionSeconds++);
    });

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    _pulseCtrl.dispose();
    _weightController.dispose();
    _heroPageController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return seconds >= 3600 ? '$h:$m:$s' : '$m:$s';
  }

  void _changeReps(int delta) {
    HapticFeedback.lightImpact();
    setState(() => _reps = (_reps + delta).clamp(1, 999));
  }

  Future<void> _logSet() async {
    HapticFeedback.mediumImpact();

    final log = SetLog(
      reps: _reps,
      weightKg:
          _isWeightlifting ? double.tryParse(_weightController.text) : null,
      loggedAt: DateTime.now(),
    );
    _allLogs[_currentExerciseIndex].add(log);

    final isLastSet = _currentSet >= _totalSetsPerExercise;
    final isLastExercise = _currentExerciseIndex >= widget.exercises.length - 1;

    if (isLastSet && isLastExercise) {
      _finishWorkout();
      return;
    }

    _startRest(isLastSet: isLastSet);
  }

  // --- Local Notifications for Background Alarm ---
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> _scheduleRestNotification(int delaySeconds) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'Kora_rest_timer',
      'Rest Timer',
      channelDescription: 'Alarm saat istirahat selesai',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      777,
      '🔥 Waktu Istirahat Habis!',
      'Ayo kembali ke Kora dan selesaikan set selanjutnya!',
      tz.TZDateTime.now(tz.local).add(Duration(seconds: delaySeconds)),
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  void _startRest({required bool isLastSet}) {
    setState(() {
      _isResting = true;
      _restRemaining = _restSeconds;
      _restAlertFired = false;
    });

    _scheduleRestNotification(_restRemaining);

    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _restRemaining--);

      if (_restRemaining <= 0) {
        t.cancel();
        _playAlarm();
        _endRest(isLastSet: isLastSet);
      }
    });
  }

  Future<void> _playAlarm() async {
    // Memainkan suara alarm dari asset (kring-kring)
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('audio/whistle.mp3'));
      // Lepaskan resource setelah 5 detik agar tidak memory leak
      Future.delayed(const Duration(seconds: 5), () => player.dispose());
    } catch (e) {
      debugPrint("Gagal memutar suara alarm: $e");
    }

    // Memainkan getaran kuat (Vibrate pattern)
    if (await Vibration.hasVibrator() ?? false) {
      // Pola: Tunggu 0ms, getar 500ms, jeda 200ms, getar 500ms...
      Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
    } else {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 300),
          () => HapticFeedback.heavyImpact());
      Future.delayed(const Duration(milliseconds: 600),
          () => HapticFeedback.heavyImpact());
    }
  }

  void _endRest({required bool isLastSet}) {
    _notificationsPlugin.cancel(777); // Cancel scheduled notification
    _restTimer?.cancel();
    HapticFeedback.vibrate();
    _restTimer?.cancel();
    if (isLastSet) {
      setState(() {
        _isResting = false;
        _currentExerciseIndex++;
        _currentSet = 1;
        _reps = 10;
        _heroPageController.animateToPage(
          _currentExerciseIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    } else {
      setState(() {
        _isResting = false;
        _currentSet++;
      });
    }
  }

  void _skipRest() {
    _notificationsPlugin.cancel(777);
    _restTimer?.cancel();
    final isLastSet = _currentSet >= _totalSetsPerExercise;
    _endRest(isLastSet: isLastSet);
  }

  void _addRestTime(int seconds) {
    HapticFeedback.lightImpact();
    setState(() {
      _restRemaining += seconds;
      _restAlertFired = false; // Reset alert if they added time
    });
    _notificationsPlugin.cancel(777);
    _scheduleRestNotification(_restRemaining);
  }

  Future<void> _finishWorkout() async {
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryScreen(
          exercises: widget.exercises,
          allLogs: _allLogs,
          sessionSeconds: _sessionSeconds,
          userWeight: widget.userWeight,
        ),
      ),
    );
  }

  void _showExitDialog() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Icon(Icons.warning_amber_rounded,
                color: AppTheme.accentRed, size: 48),
            const SizedBox(height: 16),
            Text('Yakin mau berhenti sekarang?',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Progress set ini akan hilang.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Lanjut Latihan',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // close sheet
                    Navigator.pop(context); // exit screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Keluar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        _buildHeroSection(),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildLogCard(),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildLogSetButton(),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isResting) _buildRestOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _showExitDialog,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Icon(Icons.close_rounded,
                      color: AppTheme.textSecondary, size: 20),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  _formatTime(_sessionSeconds),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    final screenHeight = MediaQuery.of(context).size.height;
    final imageHeight = screenHeight * 0.4;

    return SizedBox(
      height: imageHeight + 160,
      child: PageView.builder(
        controller: _heroPageController,
        onPageChanged: (idx) {
          if (idx != _currentExerciseIndex) {
            setState(() {
              _currentExerciseIndex = idx;
              _currentSet = 1;
              _reps = 10;
            });
            HapticFeedback.selectionClick();
          }
        },
        itemCount: widget.exercises.length,
        itemBuilder: (context, index) {
          final ex = widget.exercises[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Container(
                  height: imageHeight,
                  width: double.infinity,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.electricBlue.withOpacity(0.12),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ex.gifPath != null
                      ? Image.asset(
                          ex.gifPath!,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : Center(
                          child: Icon(
                            ex.icon,
                            size: 96,
                            color: AppTheme.electricBlue.withOpacity(0.85),
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                Text(
                  ex.name.toUpperCase(),
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Set $_currentSet dari $_totalSetsPerExercise',
                  style: TextStyle(
                      color: AppTheme.electricBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  ex.techniqueTip,
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogCard() {
    // Determine target based on previous log or default
    final logs = _allLogs[_currentExerciseIndex];
    int targetReps = logs.isNotEmpty ? logs.last.reps : 12;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border.withOpacity(0.8)),
          ),
          child: Column(
            children: [
              Text('Target: $targetReps Reps',
                  style: TextStyle(
                      color: AppTheme.electricBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _stepperButton(Icons.remove_rounded, () => _changeReps(-1)),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 100,
                    child: Text(
                      '$_reps',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  _stepperButton(Icons.add_rounded, () => _changeReps(1)),
                ],
              ),
              if (_isWeightlifting) ...[
                const SizedBox(height: 20),
                Divider(color: AppTheme.border),
                const SizedBox(height: 16),
                Text('BEBAN (kg)',
                    style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.fitness_center_rounded,
                        color: AppTheme.electricBlue, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(color: AppTheme.textMuted),
                          suffixText: 'kg',
                          suffixStyle: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 16),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: AppTheme.electricBlue, width: 2)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.border)),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 28),
      ),
    );
  }

  Widget _buildLogSetButton() {
    final isLastSet = _currentSet >= _totalSetsPerExercise;
    final isLastExercise = _currentExerciseIndex >= widget.exercises.length - 1;
    final isFinishing = isLastSet && isLastExercise;

    return GestureDetector(
      onTap: _logSet,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 62,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isFinishing
                ? [AppTheme.neonGreen, Color(0xFF00CC6A)]
                : [const Color(0xFFFF5406), const Color(0xFFFF7A3D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: (isFinishing ? AppTheme.neonGreen : AppTheme.electricBlue)
                  .withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isFinishing ? Icons.flag_rounded : Icons.check_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                isFinishing ? 'SELESAI LATIHAN' : 'REST TIME',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestOverlay() {
    final nextIndex = _currentSet >= _totalSetsPerExercise
        ? _currentExerciseIndex + 1
        : _currentExerciseIndex;
    final nextExerciseName = nextIndex < widget.exercises.length
        ? widget.exercises[nextIndex].name
        : null;

    final mins = (_restRemaining ~/ 60).toString().padLeft(2, '0');
    final secs = (_restRemaining % 60).toString().padLeft(2, '0');

    return Positioned.fill(
      child: Scaffold(
        backgroundColor: AppTheme.isDarkMode ? Colors.black : Colors.white,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('RECOVERY',
                  style: TextStyle(
                      color: AppTheme.neonGreen,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4.0)),
              const SizedBox(height: 16),
              if (nextExerciseName != null &&
                  _currentSet >= _totalSetsPerExercise)
                Text(
                    'Set $_currentSet Selesai\nBersiap untuk $nextExerciseName',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.4))
              else
                Text(
                    'Set $_currentSet Selesai\nBersiap untuk Set ${_currentSet + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.4)),
              const SizedBox(height: 60),
              Text(
                '$mins:$secs',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 100,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  fontFeatures: const [FontFeature.tabularFigures()],
                  shadows: [
                    // Highlight super tajam di bagian atas (Inner Bevel / Emboss edge)
                    Shadow(
                      color: Colors.white.withOpacity(AppTheme.isDarkMode ? 0.15 : 0.7),
                      offset: const Offset(0, -1),
                      blurRadius: 0,
                    ),
                    // Bayangan solid di bawah angka untuk kedalaman fisik (Raised 3D effect)
                    Shadow(
                      color: Colors.black.withOpacity(AppTheme.isDarkMode ? 0.9 : 0.3),
                      offset: const Offset(0, 3),
                      blurRadius: 0,
                    ),
                    // Sedikit bayangan tipis agar angka terpisah dari background, tanpa efek menyebar
                    Shadow(
                      color: Colors.black.withOpacity(AppTheme.isDarkMode ? 0.4 : 0.1),
                      offset: const Offset(0, 5),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _addRestTime(-10),
                    icon: const Icon(Icons.remove_rounded, size: 20),
                    label: const Text('10s',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: BorderSide(color: AppTheme.border, width: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(width: 20),
                  OutlinedButton.icon(
                    onPressed: () => _addRestTime(20),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('20s',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: BorderSide(color: AppTheme.border, width: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 80),
              GestureDetector(
                onTap: _skipRest,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFF5406),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFFF5406).withOpacity(0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 8))
                      ]),
                  child: const Text('LEWATI ISTIRAHAT',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
