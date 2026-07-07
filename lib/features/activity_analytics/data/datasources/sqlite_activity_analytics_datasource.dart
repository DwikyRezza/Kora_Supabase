import '../../../../core/enums/activity_enums.dart';
import '../../domain/models/activity_data_point.dart';
import 'activity_analytics_datasource.dart';
import '../../../../services/database_helper.dart';

class SqliteActivityAnalyticsDataSource implements ActivityAnalyticsDataSource {
  @override
  Future<List<ActivityDataPoint>> getChartData(ActivityMetric metric, ActivityTimeframe timeframe) async {
    // Implementasi real data (3 bulan terakhir) dari SQLite
    String type = 'running'; // Atau ambil dinamis sesuai global filter
    final rows = await DatabaseHelper().getThreeMonthWorkoutAggregation(type);
    
    List<ActivityDataPoint> data = [];
    
    // Pastikan 3 bulan terakhir SELALU dirender di grafik meskipun nilainya 0
    final DateTime now = DateTime.now();
    for (int i = 2; i >= 0; i--) {
      // Hitung bulan mundur (2 bulan lalu, 1 bulan lalu, bulan ini)
      int m = now.month - i;
      int y = now.year;
      if (m <= 0) {
        m += 12;
        y -= 1;
      }
      
      data.add(ActivityDataPoint(
        x: m.toDouble(),
        y: 0.0,
        label: m.toString(),
      ));
    }

    for (var row in rows) {
      if (row['month'] == null) continue;
      String mStr = row['month'] as String;
      double xVal = double.parse(mStr);
      
      double yVal = 0.0;
      if (metric == ActivityMetric.distance) yVal = (row['totalDistance'] as num).toDouble();
      else if (metric == ActivityMetric.duration) yVal = (row['totalDuration'] as num).toDouble();
      else if (metric == ActivityMetric.calories) yVal = (row['totalCalories'] as num).toDouble();

      // Update titik data yang sesuai bulannya
      for (int j = 0; j < data.length; j++) {
        if (data[j].x == xVal) {
          data[j] = ActivityDataPoint(
            x: xVal,
            y: yVal,
            label: mStr,
          );
          break;
        }
      }
    }
    
    return data;
  }

  @override
  Future<double> getHeroNumber(ActivityMetric metric, ActivityTimeframe timeframe) async {
    final data = await getChartData(metric, timeframe);
    double total = 0.0;
    for (var point in data) {
      total += point.y;
    }
    return total;
  }

  @override
  Future<double> getTrendPercentage(ActivityMetric metric, ActivityTimeframe timeframe) async {
    // Placeholder (butuh perbandingan prev period)
    return 12.5;
  }
}
