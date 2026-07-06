import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/models/food_result.dart';
import '../../bloc/ai_nutrition/nutrition_bloc.dart';
import '../../bloc/ai_nutrition/nutrition_event.dart';
import '../../bloc/ai_nutrition/nutrition_state.dart';

class AiNutritionScreen extends StatefulWidget {
  const AiNutritionScreen({super.key});

  @override
  State<AiNutritionScreen> createState() => _AiNutritionScreenState();
}

class _AiNutritionScreenState extends State<AiNutritionScreen> {
  late final NutritionBloc _bloc;
  final List<Map<String, TextEditingController>> _rows = [];

  @override
  void initState() {
    super.initState();
    _bloc = NutritionBloc();
    _addRow();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r['name']!.dispose();
      r['gram']!.dispose();
    }
    _bloc.close();
    super.dispose();
  }

  void _syncRowsWithState(int stateRowCount) {
    while (_rows.length < stateRowCount) {
      _rows.add({
        'name': TextEditingController(),
        'gram': TextEditingController(),
      });
    }
    while (_rows.length > stateRowCount && _rows.length > 1) {
      final removed = _rows.removeLast();
      removed['name']!.dispose();
      removed['gram']!.dispose();
    }
  }

  void _addRow() {
    _bloc.add(NutritionAddRow());
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    final r = _rows.removeAt(index);
    r['name']!.dispose();
    r['gram']!.dispose();
    _bloc.add(NutritionRemoveRow(index));
  }

  void _analyze() {
    final foods = <Map<String, String>>[];
    for (final row in _rows) {
      final name = row['name']!.text.trim();
      final gram = row['gram']!.text.trim();
      if (name.isEmpty) continue;
      foods.add({'name': name, 'gram': gram.isEmpty ? '100' : gram});
    }
    _bloc.add(NutritionAnalyzeRequested(foods));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocConsumer<NutritionBloc, NutritionState>(
        listener: (context, state) {
          if (state.isSuccess) {
            Navigator.pop(context, true);
          }
        },
        builder: (context, state) {
          _syncRowsWithState(state.rowCount);
          
          return Scaffold(
            backgroundColor: AppTheme.surface,
            appBar: AppBar(
              backgroundColor: AppTheme.surface,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              title: Row(
                children: [
                  Text('Catat Makanan', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5)),
                ],
              ),
            ),
            body: state.results != null ? _buildResultsView(state) : _buildInputView(state),
          );
        },
      ),
    );
  }

  Widget _buildInputView(NutritionState state) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icons/logoNObg.png',
                      width: 56,
                      height: 56,
                      color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Catat Apa yang Kamu Makan',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tulis menu makananmu secara natural.',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24).copyWith(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 7,
                      child: Text('Menu Makanan',
                          style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Text('Gram',
                          style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              ...List.generate(_rows.length, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildInputRow(i)
              )),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                  onTap: _addRow,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: AppTheme.surfaceVariant,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline_rounded,
                            color: AppTheme.textPrimary, size: 24),
                        const SizedBox(width: 8),
                        Text('Tambah Makanan',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
              if (state.errorMsg != null) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3400).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Text(state.errorMsg!,
                        style:
                            const TextStyle(color: Color(0xFFFF3400), fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          color: AppTheme.surface,
          child: SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: state.isAnalyzing ? null : _analyze,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                disabledBackgroundColor: AppTheme.accent.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (state.isAnalyzing)
                    const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  else
                    Image.asset(
                      'assets/icons/logoNObg.png',
                      width: 36,
                      height: 36,
                      color: Colors.white,
                    ),
                  const SizedBox(width: 12),
                  Text(state.isAnalyzing ? 'Menganalisis...' : 'Catat Makanan',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputRow(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 7,
            child: TextField(
              controller: _rows[index]['name'],
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: '2 butir telur...',
                hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 15),
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _rows[index]['gram'],
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '100g',
                hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 15),
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.remove_circle_outline_rounded,
                color: _rows.length > 1
                    ? const Color(0xFFFF3400)
                    : AppTheme.textMuted.withOpacity(0.5),
                size: 28),
            onPressed: _rows.length > 1 ? () => _removeRow(index) : null,
            padding: const EdgeInsets.all(4),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(NutritionState state) {
    final results = state.results!;
    final totalProtein = results.fold(0.0, (s, e) => s + e.protein);
    final totalCalories = results.fold(0.0, (s, e) => s + e.calories);
    final totalCarbs = results.fold(0.0, (s, e) => s + e.carbs);
    final totalFat = results.fold(0.0, (s, e) => s + e.fat);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/icons/logoNObg.png',
                          width: 32,
                          height: 32,
                          color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                        ),
                        const SizedBox(width: 12),
                        Text('Hasil Analisis',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _totalChip('Pro', '${totalProtein.toStringAsFixed(0)}g', const Color(0xFFBD4BE5)),
                        const SizedBox(width: 12),
                        _totalChip('Cal', '${totalCalories.toStringAsFixed(0)}k', const Color(0xFFFF3400)),
                        const SizedBox(width: 12),
                        _totalChip('Carb', '${totalCarbs.toStringAsFixed(0)}g', const Color(0xFF00A9DD)),
                        const SizedBox(width: 12),
                        _totalChip('Fat', '${totalFat.toStringAsFixed(0)}g', AppTheme.accent),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text('Detail Per Makanan',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              const SizedBox(height: 16),
              ...results.map((r) => _buildFoodResultCard(r)),
              const SizedBox(height: 80),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          color: AppTheme.surface,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  // ignore: invalid_use_of_visible_for_testing_member
                  onPressed: () => _bloc.emit(_bloc.state.clearState()),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.surfaceVariant, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                  ),
                  child: Text('Ulangi',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: state.isSaving ? null : () => _bloc.add(NutritionSaveRequested()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    disabledBackgroundColor: AppTheme.accent.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                    elevation: 0,
                  ),
                  child: state.isSaving
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Simpan',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFoodResultCard(FoodResult r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('${r.gram.toStringAsFixed(0)}g',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(r.name,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ),
              Text('${r.calories.toStringAsFixed(0)} kcal',
                  style: const TextStyle(
                      color: Color(0xFFFF3400),
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _miniNutrient('Protein', r.protein, const Color(0xFFBD4BE5)),
              _miniNutrient('Karbo', r.carbs, const Color(0xFF00A9DD)),
              _miniNutrient('Lemak', r.fat, AppTheme.accent),
              _miniNutrient('Serat', r.fiber, AppTheme.textMuted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniNutrient(String label, double value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text('${value.toStringAsFixed(1)}g',
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _totalChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
