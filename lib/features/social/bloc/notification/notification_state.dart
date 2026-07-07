import 'package:equatable/equatable.dart';

enum NotificationStatus { initial, loading, success, failure }

class NotificationState extends Equatable {
  final NotificationStatus status;
  final List<Map<String, dynamic>> notifications;
  final String? errorMessage;

  const NotificationState({
    this.status = NotificationStatus.initial,
    this.notifications = const [],
    this.errorMessage,
  });

  NotificationState copyWith({
    NotificationStatus? status,
    List<Map<String, dynamic>>? notifications,
    String? errorMessage,
  }) {
    return NotificationState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, notifications, errorMessage];
}
