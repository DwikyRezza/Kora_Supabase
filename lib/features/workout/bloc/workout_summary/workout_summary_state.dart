import 'package:equatable/equatable.dart';

enum WorkoutSummaryStatus { initial, saving, success, failure }

class WorkoutSummaryState extends Equatable {
  final WorkoutSummaryStatus status;
  final String? errorMessage;

  const WorkoutSummaryState({
    this.status = WorkoutSummaryStatus.initial,
    this.errorMessage,
  });

  WorkoutSummaryState copyWith({
    WorkoutSummaryStatus? status,
    String? errorMessage,
  }) {
    return WorkoutSummaryState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
