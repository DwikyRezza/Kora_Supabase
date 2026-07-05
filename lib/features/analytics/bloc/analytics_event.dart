import 'package:equatable/equatable.dart';

abstract class AnalyticsEvent extends Equatable {
  const AnalyticsEvent();

  @override
  List<Object?> get props => [];
}

class AnalyticsLoadData extends AnalyticsEvent {
  final DateTime month;
  final String filter;
  const AnalyticsLoadData(this.month, this.filter);
  
  @override
  List<Object?> get props => [month, filter];
}

class AnalyticsFilterChanged extends AnalyticsEvent {
  final String filter;
  const AnalyticsFilterChanged(this.filter);
  
  @override
  List<Object?> get props => [filter];
}

class AnalyticsMonthChanged extends AnalyticsEvent {
  final DateTime month;
  const AnalyticsMonthChanged(this.month);
  
  @override
  List<Object?> get props => [month];
}
