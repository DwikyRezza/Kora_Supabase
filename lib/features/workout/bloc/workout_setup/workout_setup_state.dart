import 'package:equatable/equatable.dart';

class WorkoutSetupState extends Equatable {
  final int currentPage;
  final String? selectedMode; // 'bodyweight' | 'weighted'
  final Set<String> selectedMuscles;
  final List<String> selectedExerciseIds;
  final Map<String, int> exerciseSets;
  final String searchQuery;

  const WorkoutSetupState({
    this.currentPage = 0,
    this.selectedMode,
    this.selectedMuscles = const {},
    this.selectedExerciseIds = const [],
    this.exerciseSets = const {},
    this.searchQuery = '',
  });

  WorkoutSetupState copyWith({
    int? currentPage,
    String? selectedMode,
    Set<String>? selectedMuscles,
    List<String>? selectedExerciseIds,
    Map<String, int>? exerciseSets,
    String? searchQuery,
  }) {
    return WorkoutSetupState(
      currentPage: currentPage ?? this.currentPage,
      selectedMode: selectedMode ?? this.selectedMode,
      selectedMuscles: selectedMuscles ?? this.selectedMuscles,
      selectedExerciseIds: selectedExerciseIds ?? this.selectedExerciseIds,
      exerciseSets: exerciseSets ?? this.exerciseSets,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get canProceedToNext {
    if (currentPage == 0 && selectedMode != null) return true;
    if (currentPage == 1 && selectedMuscles.isNotEmpty) return true;
    if (currentPage == 2 && selectedExerciseIds.isNotEmpty) return true;
    if (currentPage == 3) return true;
    return false;
  }

  @override
  List<Object?> get props => [
        currentPage,
        selectedMode,
        selectedMuscles,
        selectedExerciseIds,
        exerciseSets,
        searchQuery,
      ];
}
