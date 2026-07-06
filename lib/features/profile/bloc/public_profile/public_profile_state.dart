import 'package:equatable/equatable.dart';

enum PublicProfileStatus { initial, loading, success, failure }

class PublicProfileState extends Equatable {
  final PublicProfileStatus status;
  final Map<String, dynamic>? userProfile;
  final List<Map<String, dynamic>> userPosts;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final bool isMe;
  final bool isProcessingFollow;
  final String? errorMessage;

  const PublicProfileState({
    this.status = PublicProfileStatus.initial,
    this.userProfile,
    this.userPosts = const [],
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.isMe = false,
    this.isProcessingFollow = false,
    this.errorMessage,
  });

  PublicProfileState copyWith({
    PublicProfileStatus? status,
    Map<String, dynamic>? userProfile,
    List<Map<String, dynamic>>? userPosts,
    int? followersCount,
    int? followingCount,
    bool? isFollowing,
    bool? isMe,
    bool? isProcessingFollow,
    String? errorMessage,
  }) {
    return PublicProfileState(
      status: status ?? this.status,
      userProfile: userProfile ?? this.userProfile,
      userPosts: userPosts ?? this.userPosts,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isMe: isMe ?? this.isMe,
      isProcessingFollow: isProcessingFollow ?? this.isProcessingFollow,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        userProfile,
        userPosts,
        followersCount,
        followingCount,
        isFollowing,
        isMe,
        isProcessingFollow,
        errorMessage,
      ];
}
