import 'package:flutter/material.dart';
class ProteinEntry {
  final int? id;
  final String foodName;
  final double proteinGrams;
  final double calories;
  final double carbsGrams;
  final double fatGrams;
  final double fiberGrams;
  final double sugarGrams;
  final double saltGrams;
  final int waterMl;
  final String mealType;
  final String? emojiStr;
  final DateTime date;

  ProteinEntry({
    this.id,
    required this.foodName,
    required this.proteinGrams,
    required this.calories,
    this.carbsGrams = 0.0,
    this.fatGrams = 0.0,
    this.fiberGrams = 0.0,
    this.sugarGrams = 0.0,
    this.saltGrams = 0.0,
    this.waterMl = 0,
    required this.mealType,
    this.emojiStr,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'foodName': foodName,
      'proteinGrams': proteinGrams,
      'calories': calories,
      'carbsGrams': carbsGrams,
      'fatGrams': fatGrams,
      'fiberGrams': fiberGrams,
      'sugarGrams': sugarGrams,
      'saltGrams': saltGrams,
      'waterMl': waterMl,
      'mealType': mealType,
      'emojiStr': emojiStr,
      'date': date.toIso8601String(),
    };
  }

  factory ProteinEntry.fromMap(Map<String, dynamic> map) {
    return ProteinEntry(
      id: map['id'],
      foodName: map['foodName'],
      proteinGrams: map['proteinGrams'] ?? 0.0,
      calories: map['calories'] ?? 0.0,
      carbsGrams: map['carbsGrams'] ?? 0.0,
      fatGrams: map['fatGrams'] ?? 0.0,
      fiberGrams: map['fiberGrams'] ?? 0.0,
      sugarGrams: map['sugarGrams'] ?? 0.0,
      saltGrams: map['saltGrams'] ?? 0.0,
      waterMl: map['waterMl'] ?? 0,
      mealType: map['mealType'],
      emojiStr: map['emojiStr'],
      date: DateTime.parse(map['date']),
    );
  }

  String get mealLabel {
    switch (mealType) {
      case 'breakfast':
        return 'Sarapan';
      case 'lunch':
        return 'Makan Siang';
      case 'dinner':
        return 'Makan Malam';
      case 'snack':
        return 'Snack';
      case 'water':
        return 'Air Putih';
      default:
        return mealType;
    }
  }

  IconData get mealIcon {
    switch (mealType) {
      case 'breakfast': return Icons.wb_twilight;
      case 'lunch': return Icons.wb_sunny;
      case 'dinner': return Icons.nights_stay;
      case 'snack': return Icons.local_dining;
      case 'water': return Icons.local_drink;
      default: return Icons.restaurant;
    }
  }

  IconData get foodIcon {
    return Icons.lunch_dining;
  }
}

class ProteinFoodDatabase {
  static final List<Map<String, dynamic>> foods = [
    // ─────────────────────────────────────────────
    // KATEGORI A: DATA LAMA (dari versi sebelumnya)
    // ─────────────────────────────────────────────

    // A1. Makanan Pokok & Karbo (lama)
    {
      'name': 'Nasi Liwet (100g)',
      'protein': 3.1,
      'calories': 155.0,
      'carbs': 32.0,
      'fat': 2.25,
      'fiber': 0.4,
      'sugar': 0.6,
      'salt': 0.33
    },
    {
      'name': 'Nasi Kebuli (100g)',
      'protein': 4.25,
      'calories': 185.0,
      'carbs': 31.0,
      'fat': 4.5,
      'fiber': 0.5,
      'sugar': 0.75,
      'salt': 0.40
    },
    {
      'name': 'Nasi Uduk (100g)',
      'protein': 3.0,
      'calories': 170.0,
      'carbs': 30.0,
      'fat': 4.25,
      'fiber': 0.35,
      'sugar': 0.5,
      'salt': 0.28
    },
    {
      'name': 'Nasi Jagung (100g)',
      'protein': 3.0,
      'calories': 140.0,
      'carbs': 30.0,
      'fat': 0.5,
      'fiber': 3.0,
      'sugar': 0.5,
      'salt': 0.01
    },
    {
      'name': 'Ubi Cilembu Rebus (100g)',
      'protein': 1.6,
      'calories': 86.0,
      'carbs': 20.0,
      'fat': 0.1,
      'fiber': 3.0,
      'sugar': 4.2,
      'salt': 0.01
    },
    {
      'name': 'Ubi Ungu Kukus (100g)',
      'protein': 1.5,
      'calories': 85.0,
      'carbs': 19.5,
      'fat': 0.2,
      'fiber': 3.3,
      'sugar': 4.0,
      'salt': 0.01
    },
    {
      'name': 'Singkong Rebus (100g)',
      'protein': 1.4,
      'calories': 112.0,
      'carbs': 27.0,
      'fat': 0.3,
      'fiber': 1.8,
      'sugar': 1.0,
      'salt': 0.01
    },
    {
      'name': 'Singkong Goreng (100g)',
      'protein': 1.2,
      'calories': 200.0,
      'carbs': 30.0,
      'fat': 8.0,
      'fiber': 1.5,
      'sugar': 1.0,
      'salt': 0.15
    },
    {
      'name': 'Kentang Rebus (100g)',
      'protein': 1.9,
      'calories': 87.0,
      'carbs': 20.0,
      'fat': 0.1,
      'fiber': 1.8,
      'sugar': 0.9,
      'salt': 0.01
    },
    {
      'name': 'Kentang Goreng - French Fries (100g)',
      'protein': 3.4,
      'calories': 312.0,
      'carbs': 41.0,
      'fat': 15.0,
      'fiber': 3.8,
      'sugar': 0.5,
      'salt': 0.50
    },
    {
      'name': 'Mashed Potato (100g)',
      'protein': 2.0,
      'calories': 108.0,
      'carbs': 16.0,
      'fat': 4.3,
      'fiber': 1.5,
      'sugar': 1.0,
      'salt': 0.30
    },
    {
      'name': 'Mie Instan Goreng (1 bungkus)',
      'protein': 8.0,
      'calories': 380.0,
      'carbs': 54.0,
      'fat': 14.0,
      'fiber': 2.0,
      'sugar': 2.0,
      'salt': 1.80
    },
    {
      'name': 'Mie Instan Kuah (1 bungkus)',
      'protein': 7.0,
      'calories': 330.0,
      'carbs': 48.0,
      'fat': 12.0,
      'fiber': 2.0,
      'sugar': 2.0,
      'salt': 1.60
    },
    {
      'name': 'Mie Ayam (1 mangkuk)',
      'protein': 15.0,
      'calories': 420.0,
      'carbs': 55.0,
      'fat': 15.0,
      'fiber': 4.0,
      'sugar': 3.0,
      'salt': 1.20
    },
    {
      'name': 'Kwetiau Goreng (1 porsi)',
      'protein': 12.0,
      'calories': 500.0,
      'carbs': 60.0,
      'fat': 22.0,
      'fiber': 3.0,
      'sugar': 3.0,
      'salt': 1.40
    },
    {
      'name': 'Bihun Goreng (1 porsi)',
      'protein': 10.0,
      'calories': 450.0,
      'carbs': 55.0,
      'fat': 20.0,
      'fiber': 3.5,
      'sugar': 2.5,
      'salt': 1.20
    },
    {
      'name': 'Pasta Spaghetti (100g matang)',
      'protein': 5.8,
      'calories': 158.0,
      'carbs': 31.0,
      'fat': 0.9,
      'fiber': 1.8,
      'sugar': 0.6,
      'salt': 0.01
    },
    {
      'name': 'Macaroni (100g matang)',
      'protein': 5.5,
      'calories': 155.0,
      'carbs': 30.0,
      'fat': 0.8,
      'fiber': 1.5,
      'sugar': 0.5,
      'salt': 0.01
    },
    {
      'name': 'Roti Tawar Putih (1 lembar)',
      'protein': 2.7,
      'calories': 70.0,
      'carbs': 13.0,
      'fat': 0.9,
      'fiber': 0.6,
      'sugar': 1.5,
      'salt': 0.15
    },
    {
      'name': 'Roti Gandum (1 lembar)',
      'protein': 3.6,
      'calories': 80.0,
      'carbs': 14.0,
      'fat': 1.0,
      'fiber': 2.0,
      'sugar': 1.5,
      'salt': 0.15
    },
    {
      'name': 'Bubur Ayam (1 mangkuk)',
      'protein': 12.0,
      'calories': 350.0,
      'carbs': 45.0,
      'fat': 12.0,
      'fiber': 2.5,
      'sugar': 2.0,
      'salt': 1.00
    },
    {
      'name': 'Lontong (100g)',
      'protein': 2.2,
      'calories': 144.0,
      'carbs': 31.0,
      'fat': 0.2,
      'fiber': 0.5,
      'sugar': 0.2,
      'salt': 0.01
    },
    {
      'name': 'Ketupat (100g)',
      'protein': 2.5,
      'calories': 160.0,
      'carbs': 34.0,
      'fat': 0.3,
      'fiber': 0.6,
      'sugar': 0.2,
      'salt': 0.01
    },
    {
      'name': 'Papeda (100g)',
      'protein': 0.5,
      'calories': 120.0,
      'carbs': 28.0,
      'fat': 0.1,
      'fiber': 0.3,
      'sugar': 0.1,
      'salt': 0.01
    },
    {
      'name': 'Talas Rebus (100g)',
      'protein': 1.5,
      'calories': 112.0,
      'carbs': 26.0,
      'fat': 0.1,
      'fiber': 4.1,
      'sugar': 0.4,
      'salt': 0.01
    },
    {
      'name': 'Oat/Havermut (50g)',
      'protein': 6.5,
      'calories': 190.0,
      'carbs': 33.0,
      'fat': 3.5,
      'fiber': 5.0,
      'sugar': 1.0,
      'salt': 0.01
    },
    {
      'name': 'Sereal Gandum (50g)',
      'protein': 5.0,
      'calories': 180.0,
      'carbs': 38.0,
      'fat': 2.0,
      'fiber': 4.0,
      'sugar': 5.0,
      'salt': 0.20
    },
    {
      'name': 'Granola (50g)',
      'protein': 7.0,
      'calories': 230.0,
      'carbs': 30.0,
      'fat': 10.0,
      'fiber': 4.5,
      'sugar': 8.0,
      'salt': 0.10
    },
    {
      'name': 'Pancake (1 buah)',
      'protein': 3.0,
      'calories': 90.0,
      'carbs': 14.0,
      'fat': 2.5,
      'fiber': 0.4,
      'sugar': 3.0,
      'salt': 0.20
    },
    {
      'name': 'Waffle (1 buah)',
      'protein': 4.0,
      'calories': 120.0,
      'carbs': 16.0,
      'fat': 4.5,
      'fiber': 0.5,
      'sugar': 3.5,
      'salt': 0.25
    },

    // A2. Lauk Pauk (lama)
    {
      'name': 'Telur Rebus (1 butir)',
      'protein': 6.3,
      'calories': 78.0,
      'carbs': 0.6,
      'fat': 5.3,
      'fiber': 0.0,
      'sugar': 0.2,
      'salt': 0.07
    },
    {
      'name': 'Telur Goreng / Ceplok (1 butir)',
      'protein': 6.5,
      'calories': 110.0,
      'carbs': 0.5,
      'fat': 9.0,
      'fiber': 0.0,
      'sugar': 0.2,
      'salt': 0.10
    },
    {
      'name': 'Telur Dadar (1 butir)',
      'protein': 7.0,
      'calories': 120.0,
      'carbs': 1.0,
      'fat': 10.0,
      'fiber': 0.0,
      'sugar': 0.5,
      'salt': 0.15
    },
    {
      'name': 'Telur Asin (1 butir)',
      'protein': 9.0,
      'calories': 130.0,
      'carbs': 1.5,
      'fat': 10.0,
      'fiber': 0.0,
      'sugar': 0.2,
      'salt': 0.70
    },
    {
      'name': 'Ayam Goreng (1 potong)',
      'protein': 18.0,
      'calories': 250.0,
      'carbs': 5.0,
      'fat': 16.0,
      'fiber': 0.0,
      'sugar': 0.5,
      'salt': 0.55
    },
    {
      'name': 'Ayam Bakar (1 potong)',
      'protein': 20.0,
      'calories': 200.0,
      'carbs': 6.0,
      'fat': 10.0,
      'fiber': 0.0,
      'sugar': 2.0,
      'salt': 0.60
    },
    {
      'name': 'Ayam Geprek (1 porsi)',
      'protein': 22.0,
      'calories': 320.0,
      'carbs': 15.0,
      'fat': 20.0,
      'fiber': 1.0,
      'sugar': 1.5,
      'salt': 0.90
    },
    {
      'name': 'Dada Ayam Fillet (100g)',
      'protein': 31.0,
      'calories': 165.0,
      'carbs': 0.0,
      'fat': 3.6,
      'fiber': 0.0,
      'sugar': 0.0,
      'salt': 0.07
    },
    {
      'name': 'Sate Ayam (5 tusuk)',
      'protein': 15.0,
      'calories': 180.0,
      'carbs': 5.0,
      'fat': 10.0,
      'fiber': 1.0,
      'sugar': 3.0,
      'salt': 0.50
    },
    {
      'name': 'Opor Ayam (1 potong)',
      'protein': 16.0,
      'calories': 280.0,
      'carbs': 4.0,
      'fat': 22.0,
      'fiber': 0.5,
      'sugar': 1.5,
      'salt': 0.70
    },
    {
      'name': 'Rendang Daging Sapi (1 potong)',
      'protein': 20.0,
      'calories': 250.0,
      'carbs': 5.0,
      'fat': 16.0,
      'fiber': 1.5,
      'sugar': 2.0,
      'salt': 0.80
    },
    {
      'name': 'Empal Sapi (1 potong)',
      'protein': 15.0,
      'calories': 220.0,
      'carbs': 8.0,
      'fat': 14.0,
      'fiber': 0.5,
      'sugar': 3.0,
      'salt': 0.60
    },
    {
      'name': 'Dendeng Balado (1 potong)',
      'protein': 18.0,
      'calories': 260.0,
      'carbs': 10.0,
      'fat': 15.0,
      'fiber': 1.0,
      'sugar': 4.0,
      'salt': 0.75
    },
    {
      'name': 'Bakso Sapi (5 butir)',
      'protein': 12.0,
      'calories': 200.0,
      'carbs': 8.0,
      'fat': 12.0,
      'fiber': 0.5,
      'sugar': 1.0,
      'salt': 0.90
    },
    {
      'name': 'Sosis Sapi/Ayam (1 bh)',
      'protein': 6.0,
      'calories': 140.0,
      'carbs': 3.0,
      'fat': 11.0,
      'fiber': 0.0,
      'sugar': 1.0,
      'salt': 0.55
    },
    {
      'name': 'Nugget Ayam (3 bh)',
      'protein': 9.0,
      'calories': 170.0,
      'carbs': 10.0,
      'fat': 10.0,
      'fiber': 0.5,
      'sugar': 1.0,
      'salt': 0.50
    },
    {
      'name': 'Ikan Goreng Lele/Nila (1 ekor)',
      'protein': 18.0,
      'calories': 220.0,
      'carbs': 2.0,
      'fat': 15.0,
      'fiber': 0.0,
      'sugar': 0.3,
      'salt': 0.45
    },
    {
      'name': 'Ikan Bakar (1 ekor)',
      'protein': 20.0,
      'calories': 160.0,
      'carbs': 1.0,
      'fat': 7.0,
      'fiber': 0.0,
      'sugar': 0.5,
      'salt': 0.60
    },
    {
      'name': 'Ikan Pepes (1 bungkus)',
      'protein': 18.0,
      'calories': 150.0,
      'carbs': 3.0,
      'fat': 6.0,
      'fiber': 1.0,
      'sugar': 0.5,
      'salt': 0.55
    },
    {
      'name': 'Ikan Salmon Panggang (100g)',
      'protein': 25.0,
      'calories': 206.0,
      'carbs': 0.0,
      'fat': 13.0,
      'fiber': 0.0,
      'sugar': 0.0,
      'salt': 0.06
    },
    {
      'name': 'Ikan Tuna Kaleng (100g)',
      'protein': 20.0,
      'calories': 110.0,
      'carbs': 0.0,
      'fat': 2.0,
      'fiber': 0.0,
      'sugar': 0.0,
      'salt': 0.35
    },
    {
      'name': 'Udang Goreng Tepung (100g)',
      'protein': 15.0,
      'calories': 240.0,
      'carbs': 18.0,
      'fat': 12.0,
      'fiber': 0.5,
      'sugar': 1.5,
      'salt': 0.70
    },
    {
      'name': 'Udang Balado (100g)',
      'protein': 18.0,
      'calories': 180.0,
      'carbs': 6.0,
      'fat': 9.0,
      'fiber': 1.0,
      'sugar': 2.0,
      'salt': 0.80
    },
    {
      'name': 'Cumi Saus Tiram (100g)',
      'protein': 15.0,
      'calories': 160.0,
      'carbs': 8.0,
      'fat': 6.0,
      'fiber': 0.5,
      'sugar': 3.0,
      'salt': 0.90
    },
    {
      'name': 'Cumi Goreng Tepung (100g)',
      'protein': 14.0,
      'calories': 280.0,
      'carbs': 20.0,
      'fat': 15.0,
      'fiber': 1.0,
      'sugar': 1.5,
      'salt': 0.65
    },
    {
      'name': 'Kepiting Saus Padang (100g)',
      'protein': 16.0,
      'calories': 190.0,
      'carbs': 8.0,
      'fat': 9.0,
      'fiber': 0.5,
      'sugar': 3.5,
      'salt': 1.10
    },
    {
      'name': 'Kerang Hijau (100g)',
      'protein': 14.0,
      'calories': 110.0,
      'carbs': 4.0,
      'fat': 3.0,
      'fiber': 0.0,
      'sugar': 0.5,
      'salt': 0.60
    },
    {
      'name': 'Tempe Goreng (100g)',
      'protein': 18.0,
      'calories': 250.0,
      'carbs': 10.0,
      'fat': 18.0,
      'fiber': 5.0,
      'sugar': 1.0,
      'salt': 0.10
    },
    {
      'name': 'Tempe Bacem (100g)',
      'protein': 15.0,
      'calories': 220.0,
      'carbs': 15.0,
      'fat': 10.0,
      'fiber': 4.5,
      'sugar': 6.0,
      'salt': 0.35
    },
    {
      'name': 'Oreg Tempe (100g)',
      'protein': 16.0,
      'calories': 260.0,
      'carbs': 18.0,
      'fat': 14.0,
      'fiber': 4.0,
      'sugar': 3.0,
      'salt': 0.40
    },
    {
      'name': 'Tahu Goreng (100g)',
      'protein': 9.0,
      'calories': 160.0,
      'carbs': 5.0,
      'fat': 12.0,
      'fiber': 1.0,
      'sugar': 0.5,
      'salt': 0.15
    },
    {
      'name': 'Tahu Isi (1 bh)',
      'protein': 5.0,
      'calories': 130.0,
      'carbs': 10.0,
      'fat': 8.0,
      'fiber': 1.5,
      'sugar': 1.0,
      'salt': 0.35
    },
    {
      'name': 'Tahu Bacem (1 potong)',
      'protein': 6.0,
      'calories': 110.0,
      'carbs': 12.0,
      'fat': 5.0,
      'fiber': 1.0,
      'sugar': 5.0,
      'salt': 0.30
    },
    {
      'name': 'Tahu Gejrot (1 porsi)',
      'protein': 8.0,
      'calories': 180.0,
      'carbs': 20.0,
      'fat': 8.0,
      'fiber': 2.0,
      'sugar': 6.0,
      'salt': 0.70
    },
    {
      'name': 'Pepes Tahu (1 bungkus)',
      'protein': 8.0,
      'calories': 100.0,
      'carbs': 6.0,
      'fat': 5.0,
      'fiber': 1.5,
      'sugar': 1.0,
      'salt': 0.30
    },
    {
      'name': 'Daging Kambing Gulai (100g)',
      'protein': 18.0,
      'calories': 260.0,
      'carbs': 4.0,
      'fat': 18.0,
      'fiber': 0.5,
      'sugar': 1.0,
      'salt': 0.55
    },
    {
      'name': 'Sate Kambing (5 tusuk)',
      'protein': 18.0,
      'calories': 210.0,
      'carbs': 5.0,
      'fat': 12.0,
      'fiber': 0.5,
      'sugar': 2.0,
      'salt': 0.50
    },
    {
      'name': 'Hati Ayam Goreng (50g)',
      'protein': 13.0,
      'calories': 120.0,
      'carbs': 1.0,
      'fat': 7.0,
      'fiber': 0.0,
      'sugar': 0.3,
      'salt': 0.25
    },
    {
      'name': 'Ampela Ayam (50g)',
      'protein': 10.0,
      'calories': 90.0,
      'carbs': 0.0,
      'fat': 4.0,
      'fiber': 0.0,
      'sugar': 0.0,
      'salt': 0.20
    },
    {
      'name': 'Ikan Asin Peda (50g)',
      'protein': 14.0,
      'calories': 110.0,
      'carbs': 0.0,
      'fat': 5.0,
      'fiber': 0.0,
      'sugar': 0.0,
      'salt': 1.50
    },
    {
      'name': 'Teri Medan Goreng (50g)',
      'protein': 16.0,
      'calories': 180.0,
      'carbs': 2.0,
      'fat': 12.0,
      'fiber': 0.5,
      'sugar': 0.3,
      'salt': 0.80
    },
    {
      'name': 'Telur Puyuh (5 butir)',
      'protein': 6.0,
      'calories': 75.0,
      'carbs': 0.5,
      'fat': 5.5,
      'fiber': 0.0,
      'sugar': 0.2,
      'salt': 0.12
    },
    {
      'name': 'Kornet Sapi (50g)',
      'protein': 8.0,
      'calories': 120.0,
      'carbs': 2.0,
      'fat': 9.0,
      'fiber': 0.0,
      'sugar': 0.5,
      'salt': 0.55
    },
    {
      'name': 'Smoke Beef (50g)',
      'protein': 9.0,
      'calories': 90.0,
      'carbs': 1.0,
      'fat': 5.0,
      'fiber': 0.0,
      'sugar': 0.5,
      'salt': 0.60
    },
    {
      'name': 'Keju Cheddar (30g)',
      'protein': 7.0,
      'calories': 120.0,
      'carbs': 1.0,
      'fat': 10.0,
      'fiber': 0.0,
      'sugar': 0.3,
      'salt': 0.18
    },
    {
      'name': 'Yogurt Plain (150g)',
      'protein': 15.0,
      'calories': 100.0,
      'carbs': 6.0,
      'fat': 0.5,
      'fiber': 0.0,
      'sugar': 5.0,
      'salt': 0.07
    },
    {
      'name': 'Susu Sapi Segar (250ml)',
      'protein': 8.0,
      'calories': 150.0,
      'carbs': 12.0,
      'fat': 8.0,
      'fiber': 0.0,
      'sugar': 11.0,
      'salt': 0.10
    },
    {
      'name': 'Edamame Rebus (100g)',
      'protein': 11.0,
      'calories': 122.0,
      'carbs': 10.0,
      'fat': 5.0,
      'fiber': 5.0,
      'sugar': 2.2,
      'salt': 0.01
    },
    {
      'name': 'Kacang Tanah Goreng (50g)',
      'protein': 13.0,
      'calories': 290.0,
      'carbs': 10.0,
      'fat': 25.0,
      'fiber': 4.0,
      'sugar': 1.5,
      'salt': 0.10
    },
    {
      'name': 'Kacang Merah dalam Sup (100g)',
      'protein': 9.0,
      'calories': 130.0,
      'carbs': 23.0,
      'fat': 0.5,
      'fiber': 7.0,
      'sugar': 0.3,
      'salt': 0.01
    },

    // A3. Sayur-Mayur & Sup (lama)
    {
      'name': 'Sayur Bayam Bening (1 mangkuk)',
      'protein': 3.0,
      'calories': 50.0,
      'carbs': 8.0,
      'fat': 1.0,
      'fiber': 3.0,
      'sugar': 1.5,
      'salt': 0.10
    },
    {
      'name': 'Sayur Asem (1 mangkuk)',
      'protein': 2.0,
      'calories': 80.0,
      'carbs': 15.0,
      'fat': 2.0,
      'fiber': 4.0,
      'sugar': 3.0,
      'salt': 0.30
    },
    {
      'name': 'Sayur Lodeh (1 mangkuk)',
      'protein': 4.0,
      'calories': 150.0,
      'carbs': 12.0,
      'fat': 10.0,
      'fiber': 3.0,
      'sugar': 2.5,
      'salt': 0.40
    },
    {
      'name': 'Capcay Kuah (1 mangkuk)',
      'protein': 6.0,
      'calories': 120.0,
      'carbs': 14.0,
      'fat': 5.0,
      'fiber': 4.0,
      'sugar': 3.0,
      'salt': 0.80
    },
    {
      'name': 'Capcay Goreng (1 porsi)',
      'protein': 6.0,
      'calories': 200.0,
      'carbs': 18.0,
      'fat': 12.0,
      'fiber': 4.0,
      'sugar': 3.5,
      'salt': 0.90
    },
    {
      'name': 'Tumis Kangkung (1 porsi)',
      'protein': 3.0,
      'calories': 100.0,
      'carbs': 8.0,
      'fat': 7.0,
      'fiber': 3.0,
      'sugar': 1.5,
      'salt': 0.50
    },
    {
      'name': 'Tumis Sawi Hijau (1 porsi)',
      'protein': 2.0,
      'calories': 80.0,
      'carbs': 6.0,
      'fat': 5.0,
      'fiber': 2.5,
      'sugar': 1.5,
      'salt': 0.40
    },
    {
      'name': 'Tumis Sawi Putih (1 porsi)',
      'protein': 2.0,
      'calories': 70.0,
      'carbs': 5.0,
      'fat': 5.0,
      'fiber': 2.0,
      'sugar': 1.5,
      'salt': 0.35
    },
    {
      'name': 'Tumis Buncis (1 porsi)',
      'protein': 2.0,
      'calories': 90.0,
      'carbs': 8.0,
      'fat': 6.0,
      'fiber': 3.0,
      'sugar': 2.0,
      'salt': 0.40
    },
    {
      'name': 'Tumis Kacang Panjang (1 porsi)',
      'protein': 3.0,
      'calories': 110.0,
      'carbs': 10.0,
      'fat': 7.0,
      'fiber': 4.0,
      'sugar': 2.5,
      'salt': 0.45
    },
    {
      'name': 'Tumis Toge (1 porsi)',
      'protein': 4.0,
      'calories': 80.0,
      'carbs': 6.0,
      'fat': 5.0,
      'fiber': 2.0,
      'sugar': 1.5,
      'salt': 0.40
    },
    {
      'name': 'Tumis Jamur Tiram (1 porsi)',
      'protein': 3.0,
      'calories': 90.0,
      'carbs': 7.0,
      'fat': 6.0,
      'fiber': 2.5,
      'sugar': 1.5,
      'salt': 0.45
    },
    {
      'name': 'Brokoli Rebus (100g)',
      'protein': 2.8,
      'calories': 35.0,
      'carbs': 7.0,
      'fat': 0.4,
      'fiber': 3.3,
      'sugar': 1.7,
      'salt': 0.01
    },
    {
      'name': 'Kembang Kol Goreng Tepung (100g)',
      'protein': 3.0,
      'calories': 180.0,
      'carbs': 15.0,
      'fat': 12.0,
      'fiber': 2.0,
      'sugar': 2.0,
      'salt': 0.35
    },
    {
      'name': 'Terong Balado (1 porsi)',
      'protein': 2.0,
      'calories': 150.0,
      'carbs': 10.0,
      'fat': 12.0,
      'fiber': 4.0,
      'sugar': 3.5,
      'salt': 0.55
    },
    {
      'name': 'Lalapan Mentimun (100g)',
      'protein': 0.7,
      'calories': 15.0,
      'carbs': 3.6,
      'fat': 0.1,
      'fiber': 0.5,
      'sugar': 1.7,
      'salt': 0.00
    },
    {
      'name': 'Lalapan Kemangi (50g)',
      'protein': 1.6,
      'calories': 12.0,
      'carbs': 1.5,
      'fat': 0.3,
      'fiber': 0.8,
      'sugar': 0.5,
      'salt': 0.00
    },
    {
      'name': 'Selada Fresh (50g)',
      'protein': 0.7,
      'calories': 8.0,
      'carbs': 1.5,
      'fat': 0.1,
      'fiber': 0.6,
      'sugar': 0.8,
      'salt': 0.00
    },
    {
      'name': 'Salad Sayur Mix (1 mangkuk)',
      'protein': 3.0,
      'calories': 110.0,
      'carbs': 12.0,
      'fat': 6.0,
      'fiber': 5.0,
      'sugar': 4.0,
      'salt': 0.30
    },
    {
      'name': 'Gado-Gado (1 porsi)',
      'protein': 15.0,
      'calories': 350.0,
      'carbs': 40.0,
      'fat': 18.0,
      'fiber': 8.0,
      'sugar': 6.0,
      'salt': 0.80
    },
    {
      'name': 'Lotek (1 porsi)',
      'protein': 14.0,
      'calories': 330.0,
      'carbs': 38.0,
      'fat': 16.0,
      'fiber': 7.0,
      'sugar': 5.0,
      'salt': 0.70
    },
    {
      'name': 'Pecel Sayur (1 porsi)',
      'protein': 12.0,
      'calories': 300.0,
      'carbs': 35.0,
      'fat': 14.0,
      'fiber': 6.0,
      'sugar': 5.0,
      'salt': 0.65
    },
    {
      'name': 'Karedok (1 porsi)',
      'protein': 10.0,
      'calories': 280.0,
      'carbs': 30.0,
      'fat': 15.0,
      'fiber': 6.0,
      'sugar': 5.0,
      'salt': 0.60
    },
    {
      'name': 'Kimchi (100g)',
      'protein': 1.1,
      'calories': 15.0,
      'carbs': 3.0,
      'fat': 0.2,
      'fiber': 1.2,
      'sugar': 1.5,
      'salt': 1.20
    },
    {
      'name': 'Sup Kimlo (1 mangkuk)',
      'protein': 10.0,
      'calories': 180.0,
      'carbs': 15.0,
      'fat': 8.0,
      'fiber': 3.0,
      'sugar': 3.0,
      'salt': 0.85
    },
    {
      'name': 'Sup Asparagus (1 mangkuk)',
      'protein': 6.0,
      'calories': 120.0,
      'carbs': 12.0,
      'fat': 5.0,
      'fiber': 2.0,
      'sugar': 3.0,
      'salt': 0.70
    },
    {
      'name': 'Sup Krim Jagung (1 mangkuk)',
      'protein': 5.0,
      'calories': 200.0,
      'carbs': 25.0,
      'fat': 10.0,
      'fiber': 2.0,
      'sugar': 6.0,
      'salt': 0.75
    },
    {
      'name': 'Sup Buntut (1 mangkuk)',
      'protein': 25.0,
      'calories': 350.0,
      'carbs': 10.0,
      'fat': 22.0,
      'fiber': 2.0,
      'sugar': 2.0,
      'salt': 1.10
    },
    {
      'name': 'Sup Iga (1 mangkuk)',
      'protein': 24.0,
      'calories': 380.0,
      'carbs': 12.0,
      'fat': 25.0,
      'fiber': 2.0,
      'sugar': 2.5,
      'salt': 1.20
    },
    {
      'name': 'Soto Ayam (1 mangkuk)',
      'protein': 18.0,
      'calories': 250.0,
      'carbs': 15.0,
      'fat': 12.0,
      'fiber': 2.0,
      'sugar': 2.5,
      'salt': 1.00
    },
    {
      'name': 'Soto Daging (1 mangkuk)',
      'protein': 20.0,
      'calories': 280.0,
      'carbs': 12.0,
      'fat': 16.0,
      'fiber': 2.0,
      'sugar': 2.0,
      'salt': 1.10
    },
    {
      'name': 'Soto Betawi (1 mangkuk)',
      'protein': 22.0,
      'calories': 400.0,
      'carbs': 15.0,
      'fat': 28.0,
      'fiber': 2.0,
      'sugar': 2.5,
      'salt': 1.30
    },
    {
      'name': 'Rawon (1 mangkuk)',
      'protein': 20.0,
      'calories': 320.0,
      'carbs': 18.0,
      'fat': 18.0,
      'fiber': 3.0,
      'sugar': 2.0,
      'salt': 1.20
    },
    {
      'name': 'Gudeg (1 porsi)',
      'protein': 8.0,
      'calories': 300.0,
      'carbs': 45.0,
      'fat': 10.0,
      'fiber': 6.0,
      'sugar': 8.0,
      'salt': 0.60
    },
    {
      'name': 'Oseng Mercon (1 porsi)',
      'protein': 18.0,
      'calories': 350.0,
      'carbs': 10.0,
      'fat': 25.0,
      'fiber': 2.0,
      'sugar': 3.0,
      'salt': 1.00
    },
    {
      'name': 'Tumis Pare (1 porsi)',
      'protein': 2.0,
      'calories': 90.0,
      'carbs': 8.0,
      'fat': 6.0,
      'fiber': 4.0,
      'sugar': 1.5,
      'salt': 0.40
    },
    {
      'name': 'Tumis Daun Singkong (1 porsi)',
      'protein': 6.0,
      'calories': 140.0,
      'carbs': 10.0,
      'fat': 8.0,
      'fiber': 5.0,
      'sugar': 1.5,
      'salt': 0.50
    },
    {
      'name': 'Tumis Bunga Pepaya (1 porsi)',
      'protein': 3.0,
      'calories': 100.0,
      'carbs': 9.0,
      'fat': 6.0,
      'fiber': 4.0,
      'sugar': 1.5,
      'salt': 0.40
    },
    {
      'name': 'Sayur Labu Siam (1 mangkuk)',
      'protein': 2.0,
      'calories': 120.0,
      'carbs': 10.0,
      'fat': 8.0,
      'fiber': 3.0,
      'sugar': 2.5,
      'salt': 0.35
    },
    {
      'name': 'Sayur Nangka / Gulai (1 mangkuk)',
      'protein': 3.0,
      'calories': 220.0,
      'carbs': 20.0,
      'fat': 15.0,
      'fiber': 6.0,
      'sugar': 4.0,
      'salt': 0.60
    },
    {
      'name': 'Wortel Rebus (100g)',
      'protein': 0.9,
      'calories': 41.0,
      'carbs': 10.0,
      'fat': 0.2,
      'fiber': 2.8,
      'sugar': 4.7,
      'salt': 0.07
    },
    {
      'name': 'Labu Kuning Kukus (100g)',
      'protein': 1.0,
      'calories': 26.0,
      'carbs': 6.5,
      'fat': 0.1,
      'fiber': 0.5,
      'sugar': 2.8,
      'salt': 0.00
    },
    {
      'name': 'Petai Goreng (50g)',
      'protein': 3.0,
      'calories': 90.0,
      'carbs': 8.0,
      'fat': 5.0,
      'fiber': 2.0,
      'sugar': 1.5,
      'salt': 0.15
    },
    {
      'name': 'Jengkol Balado (1 porsi)',
      'protein': 8.0,
      'calories': 240.0,
      'carbs': 20.0,
      'fat': 14.0,
      'fiber': 5.0,
      'sugar': 3.0,
      'salt': 0.80
    },
    {
      'name': 'Sambal Goreng Kentang (1 porsi)',
      'protein': 4.0,
      'calories': 220.0,
      'carbs': 25.0,
      'fat': 12.0,
      'fiber': 3.0,
      'sugar': 3.5,
      'salt': 0.70
    },
    {
      'name': 'Sambal Terasi (1 sdm)',
      'protein': 0.5,
      'calories': 35.0,
      'carbs': 2.0,
      'fat': 3.0,
      'fiber': 0.5,
      'sugar': 1.0,
      'salt': 0.35
    },
    {
      'name': 'Sambal Matah (1 sdm)',
      'protein': 0.2,
      'calories': 45.0,
      'carbs': 1.0,
      'fat': 4.5,
      'fiber': 0.3,
      'sugar': 0.5,
      'salt': 0.20
    },
    {
      'name': 'Sambal Ijo (1 sdm)',
      'protein': 0.4,
      'calories': 40.0,
      'carbs': 2.0,
      'fat': 3.5,
      'fiber': 0.5,
      'sugar': 1.0,
      'salt': 0.25
    },
    {
      'name': 'Sambal Bawang (1 sdm)',
      'protein': 0.3,
      'calories': 50.0,
      'carbs': 1.5,
      'fat': 5.0,
      'fiber': 0.3,
      'sugar': 0.5,
      'salt': 0.30
    },
    {
      'name': 'Acar Kuning (1 porsi)',
      'protein': 1.5,
      'calories': 80.0,
      'carbs': 12.0,
      'fat': 3.0,
      'fiber': 2.0,
      'sugar': 5.0,
      'salt': 0.35
    },

    // A4. Buah-Buahan (lama)
    {
      'name': 'Pisang Cavendish (1 buah)',
      'protein': 1.3,
      'calories': 105.0,
      'carbs': 27.0,
      'fat': 0.3,
      'fiber': 3.1,
      'sugar': 14.4,
      'salt': 0.00
    },
    {
      'name': 'Pisang Raja (1 buah)',
      'protein': 1.5,
      'calories': 120.0,
      'carbs': 30.0,
      'fat': 0.4,
      'fiber': 2.5,
      'sugar': 16.0,
      'salt': 0.00
    },
    {
      'name': 'Apel Merah (1 buah)',
      'protein': 0.3,
      'calories': 95.0,
      'carbs': 25.0,
      'fat': 0.2,
      'fiber': 4.4,
      'sugar': 19.0,
      'salt': 0.00
    },
    {
      'name': 'Apel Malang (1 buah)',
      'protein': 0.4,
      'calories': 80.0,
      'carbs': 21.0,
      'fat': 0.2,
      'fiber': 4.0,
      'sugar': 16.0,
      'salt': 0.00
    },
    {
      'name': 'Jeruk Manis (1 buah)',
      'protein': 0.9,
      'calories': 62.0,
      'carbs': 15.0,
      'fat': 0.1,
      'fiber': 3.1,
      'sugar': 12.0,
      'salt': 0.00
    },
    {
      'name': 'Jeruk Nipis (1 buah)',
      'protein': 0.3,
      'calories': 20.0,
      'carbs': 7.0,
      'fat': 0.1,
      'fiber': 1.9,
      'sugar': 1.1,
      'salt': 0.00
    },
    {
      'name': 'Mangga Harum Manis (1 buah)',
      'protein': 1.4,
      'calories': 200.0,
      'carbs': 50.0,
      'fat': 0.6,
      'fiber': 5.4,
      'sugar': 45.0,
      'salt': 0.00
    },
    {
      'name': 'Pepaya (1 potong besar)',
      'protein': 0.9,
      'calories': 68.0,
      'carbs': 17.0,
      'fat': 0.4,
      'fiber': 2.7,
      'sugar': 11.3,
      'salt': 0.00
    },
    {
      'name': 'Semangka Merah (1 potong)',
      'protein': 1.0,
      'calories': 45.0,
      'carbs': 11.0,
      'fat': 0.2,
      'fiber': 0.6,
      'sugar': 9.2,
      'salt': 0.00
    },
    {
      'name': 'Semangka Kuning (1 potong)',
      'protein': 1.0,
      'calories': 46.0,
      'carbs': 11.5,
      'fat': 0.2,
      'fiber': 0.7,
      'sugar': 9.5,
      'salt': 0.00
    },
    {
      'name': 'Melon Hijau (1 potong)',
      'protein': 1.2,
      'calories': 50.0,
      'carbs': 13.0,
      'fat': 0.3,
      'fiber': 1.4,
      'sugar': 12.0,
      'salt': 0.00
    },
    {
      'name': 'Melon Cantaloupe (1 potong)',
      'protein': 1.1,
      'calories': 45.0,
      'carbs': 11.0,
      'fat': 0.2,
      'fiber': 1.2,
      'sugar': 10.6,
      'salt': 0.00
    },
    {
      'name': 'Alpukat (1 buah sedang)',
      'protein': 3.0,
      'calories': 240.0,
      'carbs': 12.0,
      'fat': 22.0,
      'fiber': 10.0,
      'sugar': 0.4,
      'salt': 0.01
    },
    {
      'name': 'Buah Naga Merah (1 buah)',
      'protein': 2.4,
      'calories': 120.0,
      'carbs': 26.0,
      'fat': 0.8,
      'fiber': 3.5,
      'sugar': 8.0,
      'salt': 0.00
    },
    {
      'name': 'Nanas (1 potong besar)',
      'protein': 0.5,
      'calories': 50.0,
      'carbs': 13.0,
      'fat': 0.1,
      'fiber': 1.4,
      'sugar': 10.0,
      'salt': 0.00
    },
    {
      'name': 'Anggur Merah (100g)',
      'protein': 0.7,
      'calories': 69.0,
      'carbs': 18.0,
      'fat': 0.2,
      'fiber': 0.9,
      'sugar': 15.5,
      'salt': 0.00
    },
    {
      'name': 'Anggur Hijau (100g)',
      'protein': 0.7,
      'calories': 69.0,
      'carbs': 18.0,
      'fat': 0.2,
      'fiber': 0.9,
      'sugar': 15.5,
      'salt': 0.00
    },
    {
      'name': 'Strawberry (100g)',
      'protein': 0.7,
      'calories': 32.0,
      'carbs': 8.0,
      'fat': 0.3,
      'fiber': 2.0,
      'sugar': 4.9,
      'salt': 0.00
    },
    {
      'name': 'Blueberry (100g)',
      'protein': 0.7,
      'calories': 57.0,
      'carbs': 14.0,
      'fat': 0.3,
      'fiber': 2.4,
      'sugar': 10.0,
      'salt': 0.00
    },
    {
      'name': 'Kelengkeng (100g)',
      'protein': 1.3,
      'calories': 60.0,
      'carbs': 15.0,
      'fat': 0.1,
      'fiber': 1.1,
      'sugar': 13.0,
      'salt': 0.00
    },
    {
      'name': 'Rambutan (100g)',
      'protein': 0.9,
      'calories': 82.0,
      'carbs': 21.0,
      'fat': 0.2,
      'fiber': 0.9,
      'sugar': 17.0,
      'salt': 0.00
    },
    {
      'name': 'Durian (100g)',
      'protein': 1.5,
      'calories': 147.0,
      'carbs': 27.0,
      'fat': 5.0,
      'fiber': 3.8,
      'sugar': 20.0,
      'salt': 0.00
    },
    {
      'name': 'Manggis (100g)',
      'protein': 0.6,
      'calories': 73.0,
      'carbs': 18.0,
      'fat': 0.6,
      'fiber': 1.8,
      'sugar': 16.0,
      'salt': 0.00
    },
    {
      'name': 'Sawo (100g)',
      'protein': 0.4,
      'calories': 83.0,
      'carbs': 20.0,
      'fat': 1.1,
      'fiber': 5.3,
      'sugar': 14.0,
      'salt': 0.00
    },
    {
      'name': 'Jambu Biji / Guava (1 buah)',
      'protein': 4.2,
      'calories': 112.0,
      'carbs': 23.0,
      'fat': 1.6,
      'fiber': 8.9,
      'sugar': 9.0,
      'salt': 0.00
    },
    {
      'name': 'Jambu Air (100g)',
      'protein': 0.6,
      'calories': 46.0,
      'carbs': 11.0,
      'fat': 0.2,
      'fiber': 1.2,
      'sugar': 8.0,
      'salt': 0.00
    },
    {
      'name': 'Salak (100g)',
      'protein': 0.4,
      'calories': 77.0,
      'carbs': 21.0,
      'fat': 0.2,
      'fiber': 0.8,
      'sugar': 16.0,
      'salt': 0.00
    },
    {
      'name': 'Kurma (3 butir)',
      'protein': 0.6,
      'calories': 60.0,
      'carbs': 16.0,
      'fat': 0.1,
      'fiber': 1.8,
      'sugar': 14.5,
      'salt': 0.00
    },
    {
      'name': 'Pir (1 buah)',
      'protein': 0.6,
      'calories': 101.0,
      'carbs': 27.0,
      'fat': 0.2,
      'fiber': 5.5,
      'sugar': 17.0,
      'salt': 0.00
    },
    {
      'name': 'Kiwi (1 buah)',
      'protein': 0.8,
      'calories': 42.0,
      'carbs': 10.0,
      'fat': 0.4,
      'fiber': 2.1,
      'sugar': 6.2,
      'salt': 0.00
    },
    {
      'name': 'Delima (100g)',
      'protein': 1.7,
      'calories': 83.0,
      'carbs': 19.0,
      'fat': 1.2,
      'fiber': 4.0,
      'sugar': 13.7,
      'salt': 0.00
    },
    {
      'name': 'Markisa (100g)',
      'protein': 2.2,
      'calories': 97.0,
      'carbs': 23.0,
      'fat': 0.7,
      'fiber': 10.0,
      'sugar': 11.2,
      'salt': 0.00
    },
    {
      'name': 'Bengkoang (100g)',
      'protein': 0.7,
      'calories': 38.0,
      'carbs': 9.0,
      'fat': 0.1,
      'fiber': 5.0,
      'sugar': 1.8,
      'salt': 0.00
    },
    {
      'name': 'Sirsak (100g)',
      'protein': 1.0,
      'calories': 66.0,
      'carbs': 17.0,
      'fat': 0.3,
      'fiber': 3.3,
      'sugar': 13.5,
      'salt': 0.00
    },
    {
      'name': 'Kedondong (100g)',
      'protein': 0.8,
      'calories': 41.0,
      'carbs': 10.0,
      'fat': 0.2,
      'fiber': 1.5,
      'sugar': 4.0,
      'salt': 0.00
    },
    {
      'name': 'Nangka Matang (100g)',
      'protein': 1.7,
      'calories': 95.0,
      'carbs': 23.0,
      'fat': 0.6,
      'fiber': 1.5,
      'sugar': 19.1,
      'salt': 0.00
    },
    {
      'name': 'Cempedak (100g)',
      'protein': 2.5,
      'calories': 115.0,
      'carbs': 25.0,
      'fat': 0.4,
      'fiber': 1.2,
      'sugar': 20.0,
      'salt': 0.00
    },
    {
      'name': 'Kelapa Muda Daging (100g)',
      'protein': 3.3,
      'calories': 354.0,
      'carbs': 15.0,
      'fat': 33.0,
      'fiber': 9.0,
      'sugar': 6.2,
      'salt': 0.02
    },
    {
      'name': 'Buah Tin (100g)',
      'protein': 0.8,
      'calories': 74.0,
      'carbs': 19.0,
      'fat': 0.3,
      'fiber': 2.9,
      'sugar': 16.3,
      'salt': 0.00
    },
    {
      'name': 'Apricot Kering (50g)',
      'protein': 1.7,
      'calories': 120.0,
      'carbs': 31.0,
      'fat': 0.2,
      'fiber': 3.6,
      'sugar': 26.0,
      'salt': 0.01
    },

    // A5. Snacks & Jajanan (lama)
    {
      'name': 'Martabak Manis Coklat Kacang (1 potong)',
      'protein': 5.0,
      'calories': 280.0,
      'carbs': 35.0,
      'fat': 12.0,
      'fiber': 1.5,
      'sugar': 15.0,
      'salt': 0.30
    },
    {
      'name': 'Martabak Telur (1 potong)',
      'protein': 7.0,
      'calories': 200.0,
      'carbs': 15.0,
      'fat': 12.0,
      'fiber': 1.0,
      'sugar': 1.5,
      'salt': 0.55
    },
    {
      'name': 'Pisang Goreng (1 buah)',
      'protein': 1.5,
      'calories': 180.0,
      'carbs': 25.0,
      'fat': 8.0,
      'fiber': 2.0,
      'sugar': 10.0,
      'salt': 0.05
    },
    {
      'name': 'Bakwan Sayur (1 buah)',
      'protein': 2.0,
      'calories': 140.0,
      'carbs': 15.0,
      'fat': 8.0,
      'fiber': 1.5,
      'sugar': 1.5,
      'salt': 0.30
    },
    {
      'name': 'Cireng (1 buah)',
      'protein': 0.5,
      'calories': 80.0,
      'carbs': 15.0,
      'fat': 2.0,
      'fiber': 0.2,
      'sugar': 0.5,
      'salt': 0.15
    },
    {
      'name': 'Cilok (5 btr + bumbu kacang)',
      'protein': 4.0,
      'calories': 250.0,
      'carbs': 35.0,
      'fat': 10.0,
      'fiber': 1.0,
      'sugar': 5.0,
      'salt': 0.60
    },
    {
      'name': 'Batagor (1 porsi)',
      'protein': 12.0,
      'calories': 400.0,
      'carbs': 40.0,
      'fat': 22.0,
      'fiber': 2.0,
      'sugar': 4.0,
      'salt': 0.90
    },
    {
      'name': 'Pempek Kapal Selam (1 buah)',
      'protein': 15.0,
      'calories': 280.0,
      'carbs': 30.0,
      'fat': 10.0,
      'fiber': 1.0,
      'sugar': 3.0,
      'salt': 0.80
    },
    {
      'name': 'Risoles Mayo (1 buah)',
      'protein': 5.0,
      'calories': 220.0,
      'carbs': 20.0,
      'fat': 13.0,
      'fiber': 1.0,
      'sugar': 2.0,
      'salt': 0.45
    },
    {
      'name': 'Pastel (1 buah)',
      'protein': 4.0,
      'calories': 200.0,
      'carbs': 22.0,
      'fat': 11.0,
      'fiber': 1.5,
      'sugar': 1.5,
      'salt': 0.40
    },
    {
      'name': 'Lemper Ayam (1 buah)',
      'protein': 4.0,
      'calories': 160.0,
      'carbs': 25.0,
      'fat': 5.0,
      'fiber': 1.0,
      'sugar': 1.0,
      'salt': 0.30
    },
    {
      'name': 'Nagasari (1 buah)',
      'protein': 1.5,
      'calories': 150.0,
      'carbs': 28.0,
      'fat': 4.0,
      'fiber': 1.0,
      'sugar': 8.0,
      'salt': 0.05
    },
    {
      'name': 'Klepon (3 buah)',
      'protein': 1.0,
      'calories': 120.0,
      'carbs': 25.0,
      'fat': 2.0,
      'fiber': 1.0,
      'sugar': 10.0,
      'salt': 0.05
    },
    {
      'name': 'Kue Lapis (1 potong)',
      'protein': 2.0,
      'calories': 180.0,
      'carbs': 35.0,
      'fat': 4.0,
      'fiber': 0.5,
      'sugar': 15.0,
      'salt': 0.10
    },
    {
      'name': 'Brownies Cokelat (1 potong)',
      'protein': 3.0,
      'calories': 250.0,
      'carbs': 30.0,
      'fat': 14.0,
      'fiber': 1.5,
      'sugar': 18.0,
      'salt': 0.20
    },
    {
      'name': 'Cookies Choco Chip (2 keping)',
      'protein': 2.0,
      'calories': 160.0,
      'carbs': 20.0,
      'fat': 8.0,
      'fiber': 0.5,
      'sugar': 10.0,
      'salt': 0.15
    },
    {
      'name': 'Keripik Singkong (50g)',
      'protein': 1.0,
      'calories': 240.0,
      'carbs': 35.0,
      'fat': 10.0,
      'fiber': 2.0,
      'sugar': 1.5,
      'salt': 0.35
    },
    {
      'name': 'Keripik Pisang (50g)',
      'protein': 1.5,
      'calories': 260.0,
      'carbs': 32.0,
      'fat': 14.0,
      'fiber': 3.0,
      'sugar': 10.0,
      'salt': 0.10
    },
    {
      'name': 'Kerupuk Kaleng (1 buah)',
      'protein': 0.5,
      'calories': 60.0,
      'carbs': 10.0,
      'fat': 2.0,
      'fiber': 0.0,
      'sugar': 0.3,
      'salt': 0.15
    },
    {
      'name': 'Emping Melinjo (50g)',
      'protein': 3.0,
      'calories': 250.0,
      'carbs': 30.0,
      'fat': 12.0,
      'fiber': 2.0,
      'sugar': 1.0,
      'salt': 0.30
    },
    {
      'name': 'Kacang Atom (50g)',
      'protein': 7.0,
      'calories': 260.0,
      'carbs': 22.0,
      'fat': 15.0,
      'fiber': 3.0,
      'sugar': 2.0,
      'salt': 0.40
    },
    {
      'name': 'Kuaci (50g)',
      'protein': 10.0,
      'calories': 290.0,
      'carbs': 10.0,
      'fat': 24.0,
      'fiber': 4.0,
      'sugar': 1.0,
      'salt': 0.10
    },
    {
      'name': 'Popcorn Asin (50g)',
      'protein': 6.0,
      'calories': 190.0,
      'carbs': 38.0,
      'fat': 2.0,
      'fiber': 7.0,
      'sugar': 0.5,
      'salt': 0.55
    },
    {
      'name': 'Pudding Mangga (1 cup)',
      'protein': 2.0,
      'calories': 150.0,
      'carbs': 25.0,
      'fat': 3.0,
      'fiber': 1.0,
      'sugar': 15.0,
      'salt': 0.05
    },
    {
      'name': 'Salad Buah dgn Mayones (1 mangkuk)',
      'protein': 3.0,
      'calories': 280.0,
      'carbs': 30.0,
      'fat': 16.0,
      'fiber': 4.0,
      'sugar': 18.0,
      'salt': 0.20
    },
    {
      'name': 'Rujak Buah (1 porsi)',
      'protein': 2.0,
      'calories': 180.0,
      'carbs': 40.0,
      'fat': 3.0,
      'fiber': 6.0,
      'sugar': 25.0,
      'salt': 0.40
    },
    {
      'name': 'Gorengan Tempe Mendoan (1 buah)',
      'protein': 5.0,
      'calories': 160.0,
      'carbs': 14.0,
      'fat': 10.0,
      'fiber': 2.0,
      'sugar': 1.0,
      'salt': 0.20
    },
    {
      'name': 'Donat Gula (1 buah)',
      'protein': 3.0,
      'calories': 220.0,
      'carbs': 30.0,
      'fat': 10.0,
      'fiber': 1.0,
      'sugar': 12.0,
      'salt': 0.25
    },
    {
      'name': 'Cimol (10 butir)',
      'protein': 1.0,
      'calories': 200.0,
      'carbs': 35.0,
      'fat': 6.0,
      'fiber': 0.5,
      'sugar': 1.0,
      'salt': 0.25
    },
    {
      'name': 'Jasuke Jagung Susu Keju (1 cup)',
      'protein': 6.0,
      'calories': 280.0,
      'carbs': 35.0,
      'fat': 12.0,
      'fiber': 3.0,
      'sugar': 15.0,
      'salt': 0.35
    },

    // ─────────────────────────────────────────────
    // KATEGORI B: DATA BARU (200 item tambahan)
    // ─────────────────────────────────────────────

    // B1. Makanan Pokok & Karbo (baru)
    {
      'name': 'Nasi Kuning (1 porsi)',
      'protein': 5.8,
      'calories': 320.0,
      'carbs': 63.0,
      'fat': 5.5,
      'fiber': 0.8,
      'sugar': 1.0,
      'salt': 0.45
    },
    {
      'name': 'Nasi Goreng Kampung (1 piring)',
      'protein': 9.5,
      'calories': 420.0,
      'carbs': 65.0,
      'fat': 13.0,
      'fiber': 1.2,
      'sugar': 2.0,
      'salt': 1.10
    },
    {
      'name': 'Nasi Goreng Seafood (1 piring)',
      'protein': 18.0,
      'calories': 480.0,
      'carbs': 62.0,
      'fat': 15.0,
      'fiber': 1.5,
      'sugar': 2.5,
      'salt': 1.40
    },
    {
      'name': 'Nasi Goreng Gila (1 piring)',
      'protein': 20.0,
      'calories': 510.0,
      'carbs': 64.0,
      'fat': 17.0,
      'fiber': 1.8,
      'sugar': 3.0,
      'salt': 1.60
    },
    {
      'name': 'Mie Celor (1 mangkuk)',
      'protein': 22.0,
      'calories': 450.0,
      'carbs': 55.0,
      'fat': 14.0,
      'fiber': 2.0,
      'sugar': 3.5,
      'salt': 1.30
    },
    {
      'name': 'Mie Kocok Bandung (1 mangkuk)',
      'protein': 18.0,
      'calories': 390.0,
      'carbs': 50.0,
      'fat': 12.0,
      'fiber': 1.5,
      'sugar': 2.0,
      'salt': 1.20
    },
    {
      'name': 'Mie Aceh Goreng/Rebus (1 mangkuk)',
      'protein': 20.0,
      'calories': 480.0,
      'carbs': 55.0,
      'fat': 18.0,
      'fiber': 2.5,
      'sugar': 3.0,
      'salt': 1.50
    },
    {
      'name': 'Mie Tiaw Pontianak (1 mangkuk)',
      'protein': 16.0,
      'calories': 440.0,
      'carbs': 58.0,
      'fat': 14.0,
      'fiber': 1.5,
      'sugar': 2.5,
      'salt': 1.30
    },
    {
      'name': 'Soun Goreng (1 piring)',
      'protein': 6.0,
      'calories': 280.0,
      'carbs': 52.0,
      'fat': 7.0,
      'fiber': 1.0,
      'sugar': 2.0,
      'salt': 0.90
    },
    {
      'name': 'Macaroni Schotel (1 loyang kecil)',
      'protein': 14.0,
      'calories': 380.0,
      'carbs': 48.0,
      'fat': 14.0,
      'fiber': 1.5,
      'sugar': 5.0,
      'salt': 0.85
    },
    {
      'name': 'Lasagna (1 porsi)',
      'protein': 20.0,
      'calories': 430.0,
      'carbs': 42.0,
      'fat': 18.0,
      'fiber': 2.0,
      'sugar': 6.0,
      'salt': 0.95
    },
    {
      'name': 'Pizza Slice (1 slice)',
      'protein': 12.0,
      'calories': 285.0,
      'carbs': 34.0,
      'fat': 10.0,
      'fiber': 1.8,
      'sugar': 3.5,
      'salt': 0.70
    },
    {
      'name': 'Burger Sapi (1 buah)',
      'protein': 25.0,
      'calories': 490.0,
      'carbs': 38.0,
      'fat': 24.0,
      'fiber': 2.5,
      'sugar': 7.0,
      'salt': 1.10
    },
    {
      'name': 'Hotdog (1 buah)',
      'protein': 12.0,
      'calories': 320.0,
      'carbs': 25.0,
      'fat': 18.0,
      'fiber': 1.2,
      'sugar': 4.0,
      'salt': 1.00
    },
    {
      'name': 'Kebab Turki (1 buah)',
      'protein': 18.0,
      'calories': 380.0,
      'carbs': 35.0,
      'fat': 17.0,
      'fiber': 2.5,
      'sugar': 4.5,
      'salt': 1.10
    },
    {
      'name': 'Sandwich Gandum (1 buah)',
      'protein': 14.0,
      'calories': 280.0,
      'carbs': 30.0,
      'fat': 10.0,
      'fiber': 3.5,
      'sugar': 4.0,
      'salt': 0.75
    },
    {
      'name': 'Garlic Bread (2 slice)',
      'protein': 4.5,
      'calories': 210.0,
      'carbs': 26.0,
      'fat': 9.5,
      'fiber': 1.0,
      'sugar': 1.5,
      'salt': 0.50
    },
    {
      'name': 'Bubur Ketan Hitam (1 mangkuk)',
      'protein': 4.5,
      'calories': 280.0,
      'carbs': 58.0,
      'fat': 4.0,
      'fiber': 2.5,
      'sugar': 18.0,
      'salt': 0.10
    },
    {
      'name': 'Bubur Sumsum (1 mangkuk)',
      'protein': 3.5,
      'calories': 240.0,
      'carbs': 48.0,
      'fat': 4.5,
      'fiber': 0.5,
      'sugar': 15.0,
      'salt': 0.08
    },
    {
      'name': 'Bubur Kacang Hijau (1 mangkuk)',
      'protein': 8.5,
      'calories': 260.0,
      'carbs': 50.0,
      'fat': 3.5,
      'fiber': 5.0,
      'sugar': 16.0,
      'salt': 0.12
    },
    {
      'name': 'Bubur Manado Tinutuan (1 mangkuk)',
      'protein': 5.5,
      'calories': 200.0,
      'carbs': 38.0,
      'fat': 3.0,
      'fiber': 3.5,
      'sugar': 2.5,
      'salt': 0.45
    },
    {
      'name': 'Gnocchi (1 porsi)',
      'protein': 7.0,
      'calories': 280.0,
      'carbs': 58.0,
      'fat': 2.5,
      'fiber': 2.0,
      'sugar': 1.5,
      'salt': 0.35
    },
    {
      'name': 'Ramen (1 mangkuk)',
      'protein': 22.0,
      'calories': 550.0,
      'carbs': 70.0,
      'fat': 18.0,
      'fiber': 3.0,
      'sugar': 4.0,
      'salt': 1.90
    },
    {
      'name': 'Udon (1 mangkuk)',
      'protein': 16.0,
      'calories': 420.0,
      'carbs': 80.0,
      'fat': 4.5,
      'fiber': 3.5,
      'sugar': 3.5,
      'salt': 1.40
    },
    {
      'name': 'Soba (1 porsi)',
      'protein': 12.0,
      'calories': 340.0,
      'carbs': 68.0,
      'fat': 1.5,
      'fiber': 2.5,
      'sugar': 1.0,
      'salt': 0.20
    },
    {
      'name': 'Quinoa (1 porsi matang)',
      'protein': 8.1,
      'calories': 222.0,
      'carbs': 39.0,
      'fat': 3.5,
      'fiber': 5.2,
      'sugar': 1.6,
      'salt': 0.01
    },
    {
      'name': 'Couscous (1 porsi matang)',
      'protein': 6.0,
      'calories': 176.0,
      'carbs': 36.5,
      'fat': 0.3,
      'fiber': 2.2,
      'sugar': 0.2,
      'salt': 0.01
    },

    // B2. Lauk Pauk (baru)
    {
      'name': 'Ayam Pop (1 potong)',
      'protein': 28.0,
      'calories': 220.0,
      'carbs': 2.0,
      'fat': 10.0,
      'fiber': 0.0,
      'sugar': 0.5,
      'salt': 0.45
    },
    {
      'name': 'Ayam Kalasan (1 potong)',
      'protein': 27.0,
      'calories': 310.0,
      'carbs': 8.0,
      'fat': 18.0,
      'fiber': 0.5,
      'sugar': 4.0,
      'salt': 0.55
    },
    {
      'name': 'Ayam Betutu (1 potong)',
      'protein': 35.0,
      'calories': 390.0,
      'carbs': 6.0,
      'fat': 24.0,
      'fiber': 1.0,
      'sugar': 2.5,
      'salt': 0.90
    },
    {
      'name': 'Ayam Rica-Rica (1 potong)',
      'protein': 28.0,
      'calories': 320.0,
      'carbs': 5.0,
      'fat': 20.0,
      'fiber': 1.5,
      'sugar': 2.0,
      'salt': 0.85
    },
    {
      'name': 'Ayam Kungpao (1 porsi)',
      'protein': 30.0,
      'calories': 350.0,
      'carbs': 12.0,
      'fat': 18.0,
      'fiber': 2.0,
      'sugar': 6.0,
      'salt': 1.20
    },
    {
      'name': 'Teriyaki Chicken (1 potong)',
      'protein': 28.0,
      'calories': 290.0,
      'carbs': 10.0,
      'fat': 14.0,
      'fiber': 0.5,
      'sugar': 8.0,
      'salt': 1.00
    },
    {
      'name': 'Chicken Katsu (1 potong)',
      'protein': 26.0,
      'calories': 350.0,
      'carbs': 18.0,
      'fat': 18.0,
      'fiber': 1.0,
      'sugar': 2.0,
      'salt': 0.80
    },
    {
      'name': 'Steak Sirloin (1 potong)',
      'protein': 42.0,
      'calories': 440.0,
      'carbs': 0.0,
      'fat': 28.0,
      'fiber': 0.0,
      'sugar': 0.0,
      'salt': 0.35
    },
    {
      'name': 'Steak Tenderloin (1 potong)',
      'protein': 44.0,
      'calories': 380.0,
      'carbs': 0.0,
      'fat': 22.0,
      'fiber': 0.0,
      'sugar': 0.0,
      'salt': 0.30
    },
    {
      'name': 'Sei Sapi (1 porsi)',
      'protein': 32.0,
      'calories': 310.0,
      'carbs': 1.0,
      'fat': 19.0,
      'fiber': 0.0,
      'sugar': 0.5,
      'salt': 0.60
    },
    {
      'name': 'Semur Daging (1 porsi)',
      'protein': 28.0,
      'calories': 320.0,
      'carbs': 12.0,
      'fat': 17.0,
      'fiber': 0.5,
      'sugar': 8.0,
      'salt': 0.95
    },
    {
      'name': 'Sop Konro (1 mangkuk)',
      'protein': 36.0,
      'calories': 480.0,
      'carbs': 8.0,
      'fat': 32.0,
      'fiber': 1.0,
      'sugar': 3.0,
      'salt': 1.30
    },
    {
      'name': 'Tongseng Sapi (1 porsi)',
      'protein': 30.0,
      'calories': 410.0,
      'carbs': 15.0,
      'fat': 25.0,
      'fiber': 2.0,
      'sugar': 5.0,
      'salt': 1.10
    },
    {
      'name': 'Gulai Kambing (1 porsi)',
      'protein': 32.0,
      'calories': 450.0,
      'carbs': 8.0,
      'fat': 32.0,
      'fiber': 1.5,
      'sugar': 2.5,
      'salt': 1.00
    },
    {
      'name': 'Sate Maranggi (5 tusuk)',
      'protein': 24.0,
      'calories': 290.0,
      'carbs': 10.0,
      'fat': 16.0,
      'fiber': 0.5,
      'sugar': 5.0,
      'salt': 0.65
    },
    {
      'name': 'Sate Taichan (5 tusuk)',
      'protein': 22.0,
      'calories': 220.0,
      'carbs': 3.0,
      'fat': 13.0,
      'fiber': 0.5,
      'sugar': 1.0,
      'salt': 0.55
    },
    {
      'name': 'Ikan Dorang Goreng (1 ekor kecil)',
      'protein': 28.0,
      'calories': 240.0,
      'carbs': 3.0,
      'fat': 12.0,
      'fiber': 0.0,
      'sugar': 0.5,
      'salt': 0.50
    },
    {
      'name': 'Ikan Gurame Asam Manis (1 porsi)',
      'protein': 30.0,
      'calories': 310.0,
      'carbs': 14.0,
      'fat': 14.0,
      'fiber': 1.0,
      'sugar': 8.0,
      'salt': 0.85
    },
    {
      'name': 'Ikan Patin Kuning (1 porsi)',
      'protein': 28.0,
      'calories': 280.0,
      'carbs': 6.0,
      'fat': 15.0,
      'fiber': 0.5,
      'sugar': 2.0,
      'salt': 0.70
    },
    {
      'name': 'Ikan Bandeng Presto (1 potong)',
      'protein': 26.0,
      'calories': 260.0,
      'carbs': 2.0,
      'fat': 16.0,
      'fiber': 0.0,
      'sugar': 0.5,
      'salt': 0.55
    },
    {
      'name': 'Otak-Otak Bakar (2 buah)',
      'protein': 14.0,
      'calories': 180.0,
      'carbs': 12.0,
      'fat': 8.0,
      'fiber': 1.0,
      'sugar': 2.0,
      'salt': 0.70
    },
    {
      'name': 'Tekwan (1 mangkuk)',
      'protein': 20.0,
      'calories': 280.0,
      'carbs': 28.0,
      'fat': 9.0,
      'fiber': 1.0,
      'sugar': 2.5,
      'salt': 1.10
    },
    {
      'name': 'Dimsum Siomay (3 buah)',
      'protein': 12.0,
      'calories': 190.0,
      'carbs': 18.0,
      'fat': 8.0,
      'fiber': 1.0,
      'sugar': 1.5,
      'salt': 0.60
    },
    {
      'name': 'Dimsum Hakau (3 buah)',
      'protein': 10.0,
      'calories': 160.0,
      'carbs': 20.0,
      'fat': 5.0,
      'fiber': 0.8,
      'sugar': 1.0,
      'salt': 0.55
    },
    {
      'name': 'Ceker Pedas Mercon (5-6 ceker)',
      'protein': 16.0,
      'calories': 210.0,
      'carbs': 5.0,
      'fat': 14.0,
      'fiber': 0.5,
      'sugar': 2.0,
      'salt': 0.80
    },
    {
      'name': 'Ati Ampela Balado (1 porsi)',
      'protein': 22.0,
      'calories': 220.0,
      'carbs': 5.0,
      'fat': 12.0,
      'fiber': 0.5,
      'sugar': 2.0,
      'salt': 0.75
    },
    {
      'name': 'Paru Goreng (1 porsi)',
      'protein': 24.0,
      'calories': 230.0,
      'carbs': 4.0,
      'fat': 13.0,
      'fiber': 0.0,
      'sugar': 0.5,
      'salt': 0.50
    },
    {
      'name': 'Babat Gongso (1 porsi)',
      'protein': 22.0,
      'calories': 240.0,
      'carbs': 8.0,
      'fat': 14.0,
      'fiber': 1.0,
      'sugar': 3.0,
      'salt': 0.90
    },
    {
      'name': 'Kikil Tumis Cabe Ijo (1 porsi)',
      'protein': 20.0,
      'calories': 250.0,
      'carbs': 6.0,
      'fat': 16.0,
      'fiber': 0.5,
      'sugar': 2.0,
      'salt': 0.85
    },
    {
      'name': 'Lidah Sapi Panggang (1 porsi)',
      'protein': 28.0,
      'calories': 320.0,
      'carbs': 2.0,
      'fat': 22.0,
      'fiber': 0.0,
      'sugar': 0.5,
      'salt': 0.55
    },
    {
      'name': 'Puyuh Goreng (1 ekor)',
      'protein': 18.0,
      'calories': 190.0,
      'carbs': 2.0,
      'fat': 12.0,
      'fiber': 0.0,
      'sugar': 0.5,
      'salt': 0.45
    },
    {
      'name': 'Bebek Goreng (1/4 ekor)',
      'protein': 36.0,
      'calories': 480.0,
      'carbs': 4.0,
      'fat': 34.0,
      'fiber': 0.0,
      'sugar': 1.0,
      'salt': 0.90
    },
    {
      'name': 'Bebek Peking (1 porsi)',
      'protein': 30.0,
      'calories': 420.0,
      'carbs': 6.0,
      'fat': 30.0,
      'fiber': 0.0,
      'sugar': 3.0,
      'salt': 1.10
    },
    {
      'name': 'Telur Balado (1 butir+bumbu)',
      'protein': 10.5,
      'calories': 180.0,
      'carbs': 4.0,
      'fat': 13.0,
      'fiber': 0.5,
      'sugar': 1.5,
      'salt': 0.55
    },
    {
      'name': 'Telur Bumbu Bali (1 butir+bumbu)',
      'protein': 10.5,
      'calories': 185.0,
      'carbs': 5.0,
      'fat': 13.5,
      'fiber': 0.8,
      'sugar': 2.0,
      'salt': 0.60
    },
    {
      'name': 'Orak Arik Telur Sayur (1 porsi)',
      'protein': 12.0,
      'calories': 200.0,
      'carbs': 6.0,
      'fat': 14.0,
      'fiber': 1.5,
      'sugar': 2.0,
      'salt': 0.55
    },
    {
      'name': 'Tahu Campur (1 mangkuk)',
      'protein': 18.0,
      'calories': 340.0,
      'carbs': 28.0,
      'fat': 16.0,
      'fiber': 2.0,
      'sugar': 3.0,
      'salt': 1.20
    },
    {
      'name': 'Tahu Tek (1 porsi)',
      'protein': 15.0,
      'calories': 310.0,
      'carbs': 28.0,
      'fat': 15.0,
      'fiber': 2.5,
      'sugar': 4.0,
      'salt': 1.10
    },
    {
      'name': 'Tahu Bulat (4 buah)',
      'protein': 10.0,
      'calories': 160.0,
      'carbs': 6.0,
      'fat': 10.0,
      'fiber': 0.5,
      'sugar': 0.5,
      'salt': 0.30
    },
    {
      'name': 'Tahu Sumedang (4 buah)',
      'protein': 9.5,
      'calories': 150.0,
      'carbs': 7.0,
      'fat': 9.0,
      'fiber': 0.5,
      'sugar': 0.5,
      'salt': 0.30
    },
    {
      'name': 'Tempe Kemul (2-3 potong)',
      'protein': 12.0,
      'calories': 210.0,
      'carbs': 18.0,
      'fat': 10.0,
      'fiber': 4.0,
      'sugar': 1.0,
      'salt': 0.35
    },
    {
      'name': 'Tempe Mendoan (2 lembar)',
      'protein': 11.0,
      'calories': 220.0,
      'carbs': 20.0,
      'fat': 11.0,
      'fiber': 3.5,
      'sugar': 1.0,
      'salt': 0.40
    },
    {
      'name': 'Nugget Ikan (4-5 buah)',
      'protein': 14.0,
      'calories': 220.0,
      'carbs': 18.0,
      'fat': 10.0,
      'fiber': 1.0,
      'sugar': 2.0,
      'salt': 0.65
    },
    {
      'name': 'Fish and Chips (1 porsi)',
      'protein': 28.0,
      'calories': 530.0,
      'carbs': 50.0,
      'fat': 22.0,
      'fiber': 3.0,
      'sugar': 3.0,
      'salt': 1.20
    },
    {
      'name': 'Lobster Saus Mentega (1 porsi)',
      'protein': 36.0,
      'calories': 380.0,
      'carbs': 5.0,
      'fat': 22.0,
      'fiber': 0.0,
      'sugar': 2.0,
      'salt': 1.50
    },
    {
      'name': 'Kerang Bambu (1 porsi)',
      'protein': 20.0,
      'calories': 140.0,
      'carbs': 5.0,
      'fat': 4.0,
      'fiber': 0.0,
      'sugar': 0.5,
      'salt': 0.90
    },
    {
      'name': 'Scallop Panggang (4-5 buah)',
      'protein': 22.0,
      'calories': 150.0,
      'carbs': 5.0,
      'fat': 3.5,
      'fiber': 0.0,
      'sugar': 1.0,
      'salt': 0.55
    },
    {
      'name': 'Sarden Kaleng (1/2 kaleng kecil)',
      'protein': 20.0,
      'calories': 180.0,
      'carbs': 2.0,
      'fat': 10.0,
      'fiber': 0.0,
      'sugar': 0.5,
      'salt': 0.80
    },
    {
      'name': 'Abon Sapi (2 sdm)',
      'protein': 12.0,
      'calories': 140.0,
      'carbs': 8.0,
      'fat': 7.0,
      'fiber': 0.0,
      'sugar': 4.0,
      'salt': 0.45
    },
    {
      'name': 'Dendeng Sayur Analog Protein (1 porsi)',
      'protein': 10.0,
      'calories': 200.0,
      'carbs': 18.0,
      'fat': 9.0,
      'fiber': 4.5,
      'sugar': 2.0,
      'salt': 0.55
    },

    // B3. Sayur & Masakan Berkuah (baru)
    {
      'name': 'Tumis Genjer (1 porsi)',
      'protein': 3.0,
      'calories': 80.0,
      'carbs': 8.0,
      'fat': 4.0,
      'fiber': 2.5,
      'sugar': 1.0,
      'salt': 0.40
    },
    {
      'name': 'Tumis Daun Pepaya (1 porsi)',
      'protein': 3.5,
      'calories': 90.0,
      'carbs': 7.0,
      'fat': 5.0,
      'fiber': 3.0,
      'sugar': 1.5,
      'salt': 0.45
    },
    {
      'name': 'Tumis Rebung (1 porsi)',
      'protein': 2.5,
      'calories': 85.0,
      'carbs': 8.0,
      'fat': 4.5,
      'fiber': 3.5,
      'sugar': 1.0,
      'salt': 0.50
    },
    {
      'name': 'Tumis Labu Siam (1 porsi)',
      'protein': 2.0,
      'calories': 70.0,
      'carbs': 8.0,
      'fat': 3.5,
      'fiber': 2.0,
      'sugar': 2.5,
      'salt': 0.35
    },
    {
      'name': 'Sayur Bobor Bayam (1 mangkuk)',
      'protein': 5.0,
      'calories': 130.0,
      'carbs': 12.0,
      'fat': 6.0,
      'fiber': 3.0,
      'sugar': 3.0,
      'salt': 0.30
    },
    {
      'name': 'Sayur Gabus Pucung (1 mangkuk)',
      'protein': 20.0,
      'calories': 220.0,
      'carbs': 8.0,
      'fat': 12.0,
      'fiber': 1.5,
      'sugar': 2.0,
      'salt': 0.80
    },
    {
      'name': 'Brongkos (1 mangkuk)',
      'protein': 14.0,
      'calories': 280.0,
      'carbs': 22.0,
      'fat': 14.0,
      'fiber': 5.0,
      'sugar': 3.0,
      'salt': 0.60
    },
    {
      'name': 'Trancam (1 porsi)',
      'protein': 3.5,
      'calories': 90.0,
      'carbs': 8.0,
      'fat': 5.0,
      'fiber': 3.0,
      'sugar': 3.0,
      'salt': 0.25
    },
    {
      'name': 'Urap-Urap Sayur (1 porsi)',
      'protein': 4.5,
      'calories': 150.0,
      'carbs': 14.0,
      'fat': 9.0,
      'fiber': 4.5,
      'sugar': 3.5,
      'salt': 0.20
    },
    {
      'name': 'Asinan Betawi (1 porsi)',
      'protein': 4.0,
      'calories': 160.0,
      'carbs': 22.0,
      'fat': 7.0,
      'fiber': 3.0,
      'sugar': 10.0,
      'salt': 0.80
    },
    {
      'name': 'Asinan Bogor (1 porsi)',
      'protein': 3.0,
      'calories': 140.0,
      'carbs': 24.0,
      'fat': 4.5,
      'fiber': 2.5,
      'sugar': 14.0,
      'salt': 0.55
    },
    {
      'name': 'Salad Caesar (1 porsi)',
      'protein': 8.0,
      'calories': 220.0,
      'carbs': 12.0,
      'fat': 16.0,
      'fiber': 3.0,
      'sugar': 4.0,
      'salt': 0.65
    },
    {
      'name': 'Coleslaw (1 porsi)',
      'protein': 1.5,
      'calories': 150.0,
      'carbs': 14.0,
      'fat': 9.5,
      'fiber': 2.0,
      'sugar': 10.0,
      'salt': 0.35
    },
    {
      'name': 'Mashed Pumpkin (1 porsi)',
      'protein': 2.5,
      'calories': 110.0,
      'carbs': 22.0,
      'fat': 2.5,
      'fiber': 2.5,
      'sugar': 6.0,
      'salt': 0.20
    },
    {
      'name': 'Sup Asparagus Kepiting (1 mangkuk)',
      'protein': 12.0,
      'calories': 180.0,
      'carbs': 14.0,
      'fat': 8.0,
      'fiber': 2.0,
      'sugar': 3.0,
      'salt': 0.90
    },
    {
      'name': 'Sup Jamur Kuping (1 mangkuk)',
      'protein': 5.0,
      'calories': 120.0,
      'carbs': 14.0,
      'fat': 4.0,
      'fiber': 4.0,
      'sugar': 2.0,
      'salt': 0.70
    },
    {
      'name': 'Sup Tomat (1 mangkuk)',
      'protein': 3.5,
      'calories': 110.0,
      'carbs': 16.0,
      'fat': 3.5,
      'fiber': 2.5,
      'sugar': 8.0,
      'salt': 0.55
    },
    {
      'name': 'Tom Yum Kung (1 mangkuk)',
      'protein': 16.0,
      'calories': 190.0,
      'carbs': 10.0,
      'fat': 9.0,
      'fiber': 1.5,
      'sugar': 3.0,
      'salt': 1.50
    },
    {
      'name': 'Laksa Penyet (1 mangkuk)',
      'protein': 22.0,
      'calories': 520.0,
      'carbs': 58.0,
      'fat': 22.0,
      'fiber': 3.0,
      'sugar': 4.0,
      'salt': 1.60
    },
    {
      'name': 'Soto Lamongan (1 mangkuk)',
      'protein': 24.0,
      'calories': 320.0,
      'carbs': 22.0,
      'fat': 14.0,
      'fiber': 1.5,
      'sugar': 3.0,
      'salt': 1.20
    },
    {
      'name': 'Soto Kudus (1 mangkuk)',
      'protein': 20.0,
      'calories': 280.0,
      'carbs': 20.0,
      'fat': 12.0,
      'fiber': 1.5,
      'sugar': 2.5,
      'salt': 1.10
    },
    {
      'name': 'Soto Banjar (1 mangkuk)',
      'protein': 22.0,
      'calories': 310.0,
      'carbs': 22.0,
      'fat': 13.0,
      'fiber': 1.5,
      'sugar': 2.5,
      'salt': 1.15
    },
    {
      'name': 'Empal Gentong (1 mangkuk)',
      'protein': 30.0,
      'calories': 430.0,
      'carbs': 12.0,
      'fat': 28.0,
      'fiber': 1.0,
      'sugar': 3.0,
      'salt': 1.40
    },
    {
      'name': 'Pallubasa (1 mangkuk)',
      'protein': 32.0,
      'calories': 450.0,
      'carbs': 10.0,
      'fat': 30.0,
      'fiber': 0.5,
      'sugar': 2.5,
      'salt': 1.30
    },
    {
      'name': 'Coto Makassar (1 mangkuk)',
      'protein': 30.0,
      'calories': 420.0,
      'carbs': 8.0,
      'fat': 28.0,
      'fiber': 0.5,
      'sugar': 2.0,
      'salt': 1.30
    },
    {
      'name': 'Kimchi Jjigae (1 mangkuk)',
      'protein': 20.0,
      'calories': 280.0,
      'carbs': 14.0,
      'fat': 14.0,
      'fiber': 3.5,
      'sugar': 4.0,
      'salt': 2.00
    },
    {
      'name': 'Bok Choy Bawang Putih (1 porsi)',
      'protein': 3.5,
      'calories': 80.0,
      'carbs': 6.0,
      'fat': 4.5,
      'fiber': 2.0,
      'sugar': 1.5,
      'salt': 0.45
    },
    {
      'name': 'Tumis Baby Corn (1 porsi)',
      'protein': 3.0,
      'calories': 100.0,
      'carbs': 12.0,
      'fat': 4.5,
      'fiber': 2.5,
      'sugar': 3.0,
      'salt': 0.50
    },
    {
      'name': 'Terong Raos (1 porsi)',
      'protein': 3.5,
      'calories': 120.0,
      'carbs': 10.0,
      'fat': 7.0,
      'fiber': 3.0,
      'sugar': 3.5,
      'salt': 0.50
    },
    {
      'name': 'Perkedel Kentang (2 buah)',
      'protein': 4.5,
      'calories': 195.0,
      'carbs': 22.0,
      'fat': 9.5,
      'fiber': 2.0,
      'sugar': 2.0,
      'salt': 0.45
    },
    {
      'name': 'Perkedel Jagung Bakwan (2-3 buah)',
      'protein': 4.5,
      'calories': 185.0,
      'carbs': 24.0,
      'fat': 8.5,
      'fiber': 2.5,
      'sugar': 3.5,
      'salt': 0.40
    },
    {
      'name': 'Tumis Pare Udang Rebon (1 porsi)',
      'protein': 8.0,
      'calories': 130.0,
      'carbs': 8.0,
      'fat': 7.5,
      'fiber': 2.5,
      'sugar': 2.0,
      'salt': 0.70
    },
    {
      'name': 'Sayur Bening Kelor (1 mangkuk)',
      'protein': 4.0,
      'calories': 80.0,
      'carbs': 8.0,
      'fat': 1.5,
      'fiber': 3.5,
      'sugar': 2.0,
      'salt': 0.20
    },
    {
      'name': 'Kuluban (1 porsi)',
      'protein': 4.0,
      'calories': 140.0,
      'carbs': 12.0,
      'fat': 8.0,
      'fiber': 4.0,
      'sugar': 3.0,
      'salt': 0.20
    },
    {
      'name': 'Lawar Bali (1 porsi)',
      'protein': 12.0,
      'calories': 200.0,
      'carbs': 8.0,
      'fat': 13.0,
      'fiber': 2.5,
      'sugar': 2.0,
      'salt': 0.80
    },
    {
      'name': 'Sayur Putut (1 mangkuk)',
      'protein': 5.0,
      'calories': 130.0,
      'carbs': 14.0,
      'fat': 5.0,
      'fiber': 4.5,
      'sugar': 2.5,
      'salt': 0.35
    },
    {
      'name': 'Tumis Pakis (1 porsi)',
      'protein': 3.0,
      'calories': 75.0,
      'carbs': 7.0,
      'fat': 4.0,
      'fiber': 3.0,
      'sugar': 1.0,
      'salt': 0.40
    },
    {
      'name': 'Sup Kimlo Lengkap (1 mangkuk)',
      'protein': 10.0,
      'calories': 160.0,
      'carbs': 16.0,
      'fat': 5.0,
      'fiber': 3.0,
      'sugar': 3.0,
      'salt': 0.85
    },
    {
      'name': 'Brambang Asem (1 porsi)',
      'protein': 2.5,
      'calories': 90.0,
      'carbs': 12.0,
      'fat': 4.0,
      'fiber': 2.5,
      'sugar': 4.0,
      'salt': 0.30
    },
    {
      'name': 'Lalapan Kol Goreng (1 porsi)',
      'protein': 2.0,
      'calories': 120.0,
      'carbs': 8.0,
      'fat': 8.5,
      'fiber': 1.5,
      'sugar': 2.0,
      'salt': 0.30
    },

    // B4. Buah & Olahan Buah (baru)
    {
      'name': 'Buah Persik/Peach (1 buah)',
      'protein': 1.4,
      'calories': 57.0,
      'carbs': 14.0,
      'fat': 0.4,
      'fiber': 2.3,
      'sugar': 12.4,
      'salt': 0.00
    },
    {
      'name': 'Buah Plum (1 buah)',
      'protein': 0.5,
      'calories': 30.0,
      'carbs': 7.5,
      'fat': 0.2,
      'fiber': 0.9,
      'sugar': 6.6,
      'salt': 0.00
    },
    {
      'name': 'Buah Zaitun Olahan (5-6 buah)',
      'protein': 0.3,
      'calories': 42.0,
      'carbs': 1.1,
      'fat': 4.0,
      'fiber': 0.6,
      'sugar': 0.0,
      'salt': 0.50
    },
    {
      'name': 'Buah Tin Segar (1 buah)',
      'protein': 0.4,
      'calories': 37.0,
      'carbs': 9.6,
      'fat': 0.1,
      'fiber': 1.5,
      'sugar': 8.2,
      'salt': 0.00
    },
    {
      'name': 'Buah Leci (8-10 buah)',
      'protein': 0.8,
      'calories': 66.0,
      'carbs': 16.5,
      'fat': 0.4,
      'fiber': 1.3,
      'sugar': 15.2,
      'salt': 0.00
    },
    {
      'name': 'Buah Matoa (5-6 buah)',
      'protein': 0.5,
      'calories': 60.0,
      'carbs': 15.0,
      'fat': 0.3,
      'fiber': 1.5,
      'sugar': 12.0,
      'salt': 0.00
    },
    {
      'name': 'Buah Kesemek (1 buah)',
      'protein': 1.0,
      'calories': 118.0,
      'carbs': 31.2,
      'fat': 0.3,
      'fiber': 6.0,
      'sugar': 21.0,
      'salt': 0.00
    },
    {
      'name': 'Buah Bidara (5-6 buah)',
      'protein': 1.2,
      'calories': 79.0,
      'carbs': 20.2,
      'fat': 0.2,
      'fiber': 0.6,
      'sugar': 10.0,
      'salt': 0.00
    },
    {
      'name': 'Buah Raspberry (1 cangkir)',
      'protein': 1.5,
      'calories': 64.0,
      'carbs': 14.7,
      'fat': 0.8,
      'fiber': 8.0,
      'sugar': 5.4,
      'salt': 0.00
    },
    {
      'name': 'Buah Blackberry (1 cangkir)',
      'protein': 2.0,
      'calories': 62.0,
      'carbs': 13.8,
      'fat': 0.7,
      'fiber': 7.6,
      'sugar': 7.0,
      'salt': 0.00
    },
    {
      'name': 'Buah Cranberry Kering (3 sdm)',
      'protein': 0.1,
      'calories': 123.0,
      'carbs': 33.0,
      'fat': 0.5,
      'fiber': 2.0,
      'sugar': 26.0,
      'salt': 0.01
    },
    {
      'name': 'Buah Ceri (100g)',
      'protein': 1.1,
      'calories': 63.0,
      'carbs': 16.0,
      'fat': 0.2,
      'fiber': 2.1,
      'sugar': 12.8,
      'salt': 0.00
    },
    {
      'name': 'Buah Persimmon (1 buah)',
      'protein': 1.0,
      'calories': 118.0,
      'carbs': 31.2,
      'fat': 0.3,
      'fiber': 6.0,
      'sugar': 21.0,
      'salt': 0.00
    },
    {
      'name': 'Buah Pomelo Jeruk Bali (2 irisan)',
      'protein': 1.6,
      'calories': 76.0,
      'carbs': 19.0,
      'fat': 0.1,
      'fiber': 1.9,
      'sugar': 16.0,
      'salt': 0.00
    },
    {
      'name': 'Manisan Mangga (1 porsi kecil)',
      'protein': 0.5,
      'calories': 155.0,
      'carbs': 40.0,
      'fat': 0.2,
      'fiber': 1.0,
      'sugar': 36.0,
      'salt': 0.15
    },
    {
      'name': 'Manisan Pala (1 porsi kecil)',
      'protein': 0.3,
      'calories': 90.0,
      'carbs': 23.0,
      'fat': 0.1,
      'fiber': 0.5,
      'sugar': 20.0,
      'salt': 0.10
    },
    {
      'name': 'Asinan Buah Campur (1 porsi)',
      'protein': 2.0,
      'calories': 180.0,
      'carbs': 42.0,
      'fat': 2.0,
      'fiber': 3.0,
      'sugar': 28.0,
      'salt': 0.60
    },
    {
      'name': 'Es Buah dengan Sirup (1 gelas)',
      'protein': 1.5,
      'calories': 170.0,
      'carbs': 42.0,
      'fat': 1.0,
      'fiber': 2.5,
      'sugar': 35.0,
      'salt': 0.05
    },
    {
      'name': 'Sop Buah dengan Susu (1 mangkuk)',
      'protein': 4.0,
      'calories': 220.0,
      'carbs': 45.0,
      'fat': 4.0,
      'fiber': 3.0,
      'sugar': 35.0,
      'salt': 0.08
    },
    {
      'name': 'Jus Alpukat dengan Cokelat (1 gelas)',
      'protein': 5.0,
      'calories': 380.0,
      'carbs': 35.0,
      'fat': 25.0,
      'fiber': 6.5,
      'sugar': 22.0,
      'salt': 0.10
    },
    {
      'name': 'Jus Jeruk Murni (1 gelas)',
      'protein': 1.7,
      'calories': 112.0,
      'carbs': 26.0,
      'fat': 0.5,
      'fiber': 0.5,
      'sugar': 20.8,
      'salt': 0.00
    },
    {
      'name': 'Jus Mangga (1 gelas)',
      'protein': 1.0,
      'calories': 135.0,
      'carbs': 34.0,
      'fat': 0.3,
      'fiber': 1.0,
      'sugar': 28.0,
      'salt': 0.01
    },
    {
      'name': 'Jus Wortel Tomat (1 gelas)',
      'protein': 2.0,
      'calories': 95.0,
      'carbs': 22.0,
      'fat': 0.5,
      'fiber': 2.5,
      'sugar': 12.0,
      'salt': 0.05
    },
    {
      'name': 'Jus Jambu Merah (1 gelas)',
      'protein': 2.5,
      'calories': 120.0,
      'carbs': 28.0,
      'fat': 0.8,
      'fiber': 3.0,
      'sugar': 18.0,
      'salt': 0.02
    },
    {
      'name': 'Jus Sirsak (1 gelas)',
      'protein': 2.0,
      'calories': 140.0,
      'carbs': 35.0,
      'fat': 0.5,
      'fiber': 2.5,
      'sugar': 22.0,
      'salt': 0.01
    },
    {
      'name': 'Jus Belimbing (1 gelas)',
      'protein': 1.5,
      'calories': 90.0,
      'carbs': 21.0,
      'fat': 0.3,
      'fiber': 2.5,
      'sugar': 12.0,
      'salt': 0.02
    },
    {
      'name': 'Smoothie Bowl Berry/Naga (1 mangkuk)',
      'protein': 6.0,
      'calories': 290.0,
      'carbs': 55.0,
      'fat': 6.0,
      'fiber': 7.0,
      'sugar': 28.0,
      'salt': 0.10
    },
    {
      'name': 'Pisang Epe (1 buah)',
      'protein': 2.5,
      'calories': 260.0,
      'carbs': 52.0,
      'fat': 7.0,
      'fiber': 2.5,
      'sugar': 28.0,
      'salt': 0.10
    },

    // B5. Minuman (baru)
    {
      'name': 'Air Mineral (1 gelas)',
      'protein': 0.0,
      'calories': 0.0,
      'carbs': 0.0,
      'fat': 0.0,
      'fiber': 0.0,
      'sugar': 0.0,
      'salt': 0.00
    },
    {
      'name': 'Teh Tawar (1 gelas)',
      'protein': 0.0,
      'calories': 2.0,
      'carbs': 0.3,
      'fat': 0.0,
      'fiber': 0.0,
      'sugar': 0.0,
      'salt': 0.00
    },
    {
      'name': 'Teh Manis (1 gelas)',
      'protein': 0.0,
      'calories': 80.0,
      'carbs': 20.0,
      'fat': 0.0,
      'fiber': 0.0,
      'sugar': 20.0,
      'salt': 0.00
    },
    {
      'name': 'Teh Tarik (1 gelas)',
      'protein': 3.5,
      'calories': 130.0,
      'carbs': 22.0,
      'fat': 4.0,
      'fiber': 0.0,
      'sugar': 20.0,
      'salt': 0.08
    },
    {
      'name': 'Es Teh Lemon (1 gelas)',
      'protein': 0.3,
      'calories': 95.0,
      'carbs': 24.0,
      'fat': 0.0,
      'fiber': 0.0,
      'sugar': 22.0,
      'salt': 0.01
    },
    {
      'name': 'Es Campur (1 gelas)',
      'protein': 3.5,
      'calories': 280.0,
      'carbs': 58.0,
      'fat': 6.0,
      'fiber': 2.5,
      'sugar': 40.0,
      'salt': 0.10
    },
    {
      'name': 'Es Teler (1 gelas)',
      'protein': 4.0,
      'calories': 300.0,
      'carbs': 55.0,
      'fat': 10.0,
      'fiber': 3.0,
      'sugar': 38.0,
      'salt': 0.08
    },
    {
      'name': 'Es Pisang Ijo (1 porsi)',
      'protein': 4.5,
      'calories': 320.0,
      'carbs': 65.0,
      'fat': 6.5,
      'fiber': 2.0,
      'sugar': 40.0,
      'salt': 0.15
    },
    {
      'name': 'Es Pallu Butung (1 porsi)',
      'protein': 4.0,
      'calories': 290.0,
      'carbs': 60.0,
      'fat': 6.0,
      'fiber': 2.0,
      'sugar': 38.0,
      'salt': 0.12
    },
    {
      'name': 'Es Cendol/Dawet (1 gelas)',
      'protein': 2.5,
      'calories': 270.0,
      'carbs': 56.0,
      'fat': 6.0,
      'fiber': 1.5,
      'sugar': 40.0,
      'salt': 0.05
    },
    {
      'name': 'Es Kelapa Muda (1 gelas)',
      'protein': 1.5,
      'calories': 130.0,
      'carbs': 28.0,
      'fat': 3.0,
      'fiber': 1.5,
      'sugar': 20.0,
      'salt': 0.08
    },
    {
      'name': 'Kopi Hitam Tubruk (1 cangkir)',
      'protein': 0.3,
      'calories': 8.0,
      'carbs': 1.5,
      'fat': 0.0,
      'fiber': 0.0,
      'sugar': 0.0,
      'salt': 0.00
    },
    {
      'name': 'Kopi Susu (1 gelas)',
      'protein': 3.5,
      'calories': 130.0,
      'carbs': 18.0,
      'fat': 5.0,
      'fiber': 0.0,
      'sugar': 15.0,
      'salt': 0.10
    },
    {
      'name': 'Cafe Latte (1 gelas)',
      'protein': 8.0,
      'calories': 150.0,
      'carbs': 14.0,
      'fat': 7.5,
      'fiber': 0.0,
      'sugar': 12.0,
      'salt': 0.12
    },
    {
      'name': 'Cappuccino (1 cangkir)',
      'protein': 6.0,
      'calories': 120.0,
      'carbs': 10.0,
      'fat': 6.0,
      'fiber': 0.0,
      'sugar': 9.0,
      'salt': 0.10
    },
    {
      'name': 'Matcha Latte (1 gelas)',
      'protein': 5.5,
      'calories': 155.0,
      'carbs': 22.0,
      'fat': 5.5,
      'fiber': 0.0,
      'sugar': 18.0,
      'salt': 0.12
    },
    {
      'name': 'Thai Tea (1 gelas)',
      'protein': 3.5,
      'calories': 220.0,
      'carbs': 36.0,
      'fat': 7.0,
      'fiber': 0.0,
      'sugar': 30.0,
      'salt': 0.10
    },
    {
      'name': 'Wedang Jahe (1 cangkir)',
      'protein': 0.5,
      'calories': 70.0,
      'carbs': 17.0,
      'fat': 0.5,
      'fiber': 0.5,
      'sugar': 14.0,
      'salt': 0.01
    },
    {
      'name': 'Wedang Ronde (1 mangkuk)',
      'protein': 4.5,
      'calories': 240.0,
      'carbs': 48.0,
      'fat': 5.0,
      'fiber': 1.5,
      'sugar': 30.0,
      'salt': 0.05
    },
    {
      'name': 'Wedang Uwuh (1 cangkir)',
      'protein': 0.3,
      'calories': 80.0,
      'carbs': 20.0,
      'fat': 0.3,
      'fiber': 0.5,
      'sugar': 18.0,
      'salt': 0.01
    },
    {
      'name': 'Bajigur (1 gelas)',
      'protein': 2.5,
      'calories': 180.0,
      'carbs': 32.0,
      'fat': 6.0,
      'fiber': 0.5,
      'sugar': 28.0,
      'salt': 0.08
    },
    {
      'name': 'Bandrek (1 gelas)',
      'protein': 2.5,
      'calories': 170.0,
      'carbs': 30.0,
      'fat': 5.5,
      'fiber': 0.5,
      'sugar': 26.0,
      'salt': 0.08
    },
    {
      'name': 'STMJ Susu Telur Madu Jahe (1 gelas)',
      'protein': 9.0,
      'calories': 230.0,
      'carbs': 28.0,
      'fat': 9.0,
      'fiber': 0.0,
      'sugar': 22.0,
      'salt': 0.12
    },
    {
      'name': 'Jus Sayur Hijau Green Juice (1 gelas)',
      'protein': 3.0,
      'calories': 80.0,
      'carbs': 16.0,
      'fat': 0.5,
      'fiber': 3.0,
      'sugar': 8.0,
      'salt': 0.05
    },
    {
      'name': 'Infused Water Lemon/Timun (1 gelas)',
      'protein': 0.2,
      'calories': 8.0,
      'carbs': 1.5,
      'fat': 0.0,
      'fiber': 0.0,
      'sugar': 1.0,
      'salt': 0.00
    },
    {
      'name': 'Minuman Isotonik (1 botol)',
      'protein': 0.0,
      'calories': 90.0,
      'carbs': 22.0,
      'fat': 0.0,
      'fiber': 0.0,
      'sugar': 22.0,
      'salt': 0.45
    },
    {
      'name': 'Soda Cola/Sprite (1 kaleng)',
      'protein': 0.0,
      'calories': 140.0,
      'carbs': 38.0,
      'fat': 0.0,
      'fiber': 0.0,
      'sugar': 38.0,
      'salt': 0.05
    },
    {
      'name': 'Susu Kedelai (1 gelas)',
      'protein': 7.0,
      'calories': 120.0,
      'carbs': 14.0,
      'fat': 4.5,
      'fiber': 1.5,
      'sugar': 9.0,
      'salt': 0.08
    },
    {
      'name': 'Susu Almond (1 gelas)',
      'protein': 2.0,
      'calories': 80.0,
      'carbs': 8.0,
      'fat': 4.5,
      'fiber': 1.0,
      'sugar': 7.0,
      'salt': 0.15
    },
    {
      'name': 'Susu Oat (1 gelas)',
      'protein': 3.0,
      'calories': 120.0,
      'carbs': 18.0,
      'fat': 4.5,
      'fiber': 2.0,
      'sugar': 7.0,
      'salt': 0.12
    },

    // B6. Jajanan & Pelengkap (baru)
    {
      'name': 'Kue Cubit (5-6 buah)',
      'protein': 5.5,
      'calories': 280.0,
      'carbs': 46.0,
      'fat': 8.0,
      'fiber': 0.5,
      'sugar': 22.0,
      'salt': 0.25
    },
    {
      'name': 'Kue Pukis (2 buah)',
      'protein': 4.5,
      'calories': 230.0,
      'carbs': 38.0,
      'fat': 7.0,
      'fiber': 0.5,
      'sugar': 18.0,
      'salt': 0.20
    },
    {
      'name': 'Kue Pancong (2 buah)',
      'protein': 4.0,
      'calories': 200.0,
      'carbs': 28.0,
      'fat': 9.0,
      'fiber': 1.5,
      'sugar': 8.0,
      'salt': 0.20
    },
    {
      'name': 'Serabi Solo (2 buah)',
      'protein': 4.0,
      'calories': 210.0,
      'carbs': 32.0,
      'fat': 8.0,
      'fiber': 0.5,
      'sugar': 10.0,
      'salt': 0.15
    },
    {
      'name': 'Bika Ambon (1 potong)',
      'protein': 4.0,
      'calories': 250.0,
      'carbs': 40.0,
      'fat': 9.0,
      'fiber': 0.5,
      'sugar': 22.0,
      'salt': 0.20
    },
    {
      'name': 'Bolu Kukus (1 buah)',
      'protein': 4.5,
      'calories': 200.0,
      'carbs': 35.0,
      'fat': 5.0,
      'fiber': 0.5,
      'sugar': 20.0,
      'salt': 0.25
    },
    {
      'name': 'Lapis Legit (1 potong)',
      'protein': 4.0,
      'calories': 220.0,
      'carbs': 28.0,
      'fat': 10.0,
      'fiber': 0.3,
      'sugar': 18.0,
      'salt': 0.20
    },
    {
      'name': 'Roti Bakar Bandung (2 slice+topping)',
      'protein': 7.0,
      'calories': 320.0,
      'carbs': 50.0,
      'fat': 10.0,
      'fiber': 1.5,
      'sugar': 24.0,
      'salt': 0.45
    },
    {
      'name': 'Pisang Aroma Piscok (1 buah)',
      'protein': 3.0,
      'calories': 210.0,
      'carbs': 32.0,
      'fat': 8.0,
      'fiber': 1.5,
      'sugar': 12.0,
      'salt': 0.15
    },
    {
      'name': 'Molen Pisang (2 buah)',
      'protein': 3.5,
      'calories': 230.0,
      'carbs': 34.0,
      'fat': 9.5,
      'fiber': 1.5,
      'sugar': 12.0,
      'salt': 0.20
    },
    {
      'name': 'Gehu Pedas (2 buah)',
      'protein': 8.0,
      'calories': 180.0,
      'carbs': 16.0,
      'fat': 9.0,
      'fiber': 1.0,
      'sugar': 1.0,
      'salt': 0.40
    },
    {
      'name': 'Combro (2 buah)',
      'protein': 4.5,
      'calories': 200.0,
      'carbs': 28.0,
      'fat': 9.0,
      'fiber': 2.0,
      'sugar': 1.5,
      'salt': 0.35
    },
    {
      'name': 'Misro (2 buah)',
      'protein': 3.5,
      'calories': 195.0,
      'carbs': 30.0,
      'fat': 8.5,
      'fiber': 1.5,
      'sugar': 4.0,
      'salt': 0.15
    },
    {
      'name': 'Kerupuk Udang (5-6 keping)',
      'protein': 3.5,
      'calories': 145.0,
      'carbs': 22.0,
      'fat': 5.0,
      'fiber': 0.3,
      'sugar': 0.5,
      'salt': 0.55
    },
    {
      'name': 'Kerupuk Putih Mawar (5-6 keping)',
      'protein': 2.5,
      'calories': 140.0,
      'carbs': 24.0,
      'fat': 4.5,
      'fiber': 0.2,
      'sugar': 0.5,
      'salt': 0.40
    },
    {
      'name': 'Kacang Mete Goreng (1 genggam)',
      'protein': 4.5,
      'calories': 175.0,
      'carbs': 9.5,
      'fat': 14.5,
      'fiber': 0.9,
      'sugar': 1.5,
      'salt': 0.10
    },
    {
      'name': 'Kacang Almond Panggang (1 genggam)',
      'protein': 6.0,
      'calories': 165.0,
      'carbs': 6.0,
      'fat': 14.5,
      'fiber': 3.5,
      'sugar': 1.1,
      'salt': 0.00
    },
    {
      'name': 'Granola Bar (1 bar)',
      'protein': 4.0,
      'calories': 190.0,
      'carbs': 28.0,
      'fat': 7.0,
      'fiber': 2.5,
      'sugar': 12.0,
      'salt': 0.15
    },
    {
      'name': 'Dark Chocolate 80%+ (3 kotak kecil)',
      'protein': 2.5,
      'calories': 160.0,
      'carbs': 13.0,
      'fat': 12.0,
      'fiber': 3.5,
      'sugar': 7.0,
      'salt': 0.01
    },
    {
      'name': 'Madu Murni (1 sdm)',
      'protein': 0.1,
      'calories': 64.0,
      'carbs': 17.3,
      'fat': 0.0,
      'fiber': 0.0,
      'sugar': 17.2,
      'salt': 0.00
    },
  ];
}
