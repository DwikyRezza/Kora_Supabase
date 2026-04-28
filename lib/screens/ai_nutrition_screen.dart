import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/protein_entry.dart';
import '../services/database_helper.dart';
import '../services/cloud_sync_service.dart';
import '../theme/app_theme.dart';
import '../secrets.dart'; // Import file rahasia

class AiNutritionScreen extends StatefulWidget {
  const AiNutritionScreen({super.key});

  @override
  State<AiNutritionScreen> createState() => _AiNutritionScreenState();
}

class _AiNutritionScreenState extends State<AiNutritionScreen> {
  // Setiap row = {name: controller, gram: controller}
  final List<Map<String, TextEditingController>> _rows = [];
  bool _isAnalyzing = false;
  List<_FoodResult>? _results;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _addRow(); // mulai dengan 1 baris
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
    // Validasi input
    final foods = <Map<String, String>>[];
    for (final row in _rows) {
      final name = row['name']!.text.trim();
      final gram = row['gram']!.text.trim();
      if (name.isEmpty) continue;
      foods.add({'name': name, 'gram': gram.isEmpty ? '100' : gram});
    }

    if (foods.isEmpty) {
      setState(() => _errorMsg = 'Masukkan minimal 1 nama makanan.');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMsg = null;
      _results = null;
    });

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: geminiApiKey, // Menggunakan key dari secrets.dart
      );

      // Buat prompt daftar makanan
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

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';

      // Ekstrak JSON dari respons
      final jsonStart = text.indexOf('[');
      final jsonEnd = text.lastIndexOf(']');
      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception('Format respons tidak valid');
      }
      final jsonStr = text.substring(jsonStart, jsonEnd + 1);
      final List<dynamic> parsed = jsonDecode(jsonStr);

      setState(() {
        _results = parsed.map((e) => _FoodResult.fromMap(e)).toList();
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Gagal menganalisis: $e';
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _saveAll() async {
    if (_results == null || _results!.isEmpty) return;

    final db = DatabaseHelper();
    final now = DateTime.now();

    for (final result in _results!) {
      final entry = ProteinEntry(
        foodName: result.name,
        proteinGrams: result.protein,
        calories: result.calories,
        carbsGrams: result.carbs,
        fatGrams: result.fat,
        fiberGrams: result.fiber,
        sugarGrams: result.sugar,
        saltGrams: result.salt,
        waterMl: 0,
        mealType: _detectMealType(now),
        date: now,
      );
      await db.insertProteinEntry(entry);
    }

    // Sync ke cloud
    CloudSyncService.syncNutritionToCloud().catchError((_) {});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_results!.length} makanan berhasil dicatat!'),
        backgroundColor: AppTheme.neonGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.pop(context, true); // true = ada data baru
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
              'Catat Nutrisi AI',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 8),
            _GeminiLogo(),
          ],
        ),
      ),
      body: _results != null ? _buildResultsView() : _buildInputView(),
    );
  }

  // ── Input View ──────────────────────────────────────────────────────────────
  Widget _buildInputView() {
    return Column(
      children: [
        // Header info
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4285F4).withOpacity(0.15),
                const Color(0xFF9C27B0).withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4285F4).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              _GeminiLogo(size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analisis Nutrisi dengan Gemini AI',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ketik nama makanan & beratnya. Tambah baris untuk beberapa makanan sekaligus.',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Daftar baris makanan
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header kolom
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text('Nama Makanan',
                          style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: Text('Gram',
                          style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 36),
                  ],
                ),
              ),

              // Baris-baris input
              ...List.generate(_rows.length, (i) => _buildInputRow(i)),

              // Tombol tambah baris
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _addRow,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.neonGreen.withOpacity(0.4),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline_rounded,
                          color: AppTheme.neonGreen, size: 18),
                      const SizedBox(width: 8),
                      Text('Tambah Makanan',
                          style: TextStyle(
                              color: AppTheme.neonGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),

              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppTheme.accentRed.withOpacity(0.4)),
                  ),
                  child: Text(_errorMsg!,
                      style:
                          TextStyle(color: AppTheme.accentRed, fontSize: 13)),
                ),
              ],

              const SizedBox(height: 100),
            ],
          ),
        ),

        // Tombol Analisis
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: AppTheme.background,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isAnalyzing ? null : _analyze,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF4285F4), const Color(0xFF9C27B0)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _isAnalyzing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            const Text('Menganalisis...',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _GeminiLogo(size: 22),
                            const SizedBox(width: 10),
                            const Text('Analisis dengan Gemini',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputRow(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Nomor
          Container(
            width: 24,
            height: 48,
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          // Nama makanan
          Expanded(
            flex: 5,
            child: TextField(
              controller: _rows[index]['name'],
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'cth: Ayam Pop',
                hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppTheme.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: const Color(0xFF4285F4), width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Gram
          SizedBox(
            width: 72,
            child: TextField(
              controller: _rows[index]['gram'],
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: '100',
                hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppTheme.surface,
                suffixText: 'g',
                suffixStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: const Color(0xFF4285F4), width: 2),
                ),
              ),
            ),
          ),
          // Tombol hapus baris
          IconButton(
            icon: Icon(Icons.remove_circle_outline_rounded,
                color: _rows.length > 1
                    ? AppTheme.accentRed.withOpacity(0.7)
                    : AppTheme.border,
                size: 22),
            onPressed: _rows.length > 1 ? () => _removeRow(index) : null,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ── Results View ────────────────────────────────────────────────────────────
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
            padding: const EdgeInsets.all(16),
            children: [
              // Total summary card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4285F4).withOpacity(0.15),
                      const Color(0xFF9C27B0).withOpacity(0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF4285F4).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _GeminiLogo(size: 20),
                        const SizedBox(width: 8),
                        Text('Total ${results.length} Makanan',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _totalChip(
                            'Protein',
                            '${totalProtein.toStringAsFixed(1)}g',
                            const Color(0xFF4285F4)),
                        const SizedBox(width: 8),
                        _totalChip(
                            'Kalori',
                            '${totalCalories.toStringAsFixed(0)}kal',
                            AppTheme.accentOrange),
                        const SizedBox(width: 8),
                        _totalChip('Karbo', '${totalCarbs.toStringAsFixed(1)}g',
                            AppTheme.neonGreen),
                        const SizedBox(width: 8),
                        _totalChip('Lemak', '${totalFat.toStringAsFixed(1)}g',
                            const Color(0xFF9C27B0)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Detail Per Makanan',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const SizedBox(height: 10),
              // Kartu per makanan
              ...results.map((r) => _buildFoodResultCard(r)),
              const SizedBox(height: 80),
            ],
          ),
        ),

        // Tombol Simpan Semua
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: AppTheme.background,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              // Tombol Ulangi
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _results = null),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Ulangi',
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              // Tombol Simpan
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _saveAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Simpan Semua',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${r.gram.toStringAsFixed(0)}g',
                    style: const TextStyle(
                        color: Color(0xFF4285F4),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(r.name,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
              Text('${r.calories.toStringAsFixed(0)} kal',
                  style: TextStyle(
                      color: AppTheme.accentOrange,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _miniNutrient('Protein', r.protein, const Color(0xFF4285F4)),
              _miniNutrient('Karbo', r.carbs, AppTheme.neonGreen),
              _miniNutrient('Lemak', r.fat, const Color(0xFF9C27B0)),
              _miniNutrient('Serat', r.fiber, AppTheme.accentOrange),
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
                  color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          Text(label,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _totalChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w800)),
            Text(label,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Model hasil Gemini ───────────────────────────────────────────────────────
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

// ── Widget Logo Gemini ───────────────────────────────────────────────────────
class _GeminiLogo extends StatelessWidget {
  final double size;
  const _GeminiLogo({this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GeminiPainter()),
    );
  }
}

class _GeminiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Bintang Gemini 4-pointed
    final colors = [
      const Color(0xFF4285F4), // biru
      const Color(0xFF9C27B0), // ungu
      const Color(0xFFEA4335), // merah
      const Color(0xFFFBBC04), // kuning
    ];

    for (int i = 0; i < 4; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;
      final angle = (i * 90) * (3.14159 / 180);
      final cos = _cos(angle);
      final sin = _sin(angle);
      final r = size.width * 0.45;
      final path = Path()
        ..moveTo(cx, cy)
        ..lineTo(cx + r * cos - r * 0.18 * sin, cy + r * sin + r * 0.18 * cos)
        ..lineTo(cx + r * cos, cy + r * sin)
        ..lineTo(cx + r * cos + r * 0.18 * sin, cy + r * sin - r * 0.18 * cos)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  double _cos(double a) => (a == 0)
      ? 1
      : (a == 1.5708)
          ? 0
          : (a == 3.14159)
              ? -1
              : 0;
  double _sin(double a) => (a == 0)
      ? 0
      : (a == 1.5708)
          ? 1
          : (a == 3.14159)
              ? 0
              : -1;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
