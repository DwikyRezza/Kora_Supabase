import 'package:equatable/equatable.dart';

enum WorkoutDetailStatus { initial, loading, success, failure, deleted }

class WorkoutDetailState extends Equatable {
  final WorkoutDetailStatus status;
  final String userName;
  final String? userPhotoUrl;
  final String? errorMessage;
  final int photoRefreshKey; // to trigger FutureBuilder reload in UI

  const WorkoutDetailState({
    this.status = WorkoutDetailStatus.initial,
    this.userName = 'Atlet',
    this.userPhotoUrl,
    this.errorMessage,
    this.photoRefreshKey = 0,
  });

  WorkoutDetailState copyWith({
    WorkoutDetailStatus? status,
    String? userName,
    String? userPhotoUrl,
    String? errorMessage,
    int? photoRefreshKey,
  }) {
    return WorkoutDetailState(
      status: status ?? this.status,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      errorMessage: errorMessage ?? this.errorMessage,
      photoRefreshKey: photoRefreshKey ?? this.photoRefreshKey,
    );
  }

  @override
  List<Object?> get props => [status, userName, userPhotoUrl, errorMessage, photoRefreshKey];
}
