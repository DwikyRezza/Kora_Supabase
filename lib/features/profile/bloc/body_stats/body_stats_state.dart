import 'package:equatable/equatable.dart';
import '../../../../../models/body_measurement.dart';

enum BodyStatsStatus { initial, loading, success, failure }

class BodyStatsState extends Equatable {
  final BodyStatsStatus status;
  final List<BodyMeasurement> measurements;
  final String? errorMessage;

  const BodyStatsState({
    this.status = BodyStatsStatus.initial,
    this.measurements = const [],
    this.errorMessage,
  });

  BodyStatsState copyWith({
    BodyStatsStatus? status,
    List<BodyMeasurement>? measurements,
    String? errorMessage,
  }) {
    return BodyStatsState(
      status: status ?? this.status,
      measurements: measurements ?? this.measurements,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, measurements, errorMessage];
}
