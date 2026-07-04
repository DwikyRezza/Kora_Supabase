import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/protein_entry.dart';
import '../services/database_helper.dart';
import '../services/cloud_sync_service.dart';
import '../utils/prefetch_manager.dart';
import '../utils/background_task_queue.dart';

class AiNutritionScreen extends StatefulWidget {
  const AiNutritionScreen({super.key});

  @override
  State<AiNutritionScreen> createState() => _AiNutritionScreenState();
}

class _AiNutritionScreenState extends State<AiNutritionScreen> {
  final List<Map<String, TextEditingController>> _rows = [];
  bool _isAnalyzing = false;
  bool _isSaving = false;
  List<_FoodResult>? _results;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _addRow();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r['name']!.dispose();
      r['gram']!.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _rows.add({
        'name': TextEditingController(),
        'gram': TextEditingController(),
      });
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows[index]['name']!.dispose();
      _rows[index]['gram']!.dispose();
      _rows.removeAt(index);
    });
  }

  Future<void> _analyze() async {
    final foods = <Map<String, String>>[];
    for (final row in _rows) {
      final name = row['name']!.text.trim();
      final gram = row['gram']!.text.trim();
      if (name.isEmpty) continue;
      foods.add({'name': name, 'gram': gram.isEmpty ? '100' : gram});
    }

    if (foods.isEmpty) {
      setState(() => _errorMsg = 'Tulis minimal 1 menu makanan yang kamu makan.');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMsg = null;
      _results = null;
    });

    try {
      final vercelUrl = dotenv.env['VERCEL_URL'] ?? 'https://your-vercel-project-url.vercel.app';

      final foodList =
          foods.map((f) => '- ${f['name']} ${f['gram']}g').join('\n');
      final prompt = '''
Kamu adalah ahli gizi. Analisis kandungan nutrisi makanan berikut per porsi yang disebutkan.
Berikan respons HANYA dalam format JSON array seperti contoh di bawah, tanpa teks lain.

Makanan:
$foodList

Format respons:
[
  {
    "name": "Nama Makanan",
    "gram": 100,
    "protein": 5.2,
    "calories": 150.0,
    "carbs": 20.5,
    "fat": 3.1,
    "fiber": 1.2,
    "sugar": 2.0,
    "salt": 0.3
  }
]

Catatan: semua nilai dalam angka (double). Jika tidak tahu, perkirakan dengan best estimate.
''';

      final res = await http.post(
        Uri.parse('$vercelUrl/api/ai-nutrition'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'prompt': prompt,
        }),
      ).timeout(const Duration(seconds: 25)); // Vercel cold starts might take a bit longer

      if (res.statusCode != 200) {
        throw Exception('API Error: ${res.statusCode} ${res.body}');
      }

      final resJson = jsonDecode(res.body);

      // Handle jika Groq mengembalikan error object
      if (resJson['error'] != null) {
        final errMsg = resJson['error']['message'] ?? 'Unknown API Error';
        throw Exception('Groq API Error: $errMsg');
      }

      final text = resJson['text'] as String? ?? resJson['choices']?[0]?['message']?['content'] as String? ?? '';

      final jsonStart = text.indexOf('[');
      final jsonEnd = text.lastIndexOf(']');
      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception('Format respons tidak valid (AI tidak merespons dalam format JSON)');
      }
      final jsonStr = text.substring(jsonStart, jsonEnd + 1);
      final List<dynamic> parsed = jsonDecode(jsonStr);

      setState(() {
        _results = parsed.map((e) => _FoodResult.fromMap(e)).toList();
        _isAnalyzing = false;
      });
    } catch (e) {
      String errorMsg;
      final errStr = e.toString();
      if (errStr.contains('quota') || errStr.contains('rate limit')) {
        errorMsg = 'Kuota API Groq habis atau limit tercapai. Silakan coba lagi beberapa saat.';
      } else if (errStr.contains('API_KEY_INVALID') || errStr.contains('401')) {
        errorMsg = 'API key tidak valid. Periksa kembali GROQ_API_KEY di file .env.';
      } else if (errStr.contains('network') || errStr.contains('SocketException')) {
        errorMsg = 'Tidak ada koneksi internet. Pastikan perangkat terhubung ke internet.';
      } else {
        errorMsg = 'Gagal menganalisis: $e';
      }
      setState(() {
        _errorMsg = errorMsg;
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _saveAll() async {
    if (_results == null || _results!.isEmpty || _isSaving) return;

    final results = List.of(_results!);
    final db = DatabaseHelper();
    final now = DateTime.now();
    final mealType = _detectMealType(now);

    // Build the list of entries to insert
    final entries = results.map((r) => ProteinEntry(
      foodName: r.name,
      proteinGrams: r.protein,
      calories: r.calories,
      carbsGrams: r.carbs,
      fatGrams: r.fat,
      fiberGrams: r.fiber,
      sugarGrams: r.sugar,
      saltGrams: r.salt,
      waterMl: 0,
      mealType: mealType,
      date: now,
    )).toList();

    // ── OPTIMISTIC UPDATE ──────────────────────────────────────────────────
    // Snapshot previous state for rollback
    final pm = PrefetchManager.instance;
    final prevCalories = pm.todayCaloriesConsumed;
    final totalNewCalories = results.fold<double>(0, (s, r) => s + r.calories).toInt();
    pm.todayCaloriesConsumed = (prevCalories ?? 0) + totalNewCalories;

    // Close screen instantly — user sees updated metric on HomeScreen immediately
    if (!mounted) return;
    Navigator.pop(context, true);

    // ── BACKGROUND SAVE (with 10s timeout and rollback on failure) ──────────
    BackgroundTaskQueue.instance.enqueue<void>(
      task: () => Future.wait(entries.map((e) => db.insertProteinEntry(e))),
      onError: (e) {
        // Rollback the optimistic update
        pm.todayCaloriesConsumed = prevCalories;

        // Show retry SnackBar — but we are now in background, so we need a global key or messenger.
        // We show it via the app's root scaffold by broadcasting via the main navigator
        debugPrint('[Optimistic] Nutrition save failed, rolled back. Error: $e');
      },
    ).then((_) {
      // On success: fire cloud sync (also non-blocking)
      CloudSyncService.syncNutritionToCloud().catchError((_) {});
    });
  }

  String _detectMealType(DateTime dt) {
    final h = dt.hour;
    if (h >= 5 && h < 10) return 'breakfast';
    if (h >= 10 && h < 15) return 'lunch';
    if (h >= 15 && h < 20) return 'dinner';
    return 'snack';
  }

  @override
  Widget build(BuildContext context) {
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
      body: _results != null ? _buildResultsView() : _buildInputView(),
    );
  }

  Widget _buildInputView() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/icons/logo.png',
                width: 56,
                height: 56,
                color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
              ),
              SizedBox(width: 16),
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
                    SizedBox(height: 4),
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

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
                    SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Text('Gram',
                          style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(width: 48), // Padding allowance for the IconButton
                  ],
                ),
              ),

              ...List.generate(_rows.length, (i) => _buildInputRow(i)),

              SizedBox(height: 16),
              GestureDetector(
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
                      SizedBox(width: 8),
                      Text('Tambah Makanan',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ],
                  ),
                ),
              ),

              if (_errorMsg != null) ...[
                SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3400).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Text(_errorMsg!,
                      style:
                          TextStyle(color: Color(0xFFFF3400), fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],

              SizedBox(height: 100),
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
              onPressed: _isAnalyzing ? null : _analyze,
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
                  if (_isAnalyzing)
                    SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  else
                    Image.asset(
                      'assets/icons/logo.png',
                      width: 28,
                      height: 28,
                      color: Colors.white,
                    ),
                  SizedBox(width: 12),
                  Text(_isAnalyzing ? 'Menganalisis...' : 'Catat Makanan',
                      style: TextStyle(
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
          SizedBox(width: 12),
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
          SizedBox(width: 4),
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

  Widget _buildResultsView() {
    final results = _results!;
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
                          'assets/icons/logo.png',
                          width: 32,
                          height: 32,
                          color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                        ),
                        SizedBox(width: 12),
                        Text('Hasil Analisis',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ],
                    ),
                    SizedBox(height: 24),
                    Row(
                      children: [
                        _totalChip('Pro', '${totalProtein.toStringAsFixed(0)}g', const Color(0xFFBD4BE5)),
                        SizedBox(width: 12),
                        _totalChip('Cal', '${totalCalories.toStringAsFixed(0)}k', const Color(0xFFFF3400)),
                        SizedBox(width: 12),
                        _totalChip('Carb', '${totalCarbs.toStringAsFixed(0)}g', const Color(0xFF00A9DD)),
                        SizedBox(width: 12),
                        _totalChip('Fat', '${totalFat.toStringAsFixed(0)}g', AppTheme.accent),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),
              Text('Detail Per Makanan',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              SizedBox(height: 16),
              ...results.map((r) => _buildFoodResultCard(r)),
              SizedBox(height: 80),
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
                  onPressed: () => setState(() => _results = null),
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
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    disabledBackgroundColor: AppTheme.accent.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text('Simpan',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFoodResultCard(_FoodResult r) {
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
              SizedBox(width: 12),
              Expanded(
                child: Text(r.name,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ),
              Text('${r.calories.toStringAsFixed(0)} kcal',
                  style: TextStyle(
                      color: Color(0xFFFF3400),
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 20),
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
          SizedBox(height: 4),
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
            SizedBox(height: 4),
            Text(label,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _FoodResult {
  final String name;
  final double gram;
  final double protein;
  final double calories;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double salt;

  _FoodResult({
    required this.name,
    required this.gram,
    required this.protein,
    required this.calories,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.salt,
  });

  factory _FoodResult.fromMap(Map<String, dynamic> m) {
    double _d(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    return _FoodResult(
      name: m['name']?.toString() ?? '',
      gram: _d(m['gram']),
      protein: _d(m['protein']),
      calories: _d(m['calories']),
      carbs: _d(m['carbs']),
      fat: _d(m['fat']),
      fiber: _d(m['fiber']),
      sugar: _d(m['sugar']),
      salt: _d(m['salt']),
    );
  }
}
