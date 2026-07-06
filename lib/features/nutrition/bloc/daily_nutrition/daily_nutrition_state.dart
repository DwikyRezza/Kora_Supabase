import 'package:equatable/equatable.dart';
import '../../../../models/protein_entry.dart';

class DailyNutritionState extends Equatable {
  final bool isLoading;
  final List<ProteinEntry> entries;
  final double targetProtein;
  final double targetCalories;

  const DailyNutritionState({
    this.isLoading = true,
    this.entries = const [],
    this.targetProtein = 150.0,
    this.targetCalories = 2500.0,
  });

  DailyNutritionState copyWith({
    bool? isLoading,
    List<ProteinEntry>? entries,
    double? targetProtein,
    double? targetCalories,
  }) {
    return DailyNutritionState(
      isLoading: isLoading ?? this.isLoading,
      entries: entries ?? this.entries,
      targetProtein: targetProtein ?? this.targetProtein,
      targetCalories: targetCalories ?? this.targetCalories,
    );
  }

  double get totalProtein => entries.fold(0, (sum, e) => sum + e.proteinGrams);
  double get totalCalories => entries.fold(0, (sum, e) => sum + e.calories);
  double get totalCarbs => entries.fold(0, (sum, e) => sum + e.carbsGrams);
  double get totalFat => entries.fold(0, (sum, e) => sum + e.fatGrams);

  @override
  List<Object?> get props => [
        isLoading,
        entries,
        targetProtein,
        targetCalories,
      ];
}
