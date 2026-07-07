import 'package:equatable/equatable.dart';

abstract class SocialNetworkEvent extends Equatable {
  const SocialNetworkEvent();

  @override
  List<Object?> get props => [];
}

class LoadSocialData extends SocialNetworkEvent {
  final String uid;

  const LoadSocialData(this.uid);

  @override
  List<Object?> get props => [uid];
}

class UnfollowUserEvent extends SocialNetworkEvent {
  final String targetUid;

  const UnfollowUserEvent(this.targetUid);

  @override
  List<Object?> get props => [targetUid];
}

class RemoveFollowerEvent extends SocialNetworkEvent {
  final String followerUid;

  const RemoveFollowerEvent(this.followerUid);

  @override
  List<Object?> get props => [followerUid];
}
