import 'package:equatable/equatable.dart';

abstract class WorkoutMainEvent extends Equatable {
  const WorkoutMainEvent();

  @override
  List<Object?> get props => [];
}

class WorkoutMainLoadRequested extends WorkoutMainEvent {
  final bool silent;
  const WorkoutMainLoadRequested({this.silent = false});
  
  @override
  List<Object?> get props => [silent];
}

class WorkoutMainFilterChanged extends WorkoutMainEvent {
  final String filter;
  const WorkoutMainFilterChanged(this.filter);

  @override
  List<Object?> get props => [filter];
}

class WorkoutMainRefreshRequested extends WorkoutMainEvent {}
