import 'package:equatable/equatable.dart';
import '../../../../core/enums/activity_enums.dart';
import '../domain/models/activity_data_point.dart';
import '../domain/models/insight_model.dart';

enum ActivityAnalyticsStatus { initial, loading, success, failure }

class ActivityAnalyticsState extends Equatable {
  final ActivityAnalyticsStatus status;
  final ActivityMetric selectedMetric;
  final ActivityTimeframe selectedTimeframe;
  final List<ActivityDataPoint> chartData;
  final double heroNumber;
  final double trendPercentage;
  final InsightModel? insight;
  final String? errorMessage;

  const ActivityAnalyticsState({
    this.status = ActivityAnalyticsStatus.initial,
    this.selectedMetric = ActivityMetric.intake,
    this.selectedTimeframe = ActivityTimeframe.oneDay,
    this.chartData = const [],
    this.heroNumber = 0.0,
    this.trendPercentage = 0.0,
    this.insight,
    this.errorMessage,
  });

  ActivityAnalyticsState copyWith({
    ActivityAnalyticsStatus? status,
    ActivityMetric? selectedMetric,
    ActivityTimeframe? selectedTimeframe,
    List<ActivityDataPoint>? chartData,
    double? heroNumber,
    double? trendPercentage,
    InsightModel? insight,
    String? errorMessage,
  }) {
    return ActivityAnalyticsState(
      status: status ?? this.status,
      selectedMetric: selectedMetric ?? this.selectedMetric,
      selectedTimeframe: selectedTimeframe ?? this.selectedTimeframe,
      chartData: chartData ?? this.chartData,
      heroNumber: heroNumber ?? this.heroNumber,
      trendPercentage: trendPercentage ?? this.trendPercentage,
      insight: insight ?? this.insight, // To allow nulling insight, we might need a special wrapper if we want to null it explicitly, but for now we'll overwrite on success
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  // Helper method to clear insight when generating new one
  ActivityAnalyticsState copyWithInsight(InsightModel? newInsight) {
    return ActivityAnalyticsState(
      status: this.status,
      selectedMetric: this.selectedMetric,
      selectedTimeframe: this.selectedTimeframe,
      chartData: this.chartData,
      heroNumber: this.heroNumber,
      trendPercentage: this.trendPercentage,
      insight: newInsight,
      errorMessage: this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        selectedMetric,
        selectedTimeframe,
        chartData,
        heroNumber,
        trendPercentage,
        insight,
        errorMessage,
      ];
}
