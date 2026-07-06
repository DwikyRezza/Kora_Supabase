import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../repositories/schedule_repository.dart';
import '../../../../services/cloud_sync_service.dart';
import 'schedule_event.dart';
import 'schedule_state.dart';

class ScheduleBloc extends Bloc<ScheduleEventBloc, ScheduleState> {
  final ScheduleRepository _repository;

  ScheduleBloc({required ScheduleRepository repository})
      : _repository = repository,
        super(ScheduleState(selectedDate: DateTime.now())) {
    on<ScheduleLoadEvents>(_onLoadEvents);
    on<ScheduleDateChanged>(_onDateChanged);
    on<ScheduleToggleEventCompletion>(_onToggleEventCompletion);
    on<ScheduleDeleteEvent>(_onDeleteEvent);
  }

  Future<void> _onLoadEvents(ScheduleLoadEvents event, Emitter<ScheduleState> emit) async {
    emit(state.copyWith(isLoading: true));
    
    // Sync with cloud in background first, don't wait for it if it fails
    try {
      await CloudSyncService.syncScheduleToCloud();
    } catch (_) {}

    final events = await _repository.getAllScheduleEvents();
    
    emit(state.copyWith(
      allEvents: events,
      isLoading: false,
    ));
  }

  void _onDateChanged(ScheduleDateChanged event, Emitter<ScheduleState> emit) {
    emit(state.copyWith(selectedDate: event.date));
  }

  Future<void> _onToggleEventCompletion(ScheduleToggleEventCompletion event, Emitter<ScheduleState> emit) async {
    await _repository.updateScheduleEventCompletion(event.eventId, event.isCompleted);
    add(ScheduleLoadEvents()); // Reload events to reflect changes
  }

  Future<void> _onDeleteEvent(ScheduleDeleteEvent event, Emitter<ScheduleState> emit) async {
    await _repository.deleteScheduleEvent(event.eventId);
    add(ScheduleLoadEvents());
  }
}
