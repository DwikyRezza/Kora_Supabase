import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  static String keyIsOnboarded = 'isOnboarded';
  static String keyName = 'name';
  static String keyAge = 'age';
  static String keyGender = 'gender';
  static String keyHeight = 'height';
  static String keyWeight = 'weight';
  static String keyGoal = 'goal';
  static String keyTargetProtein = 'targetProtein';

  static Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyIsOnboarded) ?? false;
  }

  static Future<void> saveProfile({
    required String name,
    required int age,
    required String gender,
    required double height,
    required double weight,
    required String goal,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Calculate Target Protein
    double proteinMultiplier = 1.0;
    switch (goal) {
      case 'Bulking':
        proteinMultiplier = 2.0;
        break;
      case 'Weightlifter':
        proteinMultiplier = 1.8;
        break;
      case 'Diet':
        proteinMultiplier = 1.6;
        break;
      case 'Runner':
        proteinMultiplier = 1.5;
        break;
      default:
        proteinMultiplier = 1.0;
    }
    
    double targetProtein = weight * proteinMultiplier;

    await prefs.setString(keyName, name);
    await prefs.setInt(keyAge, age);
    await prefs.setString(keyGender, gender);
    await prefs.setDouble(keyHeight, height);
    await prefs.setDouble(keyWeight, weight);
    await prefs.setString(keyGoal, goal);
    await prefs.setDouble(keyTargetProtein, targetProtein);
    await prefs.setBool(keyIsOnboarded, true);
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      keyName: prefs.getString(keyName) ?? '',
      keyAge: prefs.getInt(keyAge) ?? 0,
      keyGender: prefs.getString(keyGender) ?? 'L',
      keyHeight: prefs.getDouble(keyHeight) ?? 0.0,
      keyWeight: prefs.getDouble(keyWeight) ?? 0.0,
      keyGoal: prefs.getString(keyGoal) ?? '',
      keyTargetProtein: prefs.getDouble(keyTargetProtein) ?? 0.0,
    };
  }

  static String getBMIStatus(double bmi) {
    if (bmi < 18.5) return 'Kurus';
    if (bmi >= 18.5 && bmi <= 24.9) return 'Ideal';
    if (bmi >= 25.0 && bmi <= 29.9) return 'Overweight';
    return 'Obesitas';
  }
}
