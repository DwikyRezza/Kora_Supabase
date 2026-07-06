import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class ProfileLoadRequested extends ProfileEvent {
  final bool silent;
  
  const ProfileLoadRequested({this.silent = false});

  @override
  List<Object?> get props => [silent];
}

class ProfileRefreshRequested extends ProfileEvent {}
