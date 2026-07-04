import '../../../../core/enums/activity_enums.dart';
import '../models/insight_model.dart';

abstract class InsightRule {
  InsightModel? evaluate(ActivityMetric metric, double heroNumber, double trend);
}

class GoalReachedRule implements InsightRule {
  @override
  InsightModel? evaluate(ActivityMetric metric, double heroNumber, double trend) {
    if (metric == ActivityMetric.calories && heroNumber >= 2000) {
      return InsightModel(text: "Luar biasa! Target kalori harianmu hampir tercapai penuh.", isPositive: true);
    }
    return null;
  }
}

class TrendDeclineRule implements InsightRule {
  @override
  InsightModel? evaluate(ActivityMetric metric, double heroNumber, double trend) {
    if (trend <= -10) {
      String metricName = _getMetricName(metric);
      return InsightModel(text: "$metricName hari ini turun cukup drastis (${trend.toStringAsFixed(0)}%). Ayo semangat lagi!", isPositive: false);
    }
    return null;
  }

  String _getMetricName(ActivityMetric metric) {
    switch (metric) {
      case ActivityMetric.intake: return "Asupan";
      case ActivityMetric.calories: return "Pembakaran kalori";
      case ActivityMetric.duration: return "Durasi latihan";
      case ActivityMetric.distance: return "Jarak tempuh";
    }
  }
}

class TrendIncreaseRule implements InsightRule {
  @override
  InsightModel? evaluate(ActivityMetric metric, double heroNumber, double trend) {
    if (trend >= 10) {
      String metricName = _getMetricName(metric);
      return InsightModel(text: "$metricName hari ini naik signifikan (${trend.toStringAsFixed(0)}%). Pertahankan momentum ini!", isPositive: true);
    }
    return null;
  }
  
  String _getMetricName(ActivityMetric metric) {
    switch (metric) {
      case ActivityMetric.intake: return "Asupan";
      case ActivityMetric.calories: return "Pembakaran kalori";
      case ActivityMetric.duration: return "Durasi latihan";
      case ActivityMetric.distance: return "Jarak tempuh";
    }
  }
}
