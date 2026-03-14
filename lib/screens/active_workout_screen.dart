import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/workout.dart';
import '../services/database_helper.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final String workoutType;
  final double userWeight;

  ActiveWorkoutScreen({
    super.key,
    required this.workoutType,
    required this.userWeight,
  });

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  bool _isRunning = false;
  int _elapsedSeconds = 0;
  Timer? _timer;

  String get _workoutTitle {
    switch (widget.workoutType) {
      case 'basketball':
        return '🏀 Latihan Basket';
      case 'weightlifting':
        return '🏋️ Angkat Beban';
      default:
        return '💪 Latihan Bebas';
    }
  }

  Color get _workoutColor {
    switch (widget.workoutType) {
      case 'basketball':
        return AppTheme.basketballColor;
      case 'weightlifting':
        return AppTheme.weightliftingColor;
      default:
        return AppTheme.neonGreen;
    }
  }

  void _toggleTimer() {
    if (_isRunning) {
      _stopTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() => _elapsedSeconds++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  Future<void> _saveWorkout() async {
    final durationMinutes = _elapsedSeconds / 60.0;
    
    // Prevent saving if duration is too short (< 1 min)
    if (durationMinutes < 1.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Durasi terlalu singkat untuk disimpan.')),
      );
      return;
    }

    final calories = Workout.calculateCalories(widget.workoutType, durationMinutes);
    final protein = Workout.calculateProteinNeeded(widget.workoutType, durationMinutes, weight: widget.userWeight);

    final workout = Workout(
      type: widget.workoutType,
      duration: durationMinutes,
      caloriesBurned: calories,
      proteinNeeded: protein,
      date: DateTime.now(),
      notes: 'Dilacak dengan Active Timer.',
    );

    await DatabaseHelper().insertWorkout(workout);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sesi latihan berhasil disimpan!')),
      );
      Navigator.pop(context, true); // Return true to signal refresh needed
    }
  }

  String get _formattedTime {
    final h = (_elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((_elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    if (h == '00') {
      return '$m:$s';
    }
    return '$h:$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_workoutTitle),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
           padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
               Icon(
                 widget.workoutType == 'basketball' ? Icons.sports_basketball : Icons.fitness_center,
                 size: 100,
                 color: _workoutColor,
               ),
               SizedBox(height: 48),
               
               // Timer Display
               Container(
                 padding: EdgeInsets.all(40),
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   color: AppTheme.surface,
                   border: Border.all(
                     color: _isRunning ? _workoutColor : AppTheme.border,
                     width: 4,
                   ),
                   boxShadow: _isRunning ? [
                     BoxShadow(
                       color: _workoutColor.withOpacity(0.3),
                       blurRadius: 30,
                       spreadRadius: 10,
                     )
                   ] : [],
                 ),
                 child: Center(
                   child: Text(
                     _formattedTime,
                     style: TextStyle(
                       fontSize: 48,
                       fontWeight: FontWeight.w800,
                       fontFeatures: [FontFeature.tabularFigures()],
                       color: AppTheme.textPrimary,
                     ),
                   ),
                 ),
               ),
               
               Spacer(),
               
               // Dynamic Status text
               Center(
                 child: Text(
                   _elapsedSeconds == 0 
                     ? 'Siap untuk mulai?' 
                     : (_isRunning ? 'Sesi sedang berjalan...' : 'Sesi dihentikan sementara'),
                   style: TextStyle(
                     fontSize: 16,
                     color: AppTheme.textMuted,
                   ),
                 ),
               ),
               
               SizedBox(height: 32),
               
               // Buttons
               Row(
                 children: [
                   if (_elapsedSeconds > 0 && !_isRunning) ...[
                     Expanded(
                       child: ElevatedButton(
                         onPressed: _saveWorkout,
                         style: ElevatedButton.styleFrom(
                           backgroundColor: AppTheme.surface,
                           foregroundColor: AppTheme.neonGreen,
                           padding: EdgeInsets.symmetric(vertical: 20),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                           side: BorderSide(color: AppTheme.neonGreen, width: 2),
                         ),
                         child: Text('Simpan Sesi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                       ),
                     ),
                     SizedBox(width: 16),
                   ],
                   
                   Expanded(
                     child: ElevatedButton(
                       onPressed: _toggleTimer,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: _isRunning ? AppTheme.accentRed : _workoutColor,
                         padding: EdgeInsets.symmetric(vertical: 20),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                       ),
                       child: Text(
                         _isRunning ? 'Jeda Latihan' : (_elapsedSeconds > 0 ? 'Lanjut' : 'Mulai Latihan'), 
                         style: TextStyle(
                           color: _isRunning ? Colors.white : Colors.black, 
                           fontSize: 18, 
                           fontWeight: FontWeight.bold
                         )
                       ),
                     ),
                   ),
                 ],
               )
             ],
           ),
        ),
      ),
    );
  }
}
