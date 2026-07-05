import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'running_event.dart';
import 'running_state.dart';
import '../../../models/workout.dart';
import '../../../services/database_helper.dart';
import '../../../services/cloud_sync_service.dart';
import '../../../services/social_service.dart';
import '../../../services/profile_service.dart';
import '../../../repositories/workout_repository.dart';

class RunningBloc extends Bloc<RunningEvent, RunningState> {
  final WorkoutRepository _workoutRepository;

  RunningBloc({required WorkoutRepository workoutRepository}) 
    : _workoutRepository = workoutRepository,
      super(const RunningState()) {
    on<RunningInit>((event, emit) {
      emit(const RunningState());
    });
    
    on<RunningStart>((event, emit) {
      emit(state.copyWith(status: RunningStatus.running));
    });

    on<RunningPause>((event, emit) {
      emit(state.copyWith(status: RunningStatus.paused));
    });

    on<RunningResume>((event, emit) {
      emit(state.copyWith(status: RunningStatus.running));
    });

    on<RunningStop>((event, emit) {
      emit(state.copyWith(status: RunningStatus.stopped));
    });

    on<RunningUpdateLocation>((event, emit) {
      final updatedRoute = List<LatLng>.from(state.routePoints)..add(event.location);
      emit(state.copyWith(
        currentLocation: event.location,
        routePoints: updatedRoute,
      ));
    });

    on<RunningUpdateMetrics>((event, emit) {
      String paceStr = '--:--';
      if (event.distance > 0.05) {
        final double minutes = event.elapsed / 60.0;
        final double paceDecimal = minutes / event.distance;
        final int paceMin = paceDecimal.floor();
        final int paceSec = ((paceDecimal - paceMin) * 60).round();
        if (paceMin < 60) {
          paceStr = '$paceMin:${paceSec.toString().padLeft(2, '0')}';
        }
      }
      emit(state.copyWith(
        distanceKm: event.distance,
        elapsedSeconds: event.elapsed,
        movingSeconds: event.movingTime,
        pace: paceStr,
      ));
    });

    on<RunningSaveWorkout>(_onSaveWorkout);
  }

  Future<void> _onSaveWorkout(RunningSaveWorkout event, Emitter<RunningState> emit) async {
    if (state.status == RunningStatus.saving) return;
    emit(state.copyWith(status: RunningStatus.saving));

    try {
      final workout = event.workout;
      await _workoutRepository.insertWorkout(workout);

      // Social Post
      try {
        final userProfile = await ProfileService.getProfile();
        await SocialService.publishWorkoutToFeed(workout.toMap());
      } catch (_) {}

      emit(state.copyWith(status: RunningStatus.success));
    } catch (e) {
      emit(state.copyWith(status: RunningStatus.error));
    }
  }
}
