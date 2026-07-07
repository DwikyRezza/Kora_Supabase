import 'package:equatable/equatable.dart';

enum SocialNetworkStatus { initial, loading, success, failure }

class SocialNetworkState extends Equatable {
  final SocialNetworkStatus status;
  final List<Map<String, dynamic>> followers;
  final List<Map<String, dynamic>> following;
  final String? errorMessage;
  final String uid;

  const SocialNetworkState({
    this.status = SocialNetworkStatus.initial,
    this.followers = const [],
    this.following = const [],
    this.errorMessage,
    this.uid = '',
  });

  SocialNetworkState copyWith({
    SocialNetworkStatus? status,
    List<Map<String, dynamic>>? followers,
    List<Map<String, dynamic>>? following,
    String? errorMessage,
    String? uid,
  }) {
    return SocialNetworkState(
      status: status ?? this.status,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      errorMessage: errorMessage ?? this.errorMessage,
      uid: uid ?? this.uid,
    );
  }

  @override
  List<Object?> get props => [status, followers, following, errorMessage, uid];
}
