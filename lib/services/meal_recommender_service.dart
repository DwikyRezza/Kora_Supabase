import 'dart:math';

class MealRecommendation {
  final String title;
  final String description;
  final double estimatedCost;
  final String category; // 'Ekonomi', 'Medium', 'Premium'

  MealRecommendation({
    required this.title,
    required this.description,
    required this.estimatedCost,
    required this.category,
  });
}

class MealRecommenderService {
  static final List<MealRecommendation> _bulkingMeals = [
    MealRecommendation(
      title: 'Sarapan: 3 Telur Rebus & Oat',
      description: 'Murah, padat kalori, dan tinggi protein. Sempurna untuk memulai hari.',
      estimatedCost: 10000,
      category: 'Ekonomi',
    ),
    MealRecommendation(
      title: 'Makan Siang: Nasi Putih & Tempe Orek 200g',
      description: 'Karbohidrat cepat serap dan protein nabati yang sangat terjangkau.',
      estimatedCost: 15000,
      category: 'Ekonomi',
    ),
    MealRecommendation(
      title: 'Sarapan: Dada Ayam 150g & Nasi Merah',
      description: 'Protein tanpa lemak berkualitas dengan karbohidrat kompleks.',
      estimatedCost: 25000,
      category: 'Medium',
    ),
    MealRecommendation(
      title: 'Makan Malam: Ikan Tuna 200g & Kentang Rebus',
      description: 'Sumber Omega-3 dan protein berkualitas tinggi.',
      estimatedCost: 35000,
      category: 'Medium',
    ),
    MealRecommendation(
      title: 'Sarapan: Telur Orak-arik (4) & Roti Gandum (3)',
      description: 'Sangat padat nutrisi untuk kebutuhan surplus kalori.',
      estimatedCost: 20000,
      category: 'Medium',
    ),
    MealRecommendation(
      title: 'Makan Siang: Daging Sapi Lada Hitam 200g & Nasi',
      description: 'Tinggi kalori, protein, dan zat besi untuk power latihan maksimal.',
      estimatedCost: 60000,
      category: 'Premium',
    ),
    MealRecommendation(
      title: 'Makan Malam: Salmon Panggang 200g & Quinoa',
      description: 'Makan malam mewah padat gizi, kaya lemak baik dan protein premium.',
      estimatedCost: 85000,
      category: 'Premium',
    ),
  ];

  static final List<MealRecommendation> _cuttingMeals = [
    MealRecommendation(
      title: 'Sarapan: 2 Putih Telur & Dada Ayam Suwir',
      description: 'Sangat rendah kalori, kaya protein untuk menjaga massa otot.',
      estimatedCost: 15000,
      category: 'Ekonomi',
    ),
    MealRecommendation(
      title: 'Makan Siang: Tempe Kukus & Sayur Bayam',
      description: 'Tinggi serat untuk menahan rasa lapar lebih lama.',
      estimatedCost: 12000,
      category: 'Ekonomi',
    ),
    MealRecommendation(
      title: 'Makan Siang: Salad Dada Ayam 150g',
      description: 'Sayuran segar dengan dressing rendah lemak.',
      estimatedCost: 30000,
      category: 'Medium',
    ),
    MealRecommendation(
      title: 'Makan Malam: Ikan Nila Bakar & Brokoli Rebus',
      description: 'Protein ringan untuk malam hari tanpa membebani sistem pencernaan.',
      estimatedCost: 25000,
      category: 'Medium',
    ),
    MealRecommendation(
      title: 'Sarapan: Steak Tenderloin Tanpa Lemak 150g',
      description: 'Potongan daging premium yang sangat rendah lemak.',
      estimatedCost: 75000,
      category: 'Premium',
    ),
    MealRecommendation(
      title: 'Makan Malam: Sashimi Tuna & Avocado Salad',
      description: 'Sangat bersih, rendah karbohidrat, tinggi protein sehat.',
      estimatedCost: 90000,
      category: 'Premium',
    ),
  ];

  static MealRecommendation getRecommendation(String goal, int dailyBudget) {
    // Estimasi budget per makan (asumsi 3x makan sehari)
    final mealBudget = dailyBudget / 3;
    
    String targetCategory = 'Medium';
    if (mealBudget <= 20000) {
      targetCategory = 'Ekonomi';
    } else if (mealBudget > 45000) {
      targetCategory = 'Premium';
    }

    // Default ke bulking jika bukan cutting/diet
    final isCutting = goal.toLowerCase().contains('cut') || goal.toLowerCase().contains('diet');
    final sourceList = isCutting ? _cuttingMeals : _bulkingMeals;
    
    // Cari meal yang cocok dengan kategori budget
    final matchedMeals = sourceList.where((meal) => meal.category == targetCategory).toList();
    
    if (matchedMeals.isEmpty) {
      // Fallback
      return sourceList[Random().nextInt(sourceList.length)];
    }

    // Return random dari yang matched
    return matchedMeals[Random().nextInt(matchedMeals.length)];
  }
}
