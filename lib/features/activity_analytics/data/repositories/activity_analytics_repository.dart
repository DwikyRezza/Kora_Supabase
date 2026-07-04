import '../../../../core/enums/activity_enums.dart';
import '../../domain/models/activity_data_point.dart';
import '../datasources/activity_analytics_datasource.dart';

class ActivityAnalyticsRepository {
  final ActivityAnalyticsDataSource _dataSource;

  ActivityAnalyticsRepository(this._dataSource);

  Future<List<ActivityDataPoint>> getChartData(ActivityMetric metric, ActivityTimeframe timeframe) {
    return _dataSource.getChartData(metric, timeframe);
  }

  Future<double> getHeroNumber(ActivityMetric metric, ActivityTimeframe timeframe) {
    return _dataSource.getHeroNumber(metric, timeframe);
  }

  Future<double> getTrendPercentage(ActivityMetric metric, ActivityTimeframe timeframe) {
    return _dataSource.getTrendPercentage(metric, timeframe);
  }
}
