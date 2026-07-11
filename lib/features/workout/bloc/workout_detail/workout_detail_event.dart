import 'package:equatable/equatable.dart';

abstract class WorkoutDetailEvent extends Equatable {
  const WorkoutDetailEvent();

  @override
  List<Object?> get props => [];
}

class WorkoutDetailLoadRequested extends WorkoutDetailEvent {
  final String? authorName;
  final String? authorPhotoUrl;

  const WorkoutDetailLoadRequested({this.authorName, this.authorPhotoUrl});

  @override
  List<Object?> get props => [authorName, authorPhotoUrl];
}

class WorkoutDetailPhotoAdded extends WorkoutDetailEvent {
  final String workoutId;
  final String imagePath;

  const WorkoutDetailPhotoAdded(this.workoutId, this.imagePath);

  @override
  List<Object?> get props => [workoutId, imagePath];
}

class WorkoutDetailDeleted extends WorkoutDetailEvent {
  final String workoutId;

  const WorkoutDetailDeleted(this.workoutId);

  @override
  List<Object?> get props => [workoutId];
}
