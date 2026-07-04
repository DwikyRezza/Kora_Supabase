import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import '../models/protein_entry.dart';
import '../services/database_helper.dart';
import '../services/profile_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/notification_service.dart';
import 'weekly_report_screen.dart';
import 'ai_nutrition_screen.dart';
import '../utils/responsive.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _refreshData() async {
    try {
      await CloudSyncService.syncNutritionToCloud();
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

        if (_totalProtein < _targetProtein * 0.9) {
          NotificationService().scheduleNutritionReminders();
        } else {
          NotificationService().cancelNutritionReminders();
        }

        _isLoading = false;
      });
    }
  }

  double get _totalProtein =>
      _entries.fold(0, (sum, e) => sum + e.proteinGrams);
  double get _totalCalories => _entries.fold(0, (sum, e) => sum + e.calories);
  double get _totalCarbs => _entries.fold(0, (sum, e) => sum + e.carbsGrams);
  double get _totalFat => _entries.fold(0, (sum, e) => sum + e.fatGrams);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface, // Flat UI: Pure White
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: AppTheme.accent))
            : RefreshIndicator(
                onRefresh: _refreshData,
                color: AppTheme.accent,
                backgroundColor: AppTheme.surface,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            SizedBox(height: 32),
                            _buildHeroRings(),
                            SizedBox(height: 32),
                            Text('Riwayat Hari Ini',
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    if (_entries.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Text('Belum ada asupan yang dicatat.',
                              style: TextStyle(color: AppTheme.textMuted)),
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
          children: [
            Text('Nutrisi',
                style: TextStyle(
                    fontSize: context.font3XL,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.accent,
                    letterSpacing: -1)),
            Text('Harian',
                style: TextStyle(
                    fontSize: context.font3XL,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    letterSpacing: -1,
                    height: 0.9)),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: _showAddWaterSheet,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(26)),
                child: Icon(Icons.water_drop,
                    color: Color(0xFF00A9DD), size: 24),
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
        color: AppTheme.surfaceVariant, // Fog Gray
        borderRadius: BorderRadius.circular(26), // 26px radius everywhere
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _macroRing('Kalori', _totalCalories, _targetCalories,
                  const Color(0xFFFF3400), 'kcal'),
              _macroRing('Protein', _totalProtein, _targetProtein,
                  const Color(0xFFBD4BE5), 'g'),
            ],
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _macroRing(
                  'Karbo', _totalCarbs, 250, const Color(0xFF00A9DD), 'g'),
              _macroRing('Lemak', _totalFat, 65, AppTheme.accent, 'g'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroRing(
      String label, double current, double target, Color color, String unit) {
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
                    Text(current.toStringAsFixed(0),
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: context.fontLG)),
                    Text(unit,
                        style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: context.fontXS,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          ),
        ),
        SizedBox(height: 12),
        Text(label,
            style: TextStyle(
                color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
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
        child: Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) async {
        await _db.deleteProteinEntry(entry.id!);
        CloudSyncService.syncNutritionToCloud().catchError((_) {});
        _loadData();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: AppTheme.surfaceVariant, width: 1.5)), // Hairline separator
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.foodName,
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  SizedBox(height: 4),
                  Text(
                      isWater
                          ? '${entry.waterMl} ml • Hidrasi'
                          : '${entry.calories.toStringAsFixed(0)} kcal • ${entry.mealLabel}',
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: isWater
                          ? const Color(0xFF00A9DD)
                          : const Color(0xFFBD4BE5),
                      shape: BoxShape.circle),
                ),
                SizedBox(width: 8),
                Text(
                  isWater
                      ? 'Air'
                      : '${entry.proteinGrams.toStringAsFixed(0)}g Pro',
                  style: TextStyle(
                    color: isWater
                        ? const Color(0xFF00A9DD)
                        : const Color(0xFFBD4BE5),
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
      color: AppTheme.background,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            final result = await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AiNutritionScreen()));
            if (result == true) _loadData();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icons/logoNObg.png',
                width: 36,
                height: 36,
                color: Colors.white,
              ),
              SizedBox(width: 10),
              Text('Catat Makanan',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddWaterSheet() {
    showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        builder: (_) {
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Tambah Air Putih',
                    style: TextStyle(
                        color: Color(0xFF00A9DD),
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _waterButton(250, '1 Gelas'),
                    _waterButton(600, 'Botol Sedang'),
                    _waterButton(1000, 'Botol Besar'),
                  ],
                ),
                SizedBox(height: 32),
              ],
            ),
          );
        });
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
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          children: [
            Icon(Icons.water_drop, color: Color(0xFF00A9DD), size: 32),
            SizedBox(height: 12),
            Text('+$ml ml',
                style: TextStyle(
                    color: Color(0xFF00A9DD),
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

