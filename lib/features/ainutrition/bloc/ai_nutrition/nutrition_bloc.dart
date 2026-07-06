import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/food_result.dart';
import 'nutrition_event.dart';
import 'nutrition_state.dart';

import '../../../../services/database_helper.dart';
import '../../../../services/cloud_sync_service.dart';
import '../../../../utils/prefetch_manager.dart';
import '../../../../utils/background_task_queue.dart';
import '../../../../models/protein_entry.dart';

class NutritionBloc extends Bloc<NutritionEvent, NutritionState> {
  NutritionBloc() : super(const NutritionState()) {
    on<NutritionAddRow>((event, emit) {
      emit(state.copyWith(rowCount: state.rowCount + 1));
    });

    on<NutritionRemoveRow>((event, emit) {
      if (state.rowCount > 1) {
        emit(state.copyWith(rowCount: state.rowCount - 1));
      }
    });

    on<NutritionAnalyzeRequested>(_onAnalyzeRequested);
    on<NutritionSaveRequested>(_onSaveRequested);
  }

  Future<void> _onAnalyzeRequested(
    NutritionAnalyzeRequested event,
    Emitter<NutritionState> emit,
  ) async {
    final foods = event.foods;
    if (foods.isEmpty) {
      emit(state.copyWith(errorMsg: 'Tulis minimal 1 menu makanan yang kamu makan.'));
      return;
    }

    emit(state.copyWith(isAnalyzing: true, errorMsg: null, results: null));

    try {
      final vercelUrl = dotenv.env['VERCEL_URL'] ?? 'https://your-vercel-project-url.vercel.app';

      final foodList = foods.map((f) => '- ${f['name']} ${f['gram']}g').join('\n');
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
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode != 200) {
        throw Exception('API Error: ${res.statusCode} ${res.body}');
      }

      final resJson = jsonDecode(res.body);

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

      final results = parsed.map((e) => FoodResult.fromMap(e)).toList();
      emit(state.copyWith(results: results, isAnalyzing: false));
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
      emit(state.copyWith(errorMsg: errorMsg, isAnalyzing: false));
    }
  }

  Future<void> _onSaveRequested(
    NutritionSaveRequested event,
    Emitter<NutritionState> emit,
  ) async {
    final results = state.results;
    if (results == null || results.isEmpty || state.isSaving) return;

    emit(state.copyWith(isSaving: true));

    final db = DatabaseHelper();
    final now = DateTime.now();
    final mealType = _detectMealType(now);

    final pm = PrefetchManager.instance;
    final prevCalories = pm.todayCaloriesConsumed;
    final prevProtein = pm.todayProtein;
    
    final totalNewCalories = results.fold<double>(0, (s, r) => s + r.calories).toInt();
    final totalNewProtein = results.fold<double>(0, (s, r) => s + r.protein);
    
    pm.todayCaloriesConsumed = (prevCalories ?? 0) + totalNewCalories;
    pm.todayProtein = (prevProtein ?? 0.0) + totalNewProtein;

    BackgroundTaskQueue.instance.enqueue<void>(
      task: () async {
        for (var r in results) {
          final entry = ProteinEntry(
            foodName: r.name,
            proteinGrams: r.protein,
            calories: r.calories,
            carbsGrams: r.carbs,
            fatGrams: r.fat,
            fiberGrams: r.fiber,
            sugarGrams: r.sugar,
            saltGrams: r.salt,
            date: now,
            mealType: mealType,
          );
          await db.insertProteinEntry(entry);
        }
      },
      onError: (e) {
        pm.todayCaloriesConsumed = prevCalories;
        pm.todayProtein = prevProtein;
      },
    ).then((_) {
      CloudSyncService.syncNutritionToCloud().catchError((_) {});
    });

    emit(state.copyWith(isSaving: false, isSuccess: true));
  }

  String _detectMealType(DateTime dt) {
    final h = dt.hour;
    if (h >= 5 && h < 10) return 'breakfast';
    if (h >= 10 && h < 15) return 'lunch';
    if (h >= 15 && h < 20) return 'dinner';
    return 'snack';
  }
}
