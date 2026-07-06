import 'package:equatable/equatable.dart';

enum EditProfileStatus { initial, loading, saving, success, failure }

class EditProfileState extends Equatable {
  final EditProfileStatus status;
  final Map<String, dynamic> profileData;
  final String? localPhotoPath;
  final String? uploadedPhotoUrl;
  final bool isUploadingPhoto;
  final String? errorMessage;
  final String? userEmail;

  const EditProfileState({
    this.status = EditProfileStatus.initial,
    this.profileData = const {},
    this.localPhotoPath,
    this.uploadedPhotoUrl,
    this.isUploadingPhoto = false,
    this.errorMessage,
    this.userEmail,
  });

  EditProfileState copyWith({
    EditProfileStatus? status,
    Map<String, dynamic>? profileData,
    String? localPhotoPath,
    String? uploadedPhotoUrl,
    bool? isUploadingPhoto,
    String? errorMessage,
    String? userEmail,
  }) {
    return EditProfileState(
      status: status ?? this.status,
      profileData: profileData ?? this.profileData,
      localPhotoPath: localPhotoPath ?? this.localPhotoPath,
      uploadedPhotoUrl: uploadedPhotoUrl ?? this.uploadedPhotoUrl,
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
      errorMessage: errorMessage ?? this.errorMessage,
      userEmail: userEmail ?? this.userEmail,
    );
  }

  @override
  List<Object?> get props => [
        status,
        profileData,
        localPhotoPath,
        uploadedPhotoUrl,
        isUploadingPhoto,
        errorMessage,
        userEmail,
      ];
}
