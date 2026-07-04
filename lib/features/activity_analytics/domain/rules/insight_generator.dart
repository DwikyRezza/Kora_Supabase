import '../../../../core/enums/activity_enums.dart';
import '../models/insight_model.dart';
import 'insight_rules.dart';

class InsightGenerator {
  final List<InsightRule> _rules;

  InsightGenerator({List<InsightRule>? rules}) 
      : _rules = rules ?? [
          GoalReachedRule(),
          TrendDeclineRule(),
          TrendIncreaseRule(),
        ];

  InsightModel? generateInsight(ActivityMetric metric, double heroNumber, double trend) {
    // Evaluate rules in order of priority. 
    // The first rule that returns a non-null insight wins.
    for (var rule in _rules) {
      final insight = rule.evaluate(metric, heroNumber, trend);
      if (insight != null) {
        return insight;
      }
    }
    
    // Return null if no insight is generated. 
    // The UI will handle null by removing the Insight Section.
    return null; 
  }
}
