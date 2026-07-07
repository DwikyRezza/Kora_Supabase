import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../services/notification_service.dart';
import 'notification_event.dart';
import 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc() : super(const NotificationState()) {
    on<LoadNotifications>(_onLoadNotifications);
  }

  Future<void> _onLoadNotifications(LoadNotifications event, Emitter<NotificationState> emit) async {
    emit(state.copyWith(status: NotificationStatus.loading));
    
    try {
      final notifs = await NotificationService.getNotifications();
      await NotificationService.markAllAsRead();
      
      emit(state.copyWith(
        status: NotificationStatus.success,
        notifications: notifs,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: NotificationStatus.failure,
        errorMessage: 'Gagal memuat notifikasi: $e',
      ));
    }
  }
}
