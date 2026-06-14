import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/protein_entry.dart';
import '../services/database_helper.dart';
import '../services/profile_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
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
  final double _targetCalories = 2500.0; 
  int _targetWaterMl = 2000;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _refreshData() async {
    try {
      await CloudSyncService.syncNutritionToCloud();
    } catch (_) {}
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
      backgroundColor: Colors.white, // Flat UI: Pure White
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5406)))
            : RefreshIndicator(
                onRefresh: _refreshData,
                color: const Color(0xFFFF5406),
                backgroundColor: Colors.white,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 32),
                            _buildHeroRings(),
                            const SizedBox(height: 32),
                            const Text('Riwayat Hari Ini', style: TextStyle(color: Color(0xFF2F2F2F), fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    if (_entries.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Text('Belum ada asupan yang dicatat.', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final entry = _entries[index];
                            return _buildFoodRow(entry);
                          },
                          childCount: _entries.length,
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildStickyBottomActions(),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Nutrisi', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFFFF5406), letterSpacing: -1)),
            Text('Harian', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF2F2F2F), letterSpacing: -1, height: 0.9)),
          ],
        ),
        Row(
          children: [
             GestureDetector(
                onTap: _showAddWaterSheet,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(26)),
                  child: const Icon(Icons.water_drop, color: Color(0xFF00A9DD), size: 24),
                ),
             ),
             const SizedBox(width: 8),
             GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyReportScreen())),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(26)),
                  child: const Icon(Icons.calendar_month, color: Color(0xFF2F2F2F), size: 24),
                ),
             ),
          ],
        )
      ],
    );
  }

  Widget _buildHeroRings() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5), // Fog Gray
        borderRadius: BorderRadius.circular(26), // 26px radius everywhere
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _macroRing('Kalori', _totalCalories, _targetCalories, const Color(0xFFFF3400), 'kcal'),
              _macroRing('Protein', _totalProtein, _targetProtein, const Color(0xFFBD4BE5), 'g'),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _macroRing('Karbo', _totalCarbs, 250, const Color(0xFF00A9DD), 'g'),
              _macroRing('Lemak', _totalFat, 65, const Color(0xFF00B33F), 'g'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroRing(String label, double current, double target, Color color, String unit) {
    double progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 8,
                color: Colors.white, // background track
              ),
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                backgroundColor: Colors.transparent,
                color: color, // macro color
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(current.toStringAsFixed(0), style: const TextStyle(color: Color(0xFF2F2F2F), fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(unit, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFoodRow(ProteinEntry entry) {
    final isWater = entry.waterMl > 0 && entry.calories == 0;
    
    return Dismissible(
      key: Key('nut_${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: const Color(0xFFFF3400),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) async {
        await _db.deleteProteinEntry(entry.id!);
        CloudSyncService.syncNutritionToCloud().catchError((_) {});
        _loadData();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5), width: 1.5)), // Hairline separator
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.foodName, style: const TextStyle(color: Color(0xFF2F2F2F), fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    isWater 
                      ? '${entry.waterMl} ml • Hidrasi' 
                      : '${entry.calories.toStringAsFixed(0)} kcal • ${entry.mealLabel}', 
                    style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: isWater ? const Color(0xFF00A9DD) : const Color(0xFFBD4BE5),
                    shape: BoxShape.circle
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isWater ? 'Air' : '${entry.proteinGrams.toStringAsFixed(0)}g Pro',
                  style: TextStyle(
                    color: isWater ? const Color(0xFF00A9DD) : const Color(0xFFBD4BE5),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBottomActions() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AiNutritionScreen()));
                if (result == true) _loadData();
              },
              icon: const _GroqIcon(),
              label: const Text('Catat AI', style: TextStyle(color: Color(0xFF2F2F2F), fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5F5F5),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _showAddProteinSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5406), // Ember Orange
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Catat Makanan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddWaterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tambah Air Putih', style: TextStyle(color: Color(0xFF00A9DD), fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _waterButton(250, '1 Gelas'),
                  _waterButton(600, 'Botol Sedang'),
                  _waterButton(1000, 'Botol Besar'),
                ],
              ),
              const SizedBox(height: 32),
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
        CloudSyncService.syncNutritionToCloud().catchError((_) {});
        _loadData();
      },
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          children: [
            const Icon(Icons.water_drop, color: Color(0xFF00A9DD), size: 32),
            const SizedBox(height: 12),
            Text('+$ml ml', style: const TextStyle(color: Color(0xFF00A9DD), fontWeight: FontWeight.bold, fontSize: 16)),
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
  bool _isSaving = false;
  
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
    if (mounted) setState(() => _frequentFoods = freq);
  }

  Future<void> _save() async {
    if (_selectedFood == null || _isSaving) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

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

    // Offline-first: await ONLY SQLite write for instant feel
    await _db.insertProteinEntry(entry);

    // Non-blocking cloud sync (fire-and-forget)
    CloudSyncService.syncNutritionToCloud().catchError((_) {});

    // Immediately close sheet — user feels zero lag
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(32, 24, 32, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 24),
          const Text('Catat Makanan', style: TextStyle(color: Color(0xFF2F2F2F), fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
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
              return ProteinFoodDatabase.foods.where((food) => (food['name'] as String).toLowerCase().contains(query)).toList();
            },
            displayStringForOption: (option) => option['name'],
            onSelected: (selection) => setState(() => _selectedFood = selection),
            fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(color: Color(0xFF2F2F2F)),
                decoration: InputDecoration(
                  labelText: 'Cari Makanan', 
                  hintText: 'Mis: Nasi, Ayam...',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          
          if (_selectedFood != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(26)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _macroMini('Pro', _selectedFood!['protein'], const Color(0xFFBD4BE5)),
                  _macroMini('Carb', _selectedFood!['carbs'] ?? 0.0, const Color(0xFF00A9DD)),
                  _macroMini('Fat', _selectedFood!['fat'] ?? 0.0, const Color(0xFF00B33F)),
                  _macroMini('Cal', _selectedFood!['calories'], const Color(0xFFFF3400)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Color(0xFF2F2F2F)),
                  decoration: InputDecoration(
                    labelText: 'Porsi',
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedMealType,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Color(0xFF2F2F2F)),
                  decoration: InputDecoration(
                    labelText: 'Waktu',
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                  ),
                  items: _mealTypes.map((m) => DropdownMenuItem(value: m['id'], child: Text(m['label']!))).toList(),
                  onChanged: (v) {
                    setState(() => _selectedMealType = v!);
                    _loadFrequentFoods();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedFood == null || _isSaving) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5406),
                disabledBackgroundColor: const Color(0xFFFF5406).withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      'Simpan Makanan',
                      style: TextStyle(
                        color: _selectedFood == null ? Colors.white54 : Colors.white,
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
        Text('${val.toStringAsFixed(0)}g', style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _GroqIcon extends StatelessWidget {
  const _GroqIcon();
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GroqIconPainter()));
  }
}

class _GroqIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2F2F2F)
      ..style = PaintingStyle.fill;
    
    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.1)
      ..arcToPoint(Offset(size.width * 0.1, size.height * 0.5), radius: Radius.circular(size.width * 0.4), clockwise: false)
      ..arcToPoint(Offset(size.width * 0.5, size.height * 0.9), radius: Radius.circular(size.width * 0.4), clockwise: false)
      ..arcToPoint(Offset(size.width * 0.9, size.height * 0.5), radius: Radius.circular(size.width * 0.4), clockwise: false)
      ..lineTo(size.width * 0.5, size.height * 0.5)
      ..lineTo(size.width * 0.5, size.height * 0.65)
      ..lineTo(size.width * 0.7, size.height * 0.65)
      ..arcToPoint(Offset(size.width * 0.5, size.height * 0.75), radius: Radius.circular(size.width * 0.25))
      ..arcToPoint(Offset(size.width * 0.25, size.height * 0.5), radius: Radius.circular(size.width * 0.25))
      ..arcToPoint(Offset(size.width * 0.5, size.height * 0.25), radius: Radius.circular(size.width * 0.25));
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
