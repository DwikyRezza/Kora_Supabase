import 'package:equatable/equatable.dart';

abstract class PublicProfileEvent extends Equatable {
  const PublicProfileEvent();

  @override
  List<Object?> get props => [];
}

class LoadPublicProfile extends PublicProfileEvent {
  final String uid;
  final bool silent;

  const LoadPublicProfile(this.uid, {this.silent = false});

  @override
  List<Object?> get props => [uid, silent];
}

class ToggleFollow extends PublicProfileEvent {
  final String uid;

  const ToggleFollow(this.uid);

  @override
  List<Object?> get props => [uid];
}
