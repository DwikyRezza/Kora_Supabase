import '../../../../core/enums/activity_enums.dart';
import '../../domain/models/activity_data_point.dart';

abstract class ActivityAnalyticsDataSource {
  Future<List<ActivityDataPoint>> getChartData(ActivityMetric metric, ActivityTimeframe timeframe);
  Future<double> getHeroNumber(ActivityMetric metric, ActivityTimeframe timeframe);
  Future<double> getTrendPercentage(ActivityMetric metric, ActivityTimeframe timeframe);
}
