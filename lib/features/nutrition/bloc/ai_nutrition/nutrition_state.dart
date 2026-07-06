import 'package:equatable/equatable.dart';
import '../../domain/models/food_result.dart';

class NutritionState extends Equatable {
  final int rowCount;
  final bool isAnalyzing;
  final bool isSaving;
  final bool isSuccess;
  final String? errorMsg;
  final List<FoodResult>? results;

  const NutritionState({
    this.rowCount = 1,
    this.isAnalyzing = false,
    this.isSaving = false,
    this.isSuccess = false,
    this.errorMsg,
    this.results,
  });

  NutritionState copyWith({
    int? rowCount,
    bool? isAnalyzing,
    bool? isSaving,
    bool? isSuccess,
    String? errorMsg,
    List<FoodResult>? results,
  }) {
    return NutritionState(
      rowCount: rowCount ?? this.rowCount,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      isSaving: isSaving ?? this.isSaving,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMsg: errorMsg, // we allow clearing the error msg
      results: results ?? this.results,
    );
  }

  // To easily clear errorMsg and results
  NutritionState clearState() {
    return NutritionState(
      rowCount: rowCount,
      isAnalyzing: false,
      isSaving: false,
      isSuccess: false,
      errorMsg: null,
      results: null,
    );
  }

  @override
  List<Object?> get props => [
        rowCount,
        isAnalyzing,
        isSaving,
        isSuccess,
        errorMsg,
        results,
      ];
}
