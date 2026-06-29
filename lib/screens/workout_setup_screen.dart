import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/exercise_definition.dart';
import 'active_workout_screen.dart';

class WorkoutSetupScreen extends StatefulWidget {
  final double userWeight;

  const WorkoutSetupScreen({super.key, required this.userWeight});

  @override
  State<WorkoutSetupScreen> createState() => _WorkoutSetupScreenState();
}

class _WorkoutSetupScreenState extends State<WorkoutSetupScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // State
  String? _selectedMode; // 'bodyweight' | 'weighted'
  final Set<String> _selectedMuscles = {};
  final List<String> _selectedExerciseIds = [];
  final Map<String, int> _exerciseSets = {};

  final Map<String, List<String>> _muscleCategories = {
    'Dada (Chest)': ['Dada'],
    'Lengan & Bahu': ['Bicep', 'Tricep', 'Forearm', 'Bahu Depan', 'Bahu Samping', 'Bahu Belakang'],
    'Kaki (Legs)': ['Paha Depan', 'Paha Belakang', 'Paha Samping', 'Paha Dalam', 'Pantat', 'Betis'],
    'Punggung & Perut': ['Punggung Atas', 'Punggung Samping', 'Punggung Bawah', 'Perut Depan', 'Perut Samping'],
  };

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      // Start workout
      final selectedExercises = _selectedExerciseIds.map((id) => exerciseDatabase.firstWhere((e) => e.id == id)).toList();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveWorkoutScreen(
            exercises: selectedExercises,
            userWeight: widget.userWeight,
            exerciseSets: _exerciseSets,
          ),
        ),
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: _prevPage,
        ),
        title: _buildProgressIndicators(),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildStep1Mode(),
                  _buildStep2Muscles(),
                  _buildStep3Exercises(),
                  _buildStep4Summary(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicators() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final isActive = index == _currentPage;
        final isDone = index < _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: isActive ? 24 : 12,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.electricBlue : (isDone ? AppTheme.electricBlue.withOpacity(0.5) : AppTheme.border),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildBottomBar() {
    bool canProceed = false;
    if (_currentPage == 0 && _selectedMode != null) canProceed = true;
    if (_currentPage == 1 && _selectedMuscles.isNotEmpty) canProceed = true;
    if (_currentPage == 2 && _selectedExerciseIds.isNotEmpty) canProceed = true;
    if (_currentPage == 3) canProceed = true;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        decoration: _currentPage == 3
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.electricBlue.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              )
            : null,
        child: ElevatedButton(
          onPressed: canProceed ? _nextPage : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.electricBlue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppTheme.surfaceVariant,
            disabledForegroundColor: AppTheme.textMuted,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            _currentPage == 3 ? 'MULAI LATIHAN' : 'LANJUTKAN',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
        ),
      ),
    );
  }

  // --- Step 1: Mode
  Widget _buildStep1Mode() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tahap 1: Mode Latihan', style: TextStyle(color: AppTheme.electricBlue, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Text('Pilih gaya latihanmu', style: TextStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Text('Ini akan menyesuaikan jenis gerakan yang akan disarankan.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 32),
          _modeCard('bodyweight', 'Bodyweight Mode', 'Fokus pada kalistenik & ketahanan tubuh tanpa alat', Icons.accessibility_new_rounded),
          const SizedBox(height: 16),
          _modeCard('weighted', 'Weighted Mode', 'Fokus hipertrofi dengan dumbbell atau barbell', Icons.fitness_center_rounded),
        ],
      ),
    );
  }

  Widget _modeCard(String mode, String title, String subtitle, IconData icon) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.electricBlue.withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppTheme.electricBlue : AppTheme.border, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.electricBlue : AppTheme.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : AppTheme.textSecondary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 2: Muscles
  Widget _buildStep2Muscles() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tahap 2: Pemetaan Otot', style: TextStyle(color: AppTheme.electricBlue, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Text('Otot apa yang ingin dilatih?', style: TextStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Text('Pilih area otot spesifik untuk menyusun rutinitas.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: _muscleCategories.entries.map((entry) {
                final categoryName = entry.key;
                final muscles = entry.value;
                // Hitung berapa otot yang sudah dipilih di kategori ini
                final selectedCount = muscles.where((m) => _selectedMuscles.contains(m)).length;
                final isCategoryActive = selectedCount > 0;

                return Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isCategoryActive ? AppTheme.electricBlue.withOpacity(0.05) : AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isCategoryActive ? AppTheme.electricBlue.withOpacity(0.5) : AppTheme.border),
                    ),
                    child: ExpansionTile(
                      title: Text(
                        categoryName,
                        style: TextStyle(
                          color: isCategoryActive ? AppTheme.electricBlue : AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: selectedCount > 0 
                          ? Text('$selectedCount otot dipilih', style: TextStyle(color: AppTheme.electricBlue, fontSize: 12)) 
                          : null,
                      iconColor: AppTheme.electricBlue,
                      collapsedIconColor: AppTheme.textSecondary,
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.start,
                          children: muscles.map((m) {
                            final isSelected = _selectedMuscles.contains(m);
                            return FilterChip(
                              label: Text(m),
                              selected: isSelected,
                              onSelected: (val) {
                                setState(() {
                                  if (val) _selectedMuscles.add(m);
                                  else _selectedMuscles.remove(m);
                                });
                              },
                              backgroundColor: AppTheme.background,
                              selectedColor: AppTheme.electricBlue.withOpacity(0.2),
                              checkmarkColor: AppTheme.electricBlue,
                              labelStyle: TextStyle(
                                color: isSelected ? AppTheme.electricBlue : AppTheme.textSecondary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: isSelected ? AppTheme.electricBlue : AppTheme.border),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 3: Exercises
  Widget _buildStep3Exercises() {
    // Filter logic
    final filtered = exerciseDatabase.where((e) {
      if (_selectedMode != null && e.category != _selectedMode) return false;
      if (_selectedMuscles.isNotEmpty) {
        bool match = false;
        for (var m in e.muscleGroups) {
          if (_selectedMuscles.contains(m)) match = true;
        }
        if (!match) return false;
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tahap 3: Kurasi Gerakan', style: TextStyle(color: AppTheme.electricBlue, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Text('Pilih gerakanmu', style: TextStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Text('Rekomendasi berdasarkan otot yang dipilih. Pilih yang ingin dilakukan.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text('Tidak ada gerakan yang sesuai kriteria.', style: TextStyle(color: AppTheme.textMuted)))
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final ex = filtered[i];
                      final isSelected = _selectedExerciseIds.contains(ex.id);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) _selectedExerciseIds.add(ex.id);
                            else _selectedExerciseIds.remove(ex.id);
                          });
                        },
                        title: Text(ex.name, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                        subtitle: Text('${ex.difficulty} • ${ex.muscleGroups.join(', ')}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        secondary: Icon(ex.icon, color: AppTheme.textMuted),
                        activeColor: AppTheme.electricBlue,
                        checkColor: Colors.white,
                        tileColor: AppTheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isSelected ? AppTheme.electricBlue : AppTheme.border),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- Step 4: Summary
  Widget _buildStep4Summary() {
    int totalSets = 0;
    for (var id in _selectedExerciseIds) {
      totalSets += _exerciseSets[id] ?? 4;
    }
    final estimatedMins = totalSets * 1; // roughly 1 min per set including rest
    final estimatedCalories = estimatedMins * 8; // roughly 8 kcal per min

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tahap Final', style: TextStyle(color: AppTheme.electricBlue, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Text('Today\'s Routine', style: TextStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Icon(Icons.local_fire_department_rounded, color: const Color(0xFFFF5406), size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estimasi Sesi', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('~$estimatedMins Menit', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          Container(width: 4, height: 4, decoration: BoxDecoration(color: AppTheme.textMuted, shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          Text('~$estimatedCalories kkal', style: TextStyle(color: const Color(0xFFFF5406), fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Daftar Gerakan (${_selectedExerciseIds.length})', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                canvasColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: ReorderableListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _selectedExerciseIds.length,
                proxyDecorator: (Widget child, int index, Animation<double> animation) {
                  return Material(
                    elevation: 12,
                    color: Colors.transparent,
                    shadowColor: AppTheme.electricBlue.withOpacity(0.5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.electricBlue, width: 2),
                        boxShadow: [
                          BoxShadow(color: AppTheme.electricBlue.withOpacity(0.3), blurRadius: 12, spreadRadius: 2),
                        ]
                      ),
                      child: child,
                    ),
                  );
                },
                onReorderStart: (_) => HapticFeedback.mediumImpact(),
                onReorder: (oldIndex, newIndex) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _selectedExerciseIds.removeAt(oldIndex);
                    _selectedExerciseIds.insert(newIndex, item);
                  });
                },
                itemBuilder: (ctx, i) {
                  final exId = _selectedExerciseIds[i];
                  final ex = exerciseDatabase.firstWhere((e) => e.id == exId);
                  return Container(
                    key: ValueKey(exId),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            child: Text('${i + 1}.', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.electricBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Icon(ex.icon, color: AppTheme.electricBlue, size: 20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ex.name, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(ex.muscleGroups.join(', '), style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      int current = _exerciseSets[exId] ?? 4;
                                      if (current > 1) _exerciseSets[exId] = current - 1;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    child: Icon(Icons.remove, color: AppTheme.textPrimary, size: 16),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    _showSetEditDialog(exId);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    child: Text('${_exerciseSets[exId] ?? 4}', style: TextStyle(color: AppTheme.electricBlue, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      int current = _exerciseSets[exId] ?? 4;
                                      if (current < 99) _exerciseSets[exId] = current + 1;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    child: Icon(Icons.add, color: AppTheme.textPrimary, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.drag_handle_rounded, color: Colors.grey, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSetEditDialog(String exId) {
    final ctrl = TextEditingController(text: '${_exerciseSets[exId] ?? 4}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Atur Jumlah Set', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.electricBlue, width: 2)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.white70))),
          TextButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text);
              if (val != null && val > 0 && val < 100) {
                setState(() => _exerciseSets[exId] = val);
              }
              Navigator.pop(ctx);
            },
            child: Text('Simpan', style: TextStyle(color: AppTheme.electricBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
