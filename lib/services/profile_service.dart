import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

/// ProfileService — Cloud-First (Firestore Only)
/// Semua data profil disimpan dan dibaca dari Firestore.
/// Tidak ada penyimpanan lokal (tidak pakai SQLite / SharedPreferences).
class ProfileService {
  static const keyName = 'name';
  static const keyAge = 'age';
  static const keyGender = 'gender';
  static const keyHeight = 'height';
  static const keyWeight = 'weight';
  static const keyGoal = 'goal';
  static const keyTargetProtein = 'targetProtein';
  static const keyPhotoUrl = 'photoUrl';
  static const keyIsOnboarded = 'isOnboarded';

  static final _firestore = FirebaseFirestore.instance;

  // ─── Referensi dokumen user di Firestore ──────────────────────────────────
  static DocumentReference get _userDoc =>
      _firestore.collection('users').doc(AuthService.uid);

  // ─── Hitung target protein berdasarkan goal ────────────────────────────────
  static double _calcTargetProtein(double weight, String goal) {
    switch (goal) {
      case 'Bulking': return weight * 2.0;
      case 'Weightlifter': return weight * 1.8;
      case 'Diet': return weight * 1.6;
      case 'Runner': return weight * 1.5;
      default: return weight * 1.0;
    }
  }

  // ─── Cek apakah user sudah onboarding (ada dokumen profil di Firestore) ────
  static Future<bool> isOnboarded() async {
    if (!AuthService.isLoggedIn) return false;
    try {
      final doc = await _userDoc.get();
      return doc.exists && (doc.data() as Map?)?.containsKey('profile') == true;
    } catch (e) {
      print('[ProfileService] isOnboarded error: $e');
      return false;
    }
  }

  // ─── Simpan profil ke Firestore ────────────────────────────────────────────
  static Future<void> saveProfile({
    required String name,
    required int age,
    required String gender,
    required double height,
    required double weight,
    required String goal,
    String? photoUrl,
  }) async {
    if (!AuthService.isLoggedIn) return;

    final targetProtein = _calcTargetProtein(weight, goal);
    final now = DateTime.now().toIso8601String();

    // Ambil data lama untuk preserve createdAt dan photoUrl yang sudah ada
    String? resolvedPhotoUrl;
    String? createdAt;
    try {
      final doc = await _userDoc.get();
      final oldProfile = (doc.data() as Map?)?.containsKey('profile') == true
          ? (doc.data() as Map)['profile'] as Map<String, dynamic>?
          : null;

      createdAt = oldProfile?['createdAt'] as String? ?? now;

      // Tentukan foto: pakai yang baru jika https://, jaga yang lama jika valid, fallback Google
      final oldPhoto = oldProfile?['photoUrl'] as String?;
      if (photoUrl != null && photoUrl.startsWith('https://')) {
        resolvedPhotoUrl = photoUrl;
      } else if (oldPhoto != null && oldPhoto.startsWith('https://')) {
        resolvedPhotoUrl = oldPhoto;
      } else {
        resolvedPhotoUrl = AuthService.photoUrl;
      }
    } catch (_) {
      createdAt = now;
      resolvedPhotoUrl = photoUrl?.startsWith('https://') == true
          ? photoUrl
          : AuthService.photoUrl;
    }

    final profileMap = {
      'uid': AuthService.uid,
      'name': name,
      'email': AuthService.email,
      'photoUrl': resolvedPhotoUrl,
      'age': age,
      'gender': gender,
      'height': height,
      'weight': weight,
      'goal': goal,
      'targetProtein': targetProtein,
      'createdAt': createdAt,
      'updatedAt': now,
    };

    // ── Simpan ke Firestore ───────────────────────────────────────────────────
    await _userDoc.set({'profile': profileMap}, SetOptions(merge: true));
    print('[ProfileService] ✅ Profil tersimpan ke Firestore: $name');
  }

  // ─── Ambil profil dari Firestore ───────────────────────────────────────────
  static Future<Map<String, dynamic>> getProfile() async {
    if (!AuthService.isLoggedIn) return _emptyProfile();

    try {
      final doc = await _userDoc.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('profile')) {
          final p = data['profile'] as Map<String, dynamic>;
          return {
            keyName: p['name'] ?? AuthService.displayName,
            keyAge: p['age'] ?? 0,
            keyGender: p['gender'] ?? 'Laki-laki',
            keyHeight: (p['height'] as num?)?.toDouble() ?? 0.0,
            keyWeight: (p['weight'] as num?)?.toDouble() ?? 0.0,
            keyGoal: p['goal'] ?? '',
            keyTargetProtein: (p['targetProtein'] as num?)?.toDouble() ?? 0.0,
            'photoUrl': p['photoUrl'] ?? AuthService.photoUrl,
            'email': p['email'] ?? AuthService.email,
          };
        }
      }
    } catch (e) {
      print('[ProfileService] getProfile error: $e');
    }

    // Fallback jika Firestore tidak bisa diakses
    return _emptyProfile();
  }

  // ─── Profil kosong (default) ───────────────────────────────────────────────
  static Map<String, dynamic> _emptyProfile() => {
    keyName: AuthService.displayName,
    keyAge: 0,
    keyGender: 'Laki-laki',
    keyHeight: 0.0,
    keyWeight: 0.0,
    keyGoal: '',
    keyTargetProtein: 0.0,
    'photoUrl': AuthService.photoUrl,
    'email': AuthService.email,
  };

  // ─── Update satu field di Firestore ────────────────────────────────────────
  static Future<void> updateProfileField(String field, dynamic value) async {
    if (!AuthService.isLoggedIn) return;
    try {
      await _userDoc.update({'profile.$field': value});
      // Recalculate targetProtein jika weight atau goal berubah
      if (field == 'weight' || field == 'goal') {
        final profile = await getProfile();
        final w = (field == 'weight') ? (value as double) : (profile[keyWeight] as double);
        final g = (field == 'goal') ? (value as String) : (profile[keyGoal] as String);
        await _userDoc.update({'profile.targetProtein': _calcTargetProtein(w, g)});
      }
    } catch (e) {
      print('[ProfileService] updateProfileField error: $e');
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  static String getBMIStatus(double bmi) {
    if (bmi < 18.5) return 'Kurus';
    if (bmi <= 24.9) return 'Ideal';
    if (bmi <= 29.9) return 'Overweight';
    return 'Obesitas';
  }

  // Backward compat stubs (tidak dipakai tapi mungkin masih direferensikan)
  static Future<void> syncToDatabase() async {}
  static Future<bool> checkAndSyncFromDatabase() async => await isOnboarded();
}
