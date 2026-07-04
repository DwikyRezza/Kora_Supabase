import 'dart:math';
import '../../../../core/enums/activity_enums.dart';
import '../../domain/models/activity_data_point.dart';
import 'activity_analytics_datasource.dart';

class MockActivityAnalyticsDataSource implements ActivityAnalyticsDataSource {
  final Random _random = Random();

  @override
  Future<List<ActivityDataPoint>> getChartData(ActivityMetric metric, ActivityTimeframe timeframe) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 400));
    
    List<ActivityDataPoint> data = [];
    int pointCount = _getPointCountForTimeframe(timeframe);
    
    double baseValue = _getBaseValueForMetric(metric);
    double volatility = baseValue * 0.3; // 30% volatility
    
    double currentValue = baseValue;
    
    for (int i = 0; i < pointCount; i++) {
      // Create some random walk to make the chart look organic
      currentValue = currentValue + (_random.nextDouble() - 0.5) * volatility;
      if (currentValue < 0) currentValue = 0;
      
      data.add(ActivityDataPoint(
        x: i.toDouble(),
        y: currentValue,
        label: _getLabelForTimeframe(timeframe, i, pointCount),
      ));
    }
    
    return data;
  }

  @override
  Future<double> getHeroNumber(ActivityMetric metric, ActivityTimeframe timeframe) async {
    await Future.delayed(const Duration(milliseconds: 200));
    double base = _getBaseValueForMetric(metric);
    double multiplier = _getMultiplierForTimeframe(timeframe);
    
    // Add some random variation
    return (base * multiplier) * (0.9 + _random.nextDouble() * 0.2); 
  }

  @override
  Future<double> getTrendPercentage(ActivityMetric metric, ActivityTimeframe timeframe) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Random trend between -15% and +25%
    return -15.0 + _random.nextDouble() * 40.0;
  }
  
  int _getPointCountForTimeframe(ActivityTimeframe timeframe) {
    switch (timeframe) {
      case ActivityTimeframe.oneHour: return 6; // Every 10 mins
      case ActivityTimeframe.sixHours: return 6; // Every 1 hour
      case ActivityTimeframe.oneDay: return 6; // Every 4 hours
      case ActivityTimeframe.sevenDays: return 7; // Every 1 day
    }
  }
  
  double _getMultiplierForTimeframe(ActivityTimeframe timeframe) {
    switch (timeframe) {
      case ActivityTimeframe.oneHour: return 0.1;
      case ActivityTimeframe.sixHours: return 0.3;
      case ActivityTimeframe.oneDay: return 1.0;
      case ActivityTimeframe.sevenDays: return 7.0;
    }
  }
  
  double _getBaseValueForMetric(ActivityMetric metric) {
    switch (metric) {
      case ActivityMetric.intake: return 2100.0; // kcal
      case ActivityMetric.calories: return 600.0; // kcal
      case ActivityMetric.duration: return 45.0; // mins
      case ActivityMetric.distance: return 5.5; // km
    }
  }
  
  String _getLabelForTimeframe(ActivityTimeframe timeframe, int index, int total) {
    final now = DateTime.now();
    switch (timeframe) {
      case ActivityTimeframe.oneHour:
        final time = now.subtract(Duration(minutes: (total - index - 1) * 10));
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      case ActivityTimeframe.sixHours:
        final time = now.subtract(Duration(hours: (total - index - 1)));
        return '${time.hour.toString().padLeft(2, '0')}:00';
      case ActivityTimeframe.oneDay:
        final time = now.subtract(Duration(hours: (total - index - 1) * 4));
        return '${time.hour.toString().padLeft(2, '0')}:00';
      case ActivityTimeframe.sevenDays:
        final time = now.subtract(Duration(days: (total - index - 1)));
        final days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
        return days[time.weekday - 1];
    }
  }
}
