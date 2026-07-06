import 'package:equatable/equatable.dart';

abstract class NutritionEvent extends Equatable {
  const NutritionEvent();

  @override
  List<Object?> get props => [];
}

class NutritionAddRow extends NutritionEvent {}

class NutritionRemoveRow extends NutritionEvent {
  final int index;
  const NutritionRemoveRow(this.index);

  @override
  List<Object?> get props => [index];
}

class NutritionAnalyzeRequested extends NutritionEvent {
  final List<Map<String, String>> foods;
  const NutritionAnalyzeRequested(this.foods);

  @override
  List<Object?> get props => [foods];
}

class NutritionSaveRequested extends NutritionEvent {}
