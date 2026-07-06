import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../models/body_measurement.dart';
import '../../../../../services/database_helper.dart';
import '../../../../../services/profile_service.dart';
import '../../../../../services/cloud_sync_service.dart';
import 'body_stats_event.dart';
import 'body_stats_state.dart';

class BodyStatsBloc extends Bloc<BodyStatsEvent, BodyStatsState> {
  final DatabaseHelper _db = DatabaseHelper();

  BodyStatsBloc() : super(const BodyStatsState()) {
    on<LoadBodyStats>(_onLoadBodyStats);
    on<RefreshBodyStats>(_onRefreshBodyStats);
    on<AddBodyMeasurement>(_onAddBodyMeasurement);
    on<DeleteBodyMeasurement>(_onDeleteBodyMeasurement);
  }

  Future<void> _onLoadBodyStats(LoadBodyStats event, Emitter<BodyStatsState> emit) async {
    emit(state.copyWith(status: BodyStatsStatus.loading));
    try {
      final data = await _db.getAllBodyMeasurements();

      // Seed from profile for the first time if empty
      if (data.isEmpty) {
        final profile = await ProfileService.getProfile();
        final weight = profile[ProfileService.keyWeight] ?? 0.0;
        final height = profile[ProfileService.keyHeight] ?? 0.0;

        if (weight > 0 && height > 0) {
          final initial = BodyMeasurement(
            weight: weight,
            height: height,
            date: DateTime.now().subtract(const Duration(days: 7)),
          );
          await _db.insertBodyMeasurement(initial);
          data.add(initial);
        }
      }
      
      emit(state.copyWith(
        status: BodyStatsStatus.success,
        measurements: data,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: BodyStatsStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRefreshBodyStats(RefreshBodyStats event, Emitter<BodyStatsState> emit) async {
    try {
      await CloudSyncService.syncBodyMeasurementsToCloud();
    } catch (_) {} // Silent fail on offline
    add(LoadBodyStats());
  }

  Future<void> _onAddBodyMeasurement(AddBodyMeasurement event, Emitter<BodyStatsState> emit) async {
    emit(state.copyWith(status: BodyStatsStatus.loading));
    try {
      final m = BodyMeasurement(
        weight: event.weight,
        height: event.height,
        date: DateTime.now(),
      );
      await _db.insertBodyMeasurement(m);

      // Update base profile with the new weight and height
      final prefs = await ProfileService.getProfile();
      final name = prefs[ProfileService.keyName] ?? "Athlete";
      final age = prefs[ProfileService.keyAge] ?? 20;
      final gender = prefs[ProfileService.keyGender] ?? "Pria";
      final goal = prefs[ProfileService.keyGoal] ?? "Bulking";

      await ProfileService.saveProfile(
        name: name,
        username: name.toLowerCase().replaceAll(' ', '_'),
        age: age,
        gender: gender,
        weight: event.weight,
        height: event.height,
        goal: goal,
        status: prefs['status'] ?? "",
      );

      // Try sync
      try {
        await CloudSyncService.syncBodyMeasurementsToCloud();
      } catch (_) {}

      add(LoadBodyStats());
    } catch (e) {
      emit(state.copyWith(
        status: BodyStatsStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onDeleteBodyMeasurement(DeleteBodyMeasurement event, Emitter<BodyStatsState> emit) async {
    emit(state.copyWith(status: BodyStatsStatus.loading));
    try {
      await _db.deleteBodyMeasurement(event.id);
      add(LoadBodyStats());
    } catch (e) {
      emit(state.copyWith(
        status: BodyStatsStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }
}
