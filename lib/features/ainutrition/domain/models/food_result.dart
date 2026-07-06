class FoodResult {
  final String name;
  final double gram;
  final double protein;
  final double calories;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double salt;

  FoodResult({
    required this.name,
    required this.gram,
    required this.protein,
    required this.calories,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.salt,
  });

  factory FoodResult.fromMap(Map<String, dynamic> m) {
    double d(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    return FoodResult(
      name: m['name']?.toString() ?? '',
      gram: d(m['gram']),
      protein: d(m['protein']),
      calories: d(m['calories']),
      carbs: d(m['carbs']),
      fat: d(m['fat']),
      fiber: d(m['fiber']),
      sugar: d(m['sugar']),
      salt: d(m['salt']),
    );
  }
}
