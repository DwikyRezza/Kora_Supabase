import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repositories/activity_analytics_repository.dart';
import '../domain/rules/insight_generator.dart';
import 'activity_analytics_event.dart';
import 'activity_analytics_state.dart';

class ActivityAnalyticsBloc extends Bloc<ActivityAnalyticsEvent, ActivityAnalyticsState> {
  final ActivityAnalyticsRepository _repository;
  final InsightGenerator _insightGenerator;

  ActivityAnalyticsBloc({
    required ActivityAnalyticsRepository repository,
    required InsightGenerator insightGenerator,
  })  : _repository = repository,
        _insightGenerator = insightGenerator,
        super(const ActivityAnalyticsState()) {
    on<LoadActivityAnalyticsData>(_onLoadData);
    on<ChangeMetric>(_onChangeMetric);
    on<ChangeTimeframe>(_onChangeTimeframe);
  }

  Future<void> _onLoadData(
    LoadActivityAnalyticsData event,
    Emitter<ActivityAnalyticsState> emit,
  ) async {
    emit(state.copyWith(status: ActivityAnalyticsStatus.loading));
    
    final metric = event.metric ?? state.selectedMetric;
    final timeframe = event.timeframe ?? state.selectedTimeframe;

    try {
      final chartData = await _repository.getChartData(metric, timeframe);
      final heroNumber = await _repository.getHeroNumber(metric, timeframe);
      final trendPercentage = await _repository.getTrendPercentage(metric, timeframe);
      
      final insight = _insightGenerator.generateInsight(metric, heroNumber, trendPercentage);

      emit(state.copyWithInsight(insight).copyWith(
        status: ActivityAnalyticsStatus.success,
        selectedMetric: metric,
        selectedTimeframe: timeframe,
        chartData: chartData,
        heroNumber: heroNumber,
        trendPercentage: trendPercentage,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ActivityAnalyticsStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onChangeMetric(
    ChangeMetric event,
    Emitter<ActivityAnalyticsState> emit,
  ) {
    if (state.selectedMetric != event.metric) {
      add(LoadActivityAnalyticsData(metric: event.metric));
    }
  }

  void _onChangeTimeframe(
    ChangeTimeframe event,
    Emitter<ActivityAnalyticsState> emit,
  ) {
    if (state.selectedTimeframe != event.timeframe) {
      add(LoadActivityAnalyticsData(timeframe: event.timeframe));
    }
  }
}
