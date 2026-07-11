import 'package:equatable/equatable.dart';

abstract class DailyNutritionEvent extends Equatable {
  const DailyNutritionEvent();

  @override
  List<Object?> get props => [];
}

class DailyNutritionLoadRequested extends DailyNutritionEvent {}

class DailyNutritionRefreshRequested extends DailyNutritionEvent {}

class DailyNutritionEntryDeleted extends DailyNutritionEvent {
  final String id;
  const DailyNutritionEntryDeleted(this.id);

  @override
  List<Object?> get props => [id];
}

class DailyNutritionWaterAdded extends DailyNutritionEvent {
  final int ml;
  final String label;

  const DailyNutritionWaterAdded(this.ml, this.label);

  @override
  List<Object?> get props => [ml, label];
}
