import 'package:flutter_bloc/flutter_bloc.dart';
import 'profile_event.dart';
import 'profile_state.dart';
import '../../../../services/profile_service.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/social_service.dart';
import '../../../../services/database_helper.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final DatabaseHelper _db = DatabaseHelper();

  ProfileBloc() : super(const ProfileState()) {
    on<ProfileLoadRequested>(_onLoadRequested);
    on<ProfileRefreshRequested>(_onRefreshRequested);
  }

  Future<void> _onLoadRequested(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    if (!event.silent) {
      emit(state.copyWith(isLoading: true));
    }

    try {
      // Load profile
      final profile = await ProfileService.getProfile();
      
      // Load social stats
      final uid = AuthService.uid;
      int followers = 0;
      int following = 0;
      List<Map<String, dynamic>> userPosts = [];
      if (uid.isNotEmpty) {
        followers = await SocialService.getFollowersCount(uid);
        following = await SocialService.getFollowingCount(uid);
        userPosts = await SocialService.getUserPosts(uid);
      }
      
      // Load activities
      final allWorkouts = await _db.getAllWorkouts();
      
      // Batch check: workout mana saja yang punya foto
      final workoutIds = allWorkouts.map((w) => w.id).where((id) => id != null).cast<int>().toList();
      final idsWithPhotos = await _db.getWorkoutIdsWithPhotos(workoutIds);

      emit(state.copyWith(
        isLoading: false,
        profile: profile,
        followersCount: followers,
        followingCount: following,
        activitiesList: allWorkouts,
        userPosts: userPosts,
        activitiesCount: userPosts.length,
        workoutsWithPhotos: idsWithPhotos,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onRefreshRequested(
    ProfileRefreshRequested event,
    Emitter<ProfileState> emit,
  ) async {
    add(const ProfileLoadRequested(silent: true));
  }
}
