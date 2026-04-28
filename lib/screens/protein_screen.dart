import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/protein_entry.dart';
import '../services/database_helper.dart';
import '../services/profile_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'package:liquid_progress_indicator_v2/liquid_progress_indicator.dart';
import 'weekly_report_screen.dart';
import 'ai_nutrition_screen.dart';

class ProteinScreen extends StatefulWidget {
  const ProteinScreen({super.key});

  @override
  State<ProteinScreen> createState() => _ProteinScreenState();
}

class _ProteinScreenState extends State<ProteinScreen> {
  final _db = DatabaseHelper();
  List<ProteinEntry> _entries = [];
  bool _isLoading = true;
  double _targetProtein = 150.0;
  final double _targetCalories = 2500.0; // Estimate
  int _targetWaterMl = 2000;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Dipanggil saat pull-to-refresh — sync nutrisi dari Firestore dulu
  Future<void> _refreshData() async {
    try {
      await CloudSyncService.syncNutritionToCloud(); // push lokal ke cloud
      // lalu pull cloud ke lokal (supaya data HP lain juga masuk)
    } catch (_) {}
    // Restore nutrition dari Firestore ke SQLite
    try {
      await CloudSyncService.restoreAllFromCloud();
    } catch (_) {}
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final today = DateTime.now();
    final entries = await _db.getProteinEntriesByDate(today);
    final profile = await ProfileService.getProfile();
    
    if (mounted) {
      setState(() {
        _entries = entries;
        _targetProtein = profile[ProfileService.keyTargetProtein] ?? 150.0;
        if (_targetProtein == 0) _targetProtein = 150.0;
        final weight = profile[ProfileService.keyWeight] ?? 70.0;
        _targetWaterMl = (weight * 35).round();
        
        // Target adjustments based on goal can be added here
        
        if (_totalProtein < _targetProtein * 0.9) {
          NotificationService().scheduleNutritionReminders();
        } else {
          NotificationService().cancelNutritionReminders();
        }

        _isLoading = false;
      });
    }
  }

  double get _totalProtein => _entries.fold(0, (sum, e) => sum + e.proteinGrams);
  double get _totalCalories => _entries.fold(0, (sum, e) => sum + e.calories);
  double get _totalCarbs => _entries.fold(0, (sum, e) => sum + e.carbsGrams);
  double get _totalFat => _entries.fold(0, (sum, e) => sum + e.fatGrams);
  double get _totalFiber => _entries.fold(0, (sum, e) => sum + e.fiberGrams);
  double get _totalSugar => _entries.fold(0, (sum, e) => sum + e.sugarGrams);
  double get _totalSalt => _entries.fold(0, (sum, e) => sum + e.saltGrams);
  int get _totalWater => _entries.fold(0, (sum, e) => sum + e.waterMl);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(' Nutrition & Hydration', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.local_fire_department_rounded, color: AppTheme.accentOrange, size: 28),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyReportScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Tombol kiri: AI Nutrition dengan logo Gemini
            FloatingActionButton.extended(
              heroTag: 'aiFab',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AiNutritionScreen(),
                  ),
                );
                // Jika ada data baru disimpan, reload
                if (result == true) _loadData();
              },
              backgroundColor: AppTheme.surface,
              foregroundColor: AppTheme.textPrimary,
              elevation: 4,
              icon: const _GeminiIcon(),
              label: const Text(
                'Catat AI',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            // Tombol kanan: catat nutrisi manual
            FloatingActionButton.extended(
              heroTag: 'proteinFab',
              onPressed: _showAddProteinSheet,
              backgroundColor: AppTheme.neonGreen,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.restaurant_menu_rounded),
              label: const Text('Catat Nutrisi',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: AppTheme.neonGreen,
              backgroundColor: AppTheme.surface,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildEnergyAndHydration(),
                          const SizedBox(height: 16),
                          _buildMacrosGrid(),
                          const SizedBox(height: 16),
                          _buildMicrosAndLimits(),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                     child: Padding(
                       padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                       child: Text('Riwayat Konsumsi', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                     ),
                  ),
                  if (_entries.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Text('Belum ada asupan yang dicatat hari ini.', style: TextStyle(color: AppTheme.textMuted)),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final entry = _entries[index];
                          final isWater = entry.waterMl > 0 && entry.calories == 0;
                          
                          return Dismissible(
                            key: Key('nut_${entry.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(color: AppTheme.accentRed, borderRadius: BorderRadius.circular(16)),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete_rounded, color: Colors.white),
                            ),
                            onDismissed: (_) async {
                              await _db.deleteProteinEntry(entry.id!);
                              // Sync ke Firestore di background
                              CloudSyncService.syncNutritionToCloud().catchError((_) {});
                              _loadData();
                            },
                            child: Card(
                              color: AppTheme.cardBg,
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: AppTheme.border),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.surfaceVariant,
                                  child: Icon(entry.foodIcon, size: 20),
                                ),
                                title: Text(entry.foodName, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  isWater 
                                    ? '${entry.waterMl} ml • Hidrasi' 
                                    : '${entry.calories.toStringAsFixed(0)} kcal • ${entry.mealLabel}', 
                                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13)
                                ),
                                trailing: isWater 
                                  ? Icon(Icons.water_drop, color: AppTheme.electricBlue)
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('${entry.proteinGrams.toStringAsFixed(1)}g Pro', style: TextStyle(color: AppTheme.neonGreen, fontSize: 13, fontWeight: FontWeight.w800)),
                                        Text('${entry.carbsGrams.toStringAsFixed(1)}g Carb', style: TextStyle(color: Colors.orange[300], fontSize: 11, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                              ),
                            ),
                          );
                        },
                        childCount: _entries.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }

  Widget _buildEnergyAndHydration() {
    double calProgress = (_totalCalories / _targetCalories).clamp(0.0, 1.0);
    double waterProgress = (_totalWater / _targetWaterMl).clamp(0.0, 1.0);

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded, color: AppTheme.accentOrange, size: 20),
                    const SizedBox(width: 8),
                    Text('Kalori', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_totalCalories.toStringAsFixed(0), style: TextStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w900)),
                Text('kcal dikonsumsi', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: calProgress, backgroundColor: AppTheme.surfaceVariant, valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange), borderRadius: BorderRadius.circular(4)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: _showAddWaterSheet,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.electricBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.electricBlue.withOpacity(0.3))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.water_drop_rounded, color: AppTheme.electricBlue, size: 20),
                          const SizedBox(width: 8),
                          Text('Air Putih', style: TextStyle(color: AppTheme.electricBlue, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Icon(Icons.add_circle, color: AppTheme.electricBlue, size: 20),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('$_totalWater', style: TextStyle(color: AppTheme.electricBlue, fontSize: 28, fontWeight: FontWeight.w900)),
                  Text('dari $_targetWaterMl ml', style: TextStyle(color: AppTheme.electricBlue, fontSize: 11)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 24,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LiquidLinearProgressIndicator(
                        value: waterProgress,
                        valueColor: AlwaysStoppedAnimation(AppTheme.electricBlue.withOpacity(0.8)),
                        backgroundColor: AppTheme.electricBlue.withOpacity(0.1),
                        borderColor: Colors.transparent,
                        borderWidth: 0,
                        borderRadius: 12.0,
                        direction: Axis.horizontal,
                        center: Text(
                          "${(waterProgress * 100).toInt()}%",
                          style: TextStyle(
                            color: waterProgress > 0.4 ? Colors.white : AppTheme.electricBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMacrosGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Makronutrisi (Bahan Bakar)', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _macroCircle('Protein', _totalProtein, _targetProtein, AppTheme.neonGreen),
              _macroCircle('Karbo', _totalCarbs, 250, Colors.orange[400]!),
              _macroCircle('Lemak', _totalFat, 65, Colors.pink[400]!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroCircle(String label, double current, double target, Color color) {
    double progress = (current / target).clamp(0.0, 1.0);
    return Column(
      children: [
        SizedBox(
          width: 70,
          height: 70,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                backgroundColor: AppTheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Center(
                child: Text('${current.toStringAsFixed(0)}g', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
              )
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMicrosAndLimits() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text('Mikro & Batasan (GGL)', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
           const SizedBox(height: 16),
           _microBar('Serat (Pencernaan)', _totalFiber, 30, Colors.green[400]!, 'g'),
           const SizedBox(height: 12),
           _microBar('Gula (Maks 50g)', _totalSugar, 50, AppTheme.accentRed, 'g', isLimit: true),
           const SizedBox(height: 12),
           _microBar('Garam (Maks 5g)', _totalSalt, 5, Colors.purple[300]!, 'g', isLimit: true),
        ],
      ),
    );
  }

  Widget _microBar(String label, double current, double target, Color color, String unit, {bool isLimit = false}) {
    double progress = (current / target).clamp(0.0, 1.0);
    bool overLimit = isLimit && current > target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
             Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
             Text('${current.toStringAsFixed(1)}$unit / ${target.toStringAsFixed(0)}$unit', 
              style: TextStyle(color: overLimit ? AppTheme.accentRed : AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
           ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppTheme.surfaceVariant,
          valueColor: AlwaysStoppedAnimation<Color>(overLimit ? AppTheme.accentRed : color),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        )
      ],
    );
  }

  void _showAddWaterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tambah Air Putih', style: TextStyle(color: AppTheme.electricBlue, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _waterButton(250, '1 Gelas'),
                  _waterButton(600, 'Botol Sedang'),
                  _waterButton(1000, 'Botol Besar'),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    );
  }

  Widget _waterButton(int ml, String label) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        await _db.insertProteinEntry(ProteinEntry(
          foodName: 'Air Putih ($label)',
          proteinGrams: 0,
          calories: 0,
          waterMl: ml,
          mealType: 'water',
          date: DateTime.now(),
        ));
        // Sync ke Firestore di background
        CloudSyncService.syncNutritionToCloud().catchError((_) {});
        _loadData();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.electricBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.electricBlue.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Icon(Icons.water_drop, color: AppTheme.electricBlue, size: 32),
            const SizedBox(height: 8),
            Text('+$ml ml', style: TextStyle(color: AppTheme.electricBlue, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  void _showAddProteinSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddNutritionSheet(
        currentSugar: _totalSugar,
        currentSalt: _totalSalt,
        currentFat: _totalFat,
        onSaved: () {
          Navigator.pop(context);
          _loadData();
        }
      ),
    );
  }
}

class _AddNutritionSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final double currentSugar;
  final double currentSalt;
  final double currentFat;

  const _AddNutritionSheet({
    required this.onSaved,
    required this.currentSugar,
    required this.currentSalt,
    required this.currentFat,
  });

  @override
  State<_AddNutritionSheet> createState() => _AddNutritionSheetState();
}

class _AddNutritionSheetState extends State<_AddNutritionSheet> {
  final _db = DatabaseHelper();
  final _amountCtrl = TextEditingController(text: '1');
  
  String _selectedMealType = 'lunch';
  final _mealTypes = [
    {'id': 'breakfast', 'label': 'Sarapan'},
    {'id': 'lunch', 'label': 'Makan Siang'},
    {'id': 'dinner', 'label': 'Makan Malam'},
    {'id': 'snack', 'label': 'Cemilan'},
  ];

  Map<String, dynamic>? _selectedFood;
  List<String> _frequentFoods = [];

  @override
  void initState() {
    super.initState();
    _autoSelectMealType();
    _loadFrequentFoods();
  }

  void _autoSelectMealType() {
    final hour = DateTime.now().hour;
    if (hour < 10) _selectedMealType = 'breakfast';
    else if (hour < 15) _selectedMealType = 'lunch';
    else if (hour < 20) _selectedMealType = 'dinner';
    else _selectedMealType = 'snack';
  }

  Future<void> _loadFrequentFoods() async {
    final freq = await _db.getFrequentFoods(mealType: _selectedMealType);
    if (mounted) {
      setState(() {
        _frequentFoods = freq;
      });
    }
  }

  Future<void> _save() async {
    if (_selectedFood == null) return;
    
    HapticFeedback.mediumImpact();
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('audio/click.mp3'));
    } catch (_) {}

    double qty = double.tryParse(_amountCtrl.text) ?? 1.0;

    final entry = ProteinEntry(
      foodName: _selectedFood!['name'],
      proteinGrams: (_selectedFood!['protein'] as double) * qty,
      calories: (_selectedFood!['calories'] as double) * qty,
      carbsGrams: (_selectedFood!['carbs'] as double? ?? 0.0) * qty,
      fatGrams: (_selectedFood!['fat'] as double? ?? 0.0) * qty,
      fiberGrams: (_selectedFood!['fiber'] as double? ?? 0.0) * qty,
      sugarGrams: (_selectedFood!['sugar'] as double? ?? 0.0) * qty,
      saltGrams: (_selectedFood!['salt'] as double? ?? 0.0) * qty,
      mealType: _selectedMealType,
      date: DateTime.now(),
    );

    final totalSugar = widget.currentSugar + entry.sugarGrams;
    final totalSalt = widget.currentSalt + entry.saltGrams;
    final totalFat = widget.currentFat + entry.fatGrams;

    if (totalSugar > 50 || totalSalt > 5 || totalFat > 67) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.accentRed),
              const SizedBox(width: 8),
              Text('Peringatan GGL!', style: TextStyle(color: AppTheme.textPrimary)),
            ],
          ),
          content: Text(
            'Makanan ini akan membuat total harianmu melampaui batas aman medis (Gula 50g, Garam 5g, atau Lemak 67g). Risiko lonjakan insulin dan kalori berlebih! Yakin ingin melanjutkan?',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Batal', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Tetap Simpan', style: TextStyle(color: AppTheme.accentRed)),
            ),
          ],
        )
      );
      if (proceed != true) return;
    }

    await _db.insertProteinEntry(entry);
    // Sync ke Firestore di background
    CloudSyncService.syncNutritionToCloud().catchError((_) {});
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          Text('Catat Nutrisi Makanan', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          Autocomplete<Map<String, dynamic>>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                 if (_frequentFoods.isNotEmpty) {
                    final freqOptions = ProteinFoodDatabase.foods.where((f) => _frequentFoods.contains(f['name'])).take(5).toList();
                    freqOptions.sort((a, b) => _frequentFoods.indexOf(a['name'] as String).compareTo(_frequentFoods.indexOf(b['name'] as String)));
                    return freqOptions;
                 }
                 return const Iterable<Map<String, dynamic>>.empty();
              }
              final query = textEditingValue.text.toLowerCase();
              final matches = ProteinFoodDatabase.foods.where((food) => (food['name'] as String).toLowerCase().contains(query)).toList();
              matches.sort((a, b) {
                final idxA = _frequentFoods.indexOf(a['name'] as String);
                final idxB = _frequentFoods.indexOf(b['name'] as String);
                if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
                if (idxA != -1) return -1;
                if (idxB != -1) return 1;
                return 0;
              });
              return matches;
            },
            displayStringForOption: (option) => option['name'],
            onSelected: (selection) => setState(() => _selectedFood = selection),
            fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Cari Makanan', 
                  hintText: 'Mis: Telur, Nasi, Ayam...',
                  prefixIcon: Icon(Icons.search, color: AppTheme.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          
          if (_selectedFood != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _macroMini('Pro', _selectedFood!['protein'], AppTheme.neonGreen),
                  _macroMini('Carb', _selectedFood!['carbs'] ?? 0.0, Colors.orange),
                  _macroMini('Fat', _selectedFood!['fat'] ?? 0.0, Colors.pink),
                  _macroMini('Cal', _selectedFood!['calories'], AppTheme.accentOrange),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Porsi (100g/butir)'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedMealType,
                  dropdownColor: AppTheme.surface,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Waktu Makan'),
                  items: _mealTypes.map((m) => DropdownMenuItem(value: m['id'], child: Text(m['label']!))).toList(),
                  onChanged: (v) {
                    setState(() => _selectedMealType = v!);
                    _loadFrequentFoods();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedFood == null ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonGreen,
                disabledBackgroundColor: AppTheme.neonGreen.withOpacity(0.35),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'Simpan Makanan',
                style: TextStyle(
                  color: _selectedFood == null ? Colors.black45 : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroMini(String label, double val, Color c) {
    return Column(
      children: [
        Text('${val.toStringAsFixed(1)}g', style: TextStyle(color: c, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ],
    );
  }
}

/// Widget logo Gemini 4-warna untuk tombol FAB
class _GeminiIcon extends StatelessWidget {
  const _GeminiIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GeminiIconPainter()),
    );
  }
}

class _GeminiIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.48;

    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFF9C27B0),
      const Color(0xFFEA4335),
      const Color(0xFFFBBC04),
    ];

    final angles = [
      [-0.3, 0.3, 1.0, 0.0],    // kanan
      [0.7, 1.3, 0.0, -1.0],    // bawah
      [1.7, 2.3, -1.0, 0.0],    // kiri
      [2.7, 3.3, 0.0, 1.0],     // atas
    ];

    for (int i = 0; i < 4; i++) {
      final paint = Paint()..color = colors[i]..style = PaintingStyle.fill;
      final dx = angles[i][2] * r;
      final dy = angles[i][3] * r;
      final path = Path()
        ..moveTo(cx, cy)
        ..lineTo(cx + dx + dy * 0.25, cy + dy - dx * 0.25)
        ..lineTo(cx + dx * 1.1, cy + dy * 1.1)
        ..lineTo(cx + dx - dy * 0.25, cy + dy + dx * 0.25)
        ..close();
      canvas.drawPath(path, paint);
    }

    // Lingkaran putih di tengah
    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.18,
      Paint()..color = Colors.white.withOpacity(0.9),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

