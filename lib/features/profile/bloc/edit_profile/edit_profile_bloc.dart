import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../../../services/profile_service.dart';
import '../../../../../services/storage_service.dart';
import '../../../../../services/auth_service.dart';
import 'edit_profile_event.dart';
import 'edit_profile_state.dart';

class EditProfileBloc extends Bloc<EditProfileEvent, EditProfileState> {
  EditProfileBloc() : super(const EditProfileState()) {
    on<LoadProfileData>(_onLoadProfileData);
    on<PickProfilePhoto>(_onPickProfilePhoto);
    on<SaveProfileData>(_onSaveProfileData);
  }

  Future<void> _onLoadProfileData(LoadProfileData event, Emitter<EditProfileState> emit) async {
    emit(state.copyWith(status: EditProfileStatus.loading));
    try {
      final profile = await ProfileService.getProfile();
      final userEmail = AuthService.email;

      String? photoUrl;
      final savedPhoto = profile['photoUrl'] as String?;
      if (savedPhoto != null && savedPhoto.startsWith('http')) {
        photoUrl = savedPhoto;
      }

      emit(state.copyWith(
        status: EditProfileStatus.success,
        profileData: profile,
        userEmail: userEmail,
        uploadedPhotoUrl: photoUrl,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EditProfileStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onPickProfilePhoto(PickProfilePhoto event, Emitter<EditProfileState> emit) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 60,
    );

    if (pickedFile != null) {
      emit(state.copyWith(isUploadingPhoto: true));
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = p.join(appDir.path, fileName);
        await File(pickedFile.path).copy(savedPath);

        emit(state.copyWith(localPhotoPath: savedPath));

        final url = await StorageService.uploadProfilePhoto(savedPath);

        if (url != null) {
          emit(state.copyWith(
            uploadedPhotoUrl: url,
            isUploadingPhoto: false,
          ));
        } else {
          emit(state.copyWith(isUploadingPhoto: false));
        }
      } catch (e) {
        emit(state.copyWith(
          isUploadingPhoto: false,
          errorMessage: 'Gagal mengunggah foto: $e',
        ));
      }
    }
  }

  Future<void> _onSaveProfileData(SaveProfileData event, Emitter<EditProfileState> emit) async {
    emit(state.copyWith(status: EditProfileStatus.saving));

    if (event.username.isEmpty) {
      emit(state.copyWith(status: EditProfileStatus.failure, errorMessage: 'Username wajib diisi'));
      // Reset back to success for UI to stay interactive
      emit(state.copyWith(status: EditProfileStatus.success));
      return;
    }

    final currentUsername = state.profileData[ProfileService.keyUsername] ?? '';
    if (event.username != currentUsername) {
      bool isUsernameAvail = await ProfileService.isUsernameAvailable(event.username);
      if (!isUsernameAvail) {
        emit(state.copyWith(
          status: EditProfileStatus.failure,
          errorMessage: 'Username "${event.username}" sudah digunakan. Silakan pilih username lain.',
        ));
        emit(state.copyWith(status: EditProfileStatus.success));
        return;
      }
    }

    try {
      await ProfileService.saveProfile(
        name: event.name,
        username: event.username,
        age: event.age,
        gender: event.gender,
        height: event.height,
        weight: event.weight,
        goal: event.goal,
        status: event.bio,
        photoUrl: state.uploadedPhotoUrl,
      );
      
      emit(state.copyWith(status: EditProfileStatus.success, profileData: await ProfileService.getProfile()));
    } catch (e) {
      emit(state.copyWith(status: EditProfileStatus.failure, errorMessage: e.toString()));
      emit(state.copyWith(status: EditProfileStatus.success));
    }
  }
}
