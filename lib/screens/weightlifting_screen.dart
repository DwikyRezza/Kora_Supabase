import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/workout.dart';
import '../services/database_helper.dart';
import 'dart:async';

class WeightliftingScreen extends StatefulWidget {
  final double userWeight;

  const WeightliftingScreen({super.key, required this.userWeight});

  @override
  State<WeightliftingScreen> createState() => _WeightliftingScreenState();
}

class _WeightliftingScreenState extends State<WeightliftingScreen> {
  int _selectedCategory = 1; // 0: Bodyweight, 1: Free Weights, 2: Isometric
  
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _setsController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(); // for isometric duration / total duration
  final TextEditingController _notesController = TextEditingController();

  // Rest Timer
  int _restTimeRemaining = 0;
  Timer? _restTimer;
  bool _isResting = false;

  void _startRestTimer(int seconds) {
    if (_restTimer != null) {
      _restTimer!.cancel();
    }
    setState(() {
      _restTimeRemaining = seconds;
      _isResting = true;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restTimeRemaining > 0) {
        setState(() {
          _restTimeRemaining--;
        });
      } else {
        _stopRestTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Waktu istirahat selesai! Ayo lanjut set berikutnya! 💪'),
            backgroundColor: AppTheme.neonGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restTimeRemaining = 0;
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _setsController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    _restTimer?.cancel();
    super.dispose();
  }
  
  String get _volumeTotal {
    double w = double.tryParse(_weightController.text) ?? 0.0;
    int r = int.tryParse(_repsController.text) ?? 0;
    int s = int.tryParse(_setsController.text) ?? 0;
    
    if (_selectedCategory == 1) {
      return (w * r * s).toStringAsFixed(1) + ' kg';
    } else if (_selectedCategory == 0) {
      return (r * s).toString() + ' repetisi';
    } else {
      int d = int.tryParse(_durationController.text) ?? 0;
      return (d * s).toString() + ' detik';
    }
  }

  Future<void> _saveWorkout() async {
    // Collect data
    double weight = double.tryParse(_weightController.text) ?? 0.0;
    int reps = int.tryParse(_repsController.text) ?? 0;
    int sets = int.tryParse(_setsController.text) ?? 0;
    double durationMins = double.tryParse(_durationController.text) ?? 0.0; // Assume total time logged or typed

    // If isometric, maybe duration was in seconds per set? For simplification let's just use durationMins for the overall log
    if (_selectedCategory == 2) {
       // user inputs duration per set in seconds. Let's say Total duration = sets * duration_per_set / 60
       int durSec = int.tryParse(_durationController.text) ?? 0;
       durationMins = (durSec * sets) / 60.0;
       if (durationMins < 1.0) durationMins = 5.0; // default 5 mins minimum for isometric logic
    } else {
       // if no duration given, lets estimate 3 mins per set including rest
       if (durationMins <= 0) {
         durationMins = sets * 3.0; // 3 minutes per set typically
         if (durationMins <= 0) durationMins = 10.0; // Default fallback
       }
    }

    final calories = Workout.calculateCalories('weightlifting', durationMins);
    final protein = Workout.calculateProteinNeeded('weightlifting', durationMins, weight: widget.userWeight);

    String subTypeStr = _selectedCategory == 0 
      ? "Bodyweight" 
      : (_selectedCategory == 1 ? "Free Weights" : "Isometric");

    String notes = "Kategori: $subTypeStr\n"
                 "Volume: $_volumeTotal\n";
    if (_notesController.text.isNotEmpty) {
      notes += "Catatan: ${_notesController.text}";
    }

    final workout = Workout(
      type: 'weightlifting',
      duration: durationMins,
      distance: null,
      sets: sets,
      reps: reps,
      weight: _selectedCategory == 1 ? weight : null,
      caloriesBurned: calories,
      proteinNeeded: protein,
      notes: notes,
      date: DateTime.now(),
    );

    await DatabaseHelper().insertWorkout(workout);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sesi $subTypeStr berhasil disimpan!')),
      );
      Navigator.pop(context, true);
    }
  }

  Widget _buildCategorySelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildCategoryTab(0, 'Beban Tubuh', Icons.accessibility_new_rounded),
          _buildCategoryTab(1, 'Beban Luar', Icons.fitness_center_rounded),
          _buildCategoryTab(2, 'Statis/Isometrik', Icons.sports_gymnastics_rounded),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(int index, String label, IconData icon) {
    bool isSelected = _selectedCategory == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategory = index;
            _weightController.clear();
            _repsController.clear();
            _setsController.clear();
            _durationController.clear();
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.weightliftingColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [BoxShadow(color: AppTheme.weightliftingColor.withOpacity(0.3), blurRadius: 8)]
                : [],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                size: 20,
              ),
              SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, String hint, {bool isInteger = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.weightliftingColor, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestTimerControls() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isResting ? AppTheme.neonGreen : AppTheme.border),
      ),
      child: Column(
        children: [
          Text(
            '⏳ Rest Timer',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          if (_isResting) ...[
            Text(
              '${_restTimeRemaining ~/ 60}:${(_restTimeRemaining % 60).toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.neonGreen),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _stopRestTimer,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Akhiri Istirahat'),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _restBtn("+30s", 30),
                SizedBox(width: 8),
                _restBtn("+60s", 60),
                SizedBox(width: 8),
                _restBtn("+90s", 90),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _restBtn(String label, int seconds) {
    return OutlinedButton(
      onPressed: () => _startRestTimer(seconds),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.neonGreen,
        side: BorderSide(color: AppTheme.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('🏋️ Logs Angkat Beban'),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCategorySelector(),
              SizedBox(height: 24),

              // Inputs based on Category
              if (_selectedCategory == 1) // Free Weights
                _buildInputField('Beban (kg/lbs)', _weightController, 'Misal: 40', isInteger: false),
              
              if (_selectedCategory == 0 || _selectedCategory == 1) ...[ // Bodyweight & Free Weights
                Row(
                  children: [
                    Expanded(child: _buildInputField('Set', _setsController, '4', isInteger: true)),
                    SizedBox(width: 16),
                    Expanded(child: _buildInputField('Repetisi', _repsController, '10', isInteger: true)),
                  ],
                ),
              ],
              
              if (_selectedCategory == 2) ...[ // Isometric
                Row(
                  children: [
                    Expanded(child: _buildInputField('Set', _setsController, '3', isInteger: true)),
                    SizedBox(width: 16),
                    Expanded(child: _buildInputField('Durasi Tahan (detik)', _durationController, '60', isInteger: true)),
                  ],
                ),
              ],

              // Volume Calculator Display
              Container(
                margin: EdgeInsets.only(bottom: 24),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.weightliftingColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.weightliftingColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Volume Kerja:', style: TextStyle(color: AppTheme.weightliftingColor, fontWeight: FontWeight.w600)),
                    Text('$_volumeTotal', style: TextStyle(color: AppTheme.weightliftingColor, fontWeight: FontWeight.w900, fontSize: 18)),
                  ],
                ),
              ),

              // Rest Timer
              _buildRestTimerControls(),
              SizedBox(height: 24),

              // Notes
              Text('Catatan / RPE (Opsional)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              TextField(
                controller: _notesController,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Misal: RPE 8, terasa lebih ringan dari minggu lalu...',
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.weightliftingColor, width: 1.5),
                  ),
                ),
              ),

              SizedBox(height: 40),
              
              ElevatedButton(
                onPressed: _saveWorkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.weightliftingColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text('Simpan Rekapan Workout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
