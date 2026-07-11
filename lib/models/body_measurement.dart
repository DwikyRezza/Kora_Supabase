import '../utils/id_generator.dart';

class BodyMeasurement {
  final String? id;
  final double weight; // in kg
  final double height; // in cm
  final double? bodyFatPercentage;
  final double? chest; // in cm
  final double? waist; // in cm
  final double? hips; // in cm
  final double? biceps; // in cm
  final DateTime date;

  BodyMeasurement({
    this.id,
    required this.weight,
    required this.height,
    this.bodyFatPercentage,
    this.chest,
    this.waist,
    this.hips,
    this.biceps,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'weight': weight,
      'height': height,
      'bodyFatPercentage': bodyFatPercentage,
      'chest': chest,
      'waist': waist,
      'hips': hips,
      'biceps': biceps,
      'date': date.toIso8601String(),
    };
  }

  factory BodyMeasurement.fromMap(Map<String, dynamic> map) {
    return BodyMeasurement(
      id: IdGenerator.parseId(map['id']),
      weight: map['weight'],
      height: map['height'],
      bodyFatPercentage: map['bodyFatPercentage'],
      chest: map['chest'],
      waist: map['waist'],
      hips: map['hips'],
      biceps: map['biceps'],
      date: DateTime.parse(map['date']),
    );
  }

  double get bmi {
    final heightInMeters = height / 100;
    return weight / (heightInMeters * heightInMeters);
  }

  String get bmiCategory {
    final bmiObj = bmi;
    if (bmiObj < 18.5) return 'Underweight';
    if (bmiObj < 24.9) return 'Normal Weight';
    if (bmiObj < 29.9) return 'Overweight';
    return 'Obese';
  }
}
