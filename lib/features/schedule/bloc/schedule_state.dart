import 'package:equatable/equatable.dart';
import '../../../../models/schedule_event.dart';

class ScheduleState extends Equatable {
  final DateTime selectedDate;
  final List<ScheduleEvent> allEvents;
  final bool isLoading;

  const ScheduleState({
    required this.selectedDate,
    this.allEvents = const [],
    this.isLoading = true,
  });

  List<ScheduleEvent> get eventsForSelectedDate {
    return allEvents.where((e) {
      final dt = e.dateTime;
      return dt.year == selectedDate.year &&
          dt.month == selectedDate.month &&
          dt.day == selectedDate.day;
    }).toList();
  }

  ScheduleState copyWith({
    DateTime? selectedDate,
    List<ScheduleEvent>? allEvents,
    bool? isLoading,
  }) {
    return ScheduleState(
      selectedDate: selectedDate ?? this.selectedDate,
      allEvents: allEvents ?? this.allEvents,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [selectedDate, allEvents, isLoading];
}
