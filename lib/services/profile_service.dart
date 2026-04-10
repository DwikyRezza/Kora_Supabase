import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'auth_service.dart';

class ProfileService {
  static String keyIsOnboarded = 'isOnboarded';
  static String keyName = 'name';
  static String keyAge = 'age';
  static String keyGender = 'gender';
  static String keyHeight = 'height';
  static String keyWeight = 'weight';
  static String keyGoal = 'goal';
  static String keyTargetProtein = 'targetProtein';

  static final _db = DatabaseHelper();

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

    // Save to SharedPreferences (backward compatibility)
    await prefs.setString(keyName, name);
    await prefs.setInt(keyAge, age);
    await prefs.setString(keyGender, gender);
    await prefs.setDouble(keyHeight, height);
    await prefs.setDouble(keyWeight, weight);
    await prefs.setString(keyGoal, goal);
    await prefs.setDouble(keyTargetProtein, targetProtein);
    await prefs.setBool(keyIsOnboarded, true);

    // Also save to database if user is logged in
    if (AuthService.isLoggedIn) {
      final uid = AuthService.uid;
      final now = DateTime.now().toIso8601String();
      await _db.upsertUserProfile({
        'uid': uid,
        'name': name,
        'email': AuthService.email,
        'photoUrl': AuthService.photoUrl,
        'age': age,
        'gender': gender,
        'height': height,
        'weight': weight,
        'goal': goal,
        'targetProtein': targetProtein,
        'createdAt': now,
        'updatedAt': now,
      });
    }
  }

  static Future<void> updateProfileField(String field, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (value is String) {
      await prefs.setString(field, value);
    } else if (value is int) {
      await prefs.setInt(field, value);
    } else if (value is double) {
      await prefs.setDouble(field, value);
    }

    // Update in database too
    if (AuthService.isLoggedIn) {
      final uid = AuthService.uid;
      final profile = await _db.getUserProfile(uid);
      if (profile != null) {
        final updated = Map<String, dynamic>.from(profile);
        updated[field] = value;
        updated['updatedAt'] = DateTime.now().toIso8601String();
        
        // Recalculate target protein if weight or goal changed
        if (field == 'weight' || field == 'goal') {
          double w = (field == 'weight') ? (value as double) : (updated['weight'] as num).toDouble();
          String g = (field == 'goal') ? (value as String) : updated['goal'];
          double multiplier = _getProteinMultiplier(g);
          updated['targetProtein'] = w * multiplier;
          await prefs.setDouble(keyTargetProtein, w * multiplier);
        }
        
        await _db.upsertUserProfile(updated);
      }
    }
  }

  static double _getProteinMultiplier(String goal) {
    switch (goal) {
      case 'Bulking': return 2.0;
      case 'Weightlifter': return 1.8;
      case 'Diet': return 1.6;
      case 'Runner': return 1.5;
      default: return 1.0;
    }
  }

  static Future<Map<String, dynamic>> getProfile() async {
    // Try loading from database first if logged in
    if (AuthService.isLoggedIn) {
      final uid = AuthService.uid;
      final dbProfile = await _db.getUserProfile(uid);
      if (dbProfile != null) {
        return {
          keyName: dbProfile['name'] ?? '',
          keyAge: dbProfile['age'] ?? 0,
          keyGender: dbProfile['gender'] ?? 'Laki-laki',
          keyHeight: (dbProfile['height'] as num?)?.toDouble() ?? 0.0,
          keyWeight: (dbProfile['weight'] as num?)?.toDouble() ?? 0.0,
          keyGoal: dbProfile['goal'] ?? '',
          keyTargetProtein: (dbProfile['targetProtein'] as num?)?.toDouble() ?? 0.0,
          'photoUrl': dbProfile['photoUrl'] ?? AuthService.photoUrl,
          'email': dbProfile['email'] ?? AuthService.email,
        };
      }
    }

    // Fallback to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    return {
      keyName: prefs.getString(keyName) ?? '',
      keyAge: prefs.getInt(keyAge) ?? 0,
      keyGender: prefs.getString(keyGender) ?? 'Laki-laki',
      keyHeight: prefs.getDouble(keyHeight) ?? 0.0,
      keyWeight: prefs.getDouble(keyWeight) ?? 0.0,
      keyGoal: prefs.getString(keyGoal) ?? '',
      keyTargetProtein: prefs.getDouble(keyTargetProtein) ?? 0.0,
    };
  }

  /// Sync SharedPreferences data to database for the logged-in user
  static Future<void> syncToDatabase() async {
    if (!AuthService.isLoggedIn) return;
    
    final prefs = await SharedPreferences.getInstance();
    final uid = AuthService.uid;
    final now = DateTime.now().toIso8601String();
    
    // Check if profile already exists in DB
    final existing = await _db.getUserProfile(uid);
    if (existing != null) return; // Already synced
    
    final name = prefs.getString(keyName) ?? AuthService.displayName;
    final weight = prefs.getDouble(keyWeight) ?? 0.0;
    final goal = prefs.getString(keyGoal) ?? 'Bulking';
    
    await _db.upsertUserProfile({
      'uid': uid,
      'name': name,
      'email': AuthService.email,
      'photoUrl': AuthService.photoUrl,
      'age': prefs.getInt(keyAge) ?? 0,
      'gender': prefs.getString(keyGender) ?? 'Laki-laki',
      'height': prefs.getDouble(keyHeight) ?? 0.0,
      'weight': weight,
      'goal': goal,
      'targetProtein': prefs.getDouble(keyTargetProtein) ?? weight * _getProteinMultiplier(goal),
      'createdAt': now,
      'updatedAt': now,
    });
  }

  static String getBMIStatus(double bmi) {
    if (bmi < 18.5) return 'Kurus';
    if (bmi >= 18.5 && bmi <= 24.9) return 'Ideal';
    if (bmi >= 25.0 && bmi <= 29.9) return 'Overweight';
    return 'Obesitas';
  }
}
