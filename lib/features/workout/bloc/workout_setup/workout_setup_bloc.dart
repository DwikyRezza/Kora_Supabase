import 'package:flutter_bloc/flutter_bloc.dart';
import 'workout_setup_event.dart';
import 'workout_setup_state.dart';

class WorkoutSetupBloc extends Bloc<WorkoutSetupEvent, WorkoutSetupState> {
  WorkoutSetupBloc() : super(const WorkoutSetupState()) {
    on<WorkoutSetupInit>(_onInit);
    on<WorkoutSetupModeSelected>(_onModeSelected);
    on<WorkoutSetupMuscleToggled>(_onMuscleToggled);
    on<WorkoutSetupSearchQueryChanged>(_onSearchQueryChanged);
    on<WorkoutSetupExerciseToggled>(_onExerciseToggled);
    on<WorkoutSetupExerciseSetsChanged>(_onExerciseSetsChanged);
    on<WorkoutSetupExerciseReordered>(_onExerciseReordered);
    on<WorkoutSetupNextPageRequested>(_onNextPageRequested);
    on<WorkoutSetupPrevPageRequested>(_onPrevPageRequested);
    on<WorkoutSetupPageChanged>(_onPageChanged);
  }

  void _onInit(WorkoutSetupInit event, Emitter<WorkoutSetupState> emit) {
    emit(const WorkoutSetupState());
  }

  void _onModeSelected(WorkoutSetupModeSelected event, Emitter<WorkoutSetupState> emit) {
    emit(state.copyWith(selectedMode: event.mode));
  }

  void _onMuscleToggled(WorkoutSetupMuscleToggled event, Emitter<WorkoutSetupState> emit) {
    final newMuscles = Set<String>.from(state.selectedMuscles);
    if (newMuscles.contains(event.muscle)) {
      newMuscles.remove(event.muscle);
    } else {
      newMuscles.add(event.muscle);
    }
    emit(state.copyWith(selectedMuscles: newMuscles));
  }

  void _onSearchQueryChanged(WorkoutSetupSearchQueryChanged event, Emitter<WorkoutSetupState> emit) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onExerciseToggled(WorkoutSetupExerciseToggled event, Emitter<WorkoutSetupState> emit) {
    final newList = List<String>.from(state.selectedExerciseIds);
    if (newList.contains(event.exerciseId)) {
      newList.remove(event.exerciseId);
    } else {
      newList.add(event.exerciseId);
    }
    emit(state.copyWith(selectedExerciseIds: newList));
  }

  void _onExerciseSetsChanged(WorkoutSetupExerciseSetsChanged event, Emitter<WorkoutSetupState> emit) {
    final newSets = Map<String, int>.from(state.exerciseSets);
    newSets[event.exerciseId] = event.sets;
    emit(state.copyWith(exerciseSets: newSets));
  }

  void _onExerciseReordered(WorkoutSetupExerciseReordered event, Emitter<WorkoutSetupState> emit) {
    int oldIndex = event.oldIndex;
    int newIndex = event.newIndex;
    
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    
    final newList = List<String>.from(state.selectedExerciseIds);
    final item = newList.removeAt(oldIndex);
    newList.insert(newIndex, item);
    
    emit(state.copyWith(selectedExerciseIds: newList));
  }

  void _onNextPageRequested(WorkoutSetupNextPageRequested event, Emitter<WorkoutSetupState> emit) {
    if (state.currentPage < 3 && state.canProceedToNext) {
      emit(state.copyWith(currentPage: state.currentPage + 1));
    }
  }

  void _onPrevPageRequested(WorkoutSetupPrevPageRequested event, Emitter<WorkoutSetupState> emit) {
    if (state.currentPage > 0) {
      emit(state.copyWith(currentPage: state.currentPage - 1));
    }
  }

  void _onPageChanged(WorkoutSetupPageChanged event, Emitter<WorkoutSetupState> emit) {
    emit(state.copyWith(currentPage: event.pageIndex));
  }
}
