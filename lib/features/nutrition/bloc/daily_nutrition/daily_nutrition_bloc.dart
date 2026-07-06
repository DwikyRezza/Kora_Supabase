import 'package:flutter_bloc/flutter_bloc.dart';
import 'daily_nutrition_event.dart';
import 'daily_nutrition_state.dart';
import '../../../../services/database_helper.dart';
import '../../../../services/profile_service.dart';
import '../../../../services/cloud_sync_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../models/protein_entry.dart';

class DailyNutritionBloc extends Bloc<DailyNutritionEvent, DailyNutritionState> {
  final DatabaseHelper _db = DatabaseHelper();

  DailyNutritionBloc() : super(const DailyNutritionState()) {
    on<DailyNutritionLoadRequested>(_onLoadRequested);
    on<DailyNutritionRefreshRequested>(_onRefreshRequested);
    on<DailyNutritionEntryDeleted>(_onEntryDeleted);
    on<DailyNutritionWaterAdded>(_onWaterAdded);
  }

  Future<void> _onLoadRequested(
    DailyNutritionLoadRequested event,
    Emitter<DailyNutritionState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      final today = DateTime.now();
      final entries = await _db.getProteinEntriesByDate(today);
      final profile = await ProfileService.getProfile();

      double targetProtein = profile[ProfileService.keyTargetProtein] ?? 150.0;
      if (targetProtein == 0) targetProtein = 150.0;

      final newState = state.copyWith(
        isLoading: false,
        entries: entries,
        targetProtein: targetProtein,
      );

      if (newState.totalProtein < targetProtein * 0.9) {
        NotificationService().scheduleNutritionReminders();
      } else {
        NotificationService().cancelNutritionReminders();
      }

      emit(newState);
    } catch (e) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onRefreshRequested(
    DailyNutritionRefreshRequested event,
    Emitter<DailyNutritionState> emit,
  ) async {
    try {
      await CloudSyncService.syncNutritionToCloud();
    } catch (_) {}
    add(DailyNutritionLoadRequested());
  }

  Future<void> _onEntryDeleted(
    DailyNutritionEntryDeleted event,
    Emitter<DailyNutritionState> emit,
  ) async {
    await _db.deleteProteinEntry(event.id);
    add(DailyNutritionLoadRequested());
  }

  Future<void> _onWaterAdded(
    DailyNutritionWaterAdded event,
    Emitter<DailyNutritionState> emit,
  ) async {
    await _db.insertProteinEntry(
      ProteinEntry(
        foodName: 'Air Putih (${event.label})',
        proteinGrams: 0,
        calories: 0,
        waterMl: event.ml,
        mealType: 'water',
        date: DateTime.now(),
      ),
    );
    try {
      await CloudSyncService.syncNutritionToCloud();
    } catch (_) {}
    add(DailyNutritionLoadRequested());
  }
}
