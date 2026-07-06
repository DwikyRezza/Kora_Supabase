import 'package:flutter_bloc/flutter_bloc.dart';
import 'workout_main_event.dart';
import 'workout_main_state.dart';
import '../../../../services/database_helper.dart';
import '../../../../services/profile_service.dart';
import '../../../../services/cloud_sync_service.dart';
import '../../../../services/social_service.dart';
import '../../../../services/auth_service.dart';

class WorkoutMainBloc extends Bloc<WorkoutMainEvent, WorkoutMainState> {
  final DatabaseHelper _db = DatabaseHelper();

  WorkoutMainBloc() : super(const WorkoutMainState()) {
    on<WorkoutMainLoadRequested>(_onLoadRequested);
    on<WorkoutMainFilterChanged>(_onFilterChanged);
    on<WorkoutMainRefreshRequested>(_onRefreshRequested);
  }

  Future<void> _onLoadRequested(
    WorkoutMainLoadRequested event,
    Emitter<WorkoutMainState> emit,
  ) async {
    if (!event.silent) {
      emit(state.copyWith(isLoading: true));
    }

    try {
      final profile = await ProfileService.getProfile();
      final userName = profile[ProfileService.keyName] as String? ?? '';

      List<Map<String, dynamic>> userPosts = [];
      if (AuthService.isLoggedIn) {
        userPosts = await SocialService.getUserPosts(AuthService.uid);
      }

      emit(state.copyWith(
        isLoading: false,
        userPosts: userPosts,
        userName: userName,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onFilterChanged(
    WorkoutMainFilterChanged event,
    Emitter<WorkoutMainState> emit,
  ) async {
    emit(state.copyWith(activeFilter: event.filter));
  }

  Future<void> _onRefreshRequested(
    WorkoutMainRefreshRequested event,
    Emitter<WorkoutMainState> emit,
  ) async {
    try {
      await CloudSyncService.syncWorkoutsToCloud();
    } catch (_) {}
    
    add(const WorkoutMainLoadRequested(silent: true));
  }
}
