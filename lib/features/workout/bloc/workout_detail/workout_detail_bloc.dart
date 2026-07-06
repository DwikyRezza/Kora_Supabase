import 'package:flutter_bloc/flutter_bloc.dart';
import 'workout_detail_event.dart';
import 'workout_detail_state.dart';
import '../../../../services/profile_service.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/database_helper.dart';

class WorkoutDetailBloc extends Bloc<WorkoutDetailEvent, WorkoutDetailState> {
  final DatabaseHelper _db = DatabaseHelper();

  WorkoutDetailBloc() : super(const WorkoutDetailState()) {
    on<WorkoutDetailLoadRequested>(_onLoadRequested);
    on<WorkoutDetailPhotoAdded>(_onPhotoAdded);
    on<WorkoutDetailDeleted>(_onDeleted);
  }

  Future<void> _onLoadRequested(
    WorkoutDetailLoadRequested event,
    Emitter<WorkoutDetailState> emit,
  ) async {
    emit(state.copyWith(status: WorkoutDetailStatus.loading));

    if (event.authorName != null && event.authorName!.isNotEmpty) {
      emit(state.copyWith(
        status: WorkoutDetailStatus.success,
        userName: event.authorName,
        userPhotoUrl: event.authorPhotoUrl,
      ));
      return;
    }

    try {
      final profile = await ProfileService.getProfile();
      String name = profile[ProfileService.keyName] ?? '';
      if (name.isEmpty) name = AuthService.displayName;
      if (name.isEmpty) name = 'Atlet';
      
      emit(state.copyWith(
        status: WorkoutDetailStatus.success,
        userName: name,
        userPhotoUrl: profile['photoUrl'] ?? AuthService.photoUrl,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: WorkoutDetailStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onPhotoAdded(
    WorkoutDetailPhotoAdded event,
    Emitter<WorkoutDetailState> emit,
  ) async {
    try {
      await _db.addWorkoutPhoto(event.workoutId, event.imagePath);
      emit(state.copyWith(
        photoRefreshKey: state.photoRefreshKey + 1,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: WorkoutDetailStatus.failure,
        errorMessage: 'Gagal menambahkan foto: ${e.toString()}',
      ));
    }
  }

  Future<void> _onDeleted(
    WorkoutDetailDeleted event,
    Emitter<WorkoutDetailState> emit,
  ) async {
    emit(state.copyWith(status: WorkoutDetailStatus.loading));
    try {
      await _db.deleteWorkout(event.workoutId);
      emit(state.copyWith(status: WorkoutDetailStatus.deleted));
    } catch (e) {
      emit(state.copyWith(
        status: WorkoutDetailStatus.failure,
        errorMessage: 'Gagal menghapus latihan: ${e.toString()}',
      ));
    }
  }
}
