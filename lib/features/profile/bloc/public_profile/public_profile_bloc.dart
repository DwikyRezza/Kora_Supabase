import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../services/social_service.dart';
import '../../../../../services/auth_service.dart';
import 'public_profile_event.dart';
import 'public_profile_state.dart';

class PublicProfileBloc extends Bloc<PublicProfileEvent, PublicProfileState> {
  PublicProfileBloc() : super(const PublicProfileState()) {
    on<LoadPublicProfile>(_onLoadPublicProfile);
    on<ToggleFollow>(_onToggleFollow);
  }

  Future<void> _onLoadPublicProfile(LoadPublicProfile event, Emitter<PublicProfileState> emit) async {
    if (!event.silent) {
      emit(state.copyWith(status: PublicProfileStatus.loading));
    }
    
    try {
      final isMe = event.uid == AuthService.uid;
      
      final profile = await SocialService.getUserProfile(event.uid);
      final posts = await SocialService.getUserPosts(event.uid);
      final followers = await SocialService.getFollowersCount(event.uid);
      final following = await SocialService.getFollowingCount(event.uid);
      
      bool isFollowing = false;
      if (!isMe) {
        isFollowing = await SocialService.checkIsFollowing(event.uid);
      }

      emit(state.copyWith(
        status: PublicProfileStatus.success,
        userProfile: profile,
        userPosts: posts,
        followersCount: followers,
        followingCount: following,
        isFollowing: isFollowing,
        isMe: isMe,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: PublicProfileStatus.failure,
        errorMessage: 'Gagal memuat profil: $e',
      ));
    }
  }

  Future<void> _onToggleFollow(ToggleFollow event, Emitter<PublicProfileState> emit) async {
    if (state.isProcessingFollow) return;
    emit(state.copyWith(isProcessingFollow: true));

    try {
      if (state.isFollowing) {
        await SocialService.unfollowUser(event.uid);
        emit(state.copyWith(
          isFollowing: false,
          followersCount: state.followersCount - 1,
          isProcessingFollow: false,
        ));
      } else {
        await SocialService.followUser(event.uid);
        emit(state.copyWith(
          isFollowing: true,
          followersCount: state.followersCount + 1,
          isProcessingFollow: false,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isProcessingFollow: false,
        errorMessage: 'Gagal mengubah status ikuti: $e',
      ));
      emit(state.copyWith(errorMessage: null));
    }
  }
}
