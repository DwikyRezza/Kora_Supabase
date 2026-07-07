import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../services/social_service.dart';
import '../../../../services/auth_service.dart';
import 'social_network_event.dart';
import 'social_network_state.dart';

class SocialNetworkBloc extends Bloc<SocialNetworkEvent, SocialNetworkState> {
  SocialNetworkBloc() : super(const SocialNetworkState()) {
    on<LoadSocialData>(_onLoadSocialData);
    on<UnfollowUserEvent>(_onUnfollowUser);
    on<RemoveFollowerEvent>(_onRemoveFollower);
  }

  Future<void> _onLoadSocialData(LoadSocialData event, Emitter<SocialNetworkState> emit) async {
    emit(state.copyWith(status: SocialNetworkStatus.loading, uid: event.uid));
    
    if (AuthService.isLoggedIn) {
      try {
        final followingData = await SocialService.getFollowing(event.uid);
        final followersData = await SocialService.getFollowers(event.uid);
        
        emit(state.copyWith(
          status: SocialNetworkStatus.success,
          following: followingData,
          followers: followersData,
        ));
      } catch (e) {
        emit(state.copyWith(
          status: SocialNetworkStatus.failure,
          errorMessage: 'Gagal memuat data: $e',
        ));
      }
    } else {
      emit(state.copyWith(status: SocialNetworkStatus.failure, errorMessage: 'User tidak login'));
    }
  }

  Future<void> _onUnfollowUser(UnfollowUserEvent event, Emitter<SocialNetworkState> emit) async {
    try {
      await SocialService.unfollowUser(event.targetUid);
      add(LoadSocialData(state.uid)); // Reload data
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Gagal berhenti mengikuti: $e'));
      emit(state.copyWith(errorMessage: null));
    }
  }

  Future<void> _onRemoveFollower(RemoveFollowerEvent event, Emitter<SocialNetworkState> emit) async {
    try {
      await SocialService.removeFollower(event.followerUid);
      add(LoadSocialData(state.uid)); // Reload data
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Gagal menghapus pengikut: $e'));
      emit(state.copyWith(errorMessage: null));
    }
  }
}
