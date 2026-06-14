import 'package:flutter/material.dart';
class Workout {
  final int? id;
  final String type; // 'running', 'basketball', 'weightlifting'
  final double duration; // in minutes
  final double? distance; // km, for running
  final int? sets; // for weightlifting
  final int? reps; // for weightlifting
  final double? weight; // kg, for weightlifting
  final int caloriesBurned;
  final double proteinNeeded; // grams
  final String notes;
  final DateTime date;
  
  // New fields for running details
  final double? movingTime;
  final double? elevationGain;
  final double? maxElevation;
  final String? photoPath;
  final String? splitsStr;
  final String? polyline; // JSON string of [lat, lng] list
  final String? title;
  final String? photosJson; // JSON string of List<String>

  Workout({
    this.id,
    required this.type,
    required this.duration,
    this.distance,
    this.sets,
    this.reps,
    this.weight,
    required this.caloriesBurned,
    required this.proteinNeeded,
    this.notes = '',
    required this.date,
    this.movingTime,
    this.elevationGain,
    this.maxElevation,
    this.photoPath,
    this.splitsStr,
    this.polyline,
    this.title,
    this.photosJson,
  });

  // Protein requirement based on workout type and intensity
  static double calculateProteinNeeded(String type, double duration, {double? weight}) {
    switch (type) {
      case 'weightlifting':
        // 1.6 - 2.2g per kg body weight, scaled to session
        double bw = weight ?? 70.0;
        return (bw * 0.04 * (duration / 60)).clamp(15, 60);
      case 'running':
        // Moderate: ~0.1g per minute
        return (duration * 0.12).clamp(10, 40);
      case 'basketball':
        // High intensity: ~0.14g per minute
        return (duration * 0.14).clamp(12, 45);
      default:
        return (duration * 0.1).clamp(10, 35);
    }
  }

  static int calculateCalories(String type, double duration) {
    switch (type) {
      case 'weightlifting':
        return (duration * 6).round();
      case 'running':
        return (duration * 10).round();
      case 'basketball':
        return (duration * 8).round();
      default:
        return (duration * 7).round();
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'duration': duration,
      'distance': distance,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'caloriesBurned': caloriesBurned,
      'proteinNeeded': proteinNeeded,
      'notes': notes,
      'date': date.toIso8601String(),
      'movingTime': movingTime,
      'elevationGain': elevationGain,
      'maxElevation': maxElevation,
      'splitsStr': splitsStr,
      'polyline': polyline,
      'title': title,
      // photoPath & photosJson TIDAK dimasukkan lagi —
      // foto sekarang disimpan di tabel terpisah 'workout_photos' (lazy loading)
    };
  }

  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'],
      type: map['type'],
      duration: map['duration'],
      distance: map['distance'],
      sets: map['sets'],
      reps: map['reps'],
      weight: map['weight'],
      caloriesBurned: map['caloriesBurned'],
      proteinNeeded: map['proteinNeeded'],
      notes: map['notes'] ?? '',
      date: DateTime.parse(map['date']),
      movingTime: map['movingTime'],
      elevationGain: map['elevationGain'],
      maxElevation: map['maxElevation'],
      // Legacy fields — tetap dibaca untuk backward compat, tapi tidak
      // lagi digunakan sebagai sumber utama foto. Gunakan DatabaseHelper
      // .getWorkoutPhotos(id) untuk lazy loading foto.
      photoPath: map['photoPath'],
      splitsStr: map['splitsStr'],
      polyline: map['polyline'],
      title: map['title'],
      photosJson: map['photosJson'],
    );
  }

  String get typeLabel {
    switch (type) {
      case 'running':
        return 'Lari';
      case 'basketball':
        return 'Basket';
      case 'weightlifting':
        return 'Angkat Beban';
      default:
        return type;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case 'running':
        return Icons.directions_run;
      case 'basketball':
        return Icons.sports_basketball;
      case 'weightlifting':
        return Icons.fitness_center;
      default:
        return Icons.sports_gymnastics;
    }
  }
}
