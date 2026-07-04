import 'package:equatable/equatable.dart';
import '../../../../core/enums/activity_enums.dart';

abstract class ActivityAnalyticsEvent extends Equatable {
  const ActivityAnalyticsEvent();

  @override
  List<Object> get props => [];
}

class LoadActivityAnalyticsData extends ActivityAnalyticsEvent {
  final ActivityMetric? metric;
  final ActivityTimeframe? timeframe;

  const LoadActivityAnalyticsData({this.metric, this.timeframe});

  @override
  List<Object> get props => [
        if (metric != null) metric!,
        if (timeframe != null) timeframe!,
      ];
}

class ChangeMetric extends ActivityAnalyticsEvent {
  final ActivityMetric metric;

  const ChangeMetric(this.metric);

  @override
  List<Object> get props => [metric];
}

class ChangeTimeframe extends ActivityAnalyticsEvent {
  final ActivityTimeframe timeframe;

  const ChangeTimeframe(this.timeframe);

  @override
  List<Object> get props => [timeframe];
}
