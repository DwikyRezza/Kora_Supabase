import 'package:equatable/equatable.dart';

abstract class BodyStatsEvent extends Equatable {
  const BodyStatsEvent();

  @override
  List<Object?> get props => [];
}

class LoadBodyStats extends BodyStatsEvent {}

class RefreshBodyStats extends BodyStatsEvent {}

class AddBodyMeasurement extends BodyStatsEvent {
  final double weight;
  final double height;

  const AddBodyMeasurement({required this.weight, required this.height});

  @override
  List<Object?> get props => [weight, height];
}

class DeleteBodyMeasurement extends BodyStatsEvent {
  final String id;

  const DeleteBodyMeasurement(this.id);

  @override
  List<Object?> get props => [id];
}
