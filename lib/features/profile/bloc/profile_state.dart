import 'package:equatable/equatable.dart';
import '../../../../models/workout.dart';

class ProfileState extends Equatable {
  final bool isLoading;
  final Map<String, dynamic> profile;
  final int followersCount;
  final int followingCount;
  final int activitiesCount;
  final List<Workout> activitiesList;
  final List<Map<String, dynamic>> userPosts;
  final Set<int> workoutsWithPhotos;

  const ProfileState({
    this.isLoading = true,
    this.profile = const {},
    this.followersCount = 0,
    this.followingCount = 0,
    this.activitiesCount = 0,
    this.activitiesList = const [],
    this.userPosts = const [],
    this.workoutsWithPhotos = const {},
  });

  ProfileState copyWith({
    bool? isLoading,
    Map<String, dynamic>? profile,
    int? followersCount,
    int? followingCount,
    int? activitiesCount,
    List<Workout>? activitiesList,
    List<Map<String, dynamic>>? userPosts,
    Set<int>? workoutsWithPhotos,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      profile: profile ?? this.profile,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      activitiesCount: activitiesCount ?? this.activitiesCount,
      activitiesList: activitiesList ?? this.activitiesList,
      userPosts: userPosts ?? this.userPosts,
      workoutsWithPhotos: workoutsWithPhotos ?? this.workoutsWithPhotos,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        profile,
        followersCount,
        followingCount,
        activitiesCount,
        activitiesList,
        userPosts,
        workoutsWithPhotos,
      ];
}
