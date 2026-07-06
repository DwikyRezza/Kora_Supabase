import 'package:equatable/equatable.dart';

class WorkoutMainState extends Equatable {
  final bool isLoading;
  final String activeFilter;
  final List<Map<String, dynamic>> userPosts;
  final String userName;

  const WorkoutMainState({
    this.isLoading = true,
    this.activeFilter = 'running',
    this.userPosts = const [],
    this.userName = '',
  });

  WorkoutMainState copyWith({
    bool? isLoading,
    String? activeFilter,
    List<Map<String, dynamic>>? userPosts,
    String? userName,
  }) {
    return WorkoutMainState(
      isLoading: isLoading ?? this.isLoading,
      activeFilter: activeFilter ?? this.activeFilter,
      userPosts: userPosts ?? this.userPosts,
      userName: userName ?? this.userName,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        activeFilter,
        userPosts,
        userName,
      ];
}
