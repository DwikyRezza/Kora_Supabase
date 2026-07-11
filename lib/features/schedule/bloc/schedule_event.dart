import 'package:equatable/equatable.dart';
import '../../../../models/schedule_event.dart';

abstract class ScheduleEventBloc extends Equatable {
  const ScheduleEventBloc();

  @override
  List<Object?> get props => [];
}

class ScheduleLoadEvents extends ScheduleEventBloc {}

class ScheduleDateChanged extends ScheduleEventBloc {
  final DateTime date;

  const ScheduleDateChanged(this.date);

  @override
  List<Object?> get props => [date];
}

class ScheduleToggleEventCompletion extends ScheduleEventBloc {
  final String eventId;
  final bool isCompleted;

  const ScheduleToggleEventCompletion(this.eventId, this.isCompleted);

  @override
  List<Object?> get props => [eventId, isCompleted];
}

class ScheduleDeleteEvent extends ScheduleEventBloc {
  final String eventId;

  const ScheduleDeleteEvent(this.eventId);

  @override
  List<Object?> get props => [eventId];
}
