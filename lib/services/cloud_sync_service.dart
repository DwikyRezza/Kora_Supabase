import 'package:cloud_firestore/cloud_firestore.dart';
import 'database_helper.dart';
import 'auth_service.dart';

/// CloudSyncService — Opsi B Strategy
///
/// SQLite = primary storage (cepat, offline)
/// Firestore = cloud backup (sync otomatis di background)
///
/// Alur:
/// - WRITE: tulis ke SQLite dulu → langsung trigger background sync ke Firestore
/// - READ: selalu dari SQLite (cepat)
/// - LOGIN (device baru): jika SQLite kosong → restore semua dari Firestore
class CloudSyncService {
  static final _firestore = FirebaseFirestore.instance;
  static final _db = DatabaseHelper();

  static String get _uid => AuthService.uid;
  static DocumentReference get _userDoc =>
      _firestore.collection('users').doc(_uid);

  // ─────────────────────────────────────────────────────────────────────────
  // SYNC UP — Push SQLite → Firestore (background, non-blocking)
  // ─────────────────────────────────────────────────────────────────────────

  /// Push semua data ke Firestore (panggil setelah login atau perubahan besar)
  static Future<void> backupToCloud() async {
    if (!AuthService.isLoggedIn) return;
    // Jalankan semua sync secara paralel
    await Future.wait([
      syncNutritionToCloud(),
      syncWorkoutsToCloud(),
      syncScheduleToCloud(),
      syncBodyMeasurementsToCloud(),
    ]);
  }

  /// Sync nutrition/protein entries → Firestore
  static Future<void> syncNutritionToCloud() async {
    if (!AuthService.isLoggedIn) return;
    try {
      final db = await _db.database;
      final entries = await db.query('protein_entries', orderBy: 'date ASC');
      if (entries.isEmpty) return;

      // Kelompokkan per tanggal untuk query yang efisien
      final Map<String, List<Map<String, dynamic>>> byDate = {};
      for (final e in entries) {
        final dateKey = (e['date'] as String).substring(0, 10); // YYYY-MM-DD
        byDate.putIfAbsent(dateKey, () => []).add(Map.from(e));
      }

      final batch = _firestore.batch();
      for (final entry in byDate.entries) {
        batch.set(
          _userDoc.collection('nutrition').doc(entry.key),
          {'date': entry.key, 'entries': entry.value},
        );
      }
      await batch.commit();
      print('[CloudSync] ✅ Nutrition synced: ${entries.length} entries');
    } catch (e) {
      print('[CloudSync] ⚠️ Nutrition sync failed: $e');
    }
  }

  /// Sync workouts → Firestore
  static Future<void> syncWorkoutsToCloud() async {
    if (!AuthService.isLoggedIn) return;
    try {
      final workouts = await _db.getAllWorkouts();
      if (workouts.isEmpty) return;

      final batch = _firestore.batch();
      for (final w in workouts) {
        batch.set(
          _userDoc.collection('workouts').doc(w.id.toString()),
          w.toMap(),
        );
      }
      await batch.commit();
      print('[CloudSync] ✅ Workouts synced: ${workouts.length}');
    } catch (e) {
      print('[CloudSync] ⚠️ Workout sync failed: $e');
    }
  }

  /// Sync schedule events → Firestore
  static Future<void> syncScheduleToCloud() async {
    if (!AuthService.isLoggedIn) return;
    try {
      final db = await _db.database;
      final events = await db.query('schedule_events');
      if (events.isEmpty) return;

      final batch = _firestore.batch();
      for (final e in events) {
        batch.set(
          _userDoc.collection('schedule_events').doc(e['id'].toString()),
          Map.from(e),
        );
      }
      await batch.commit();
      print('[CloudSync] ✅ Schedule synced: ${events.length} events');
    } catch (e) {
      print('[CloudSync] ⚠️ Schedule sync failed: $e');
    }
  }

  /// Sync body measurements → Firestore
  static Future<void> syncBodyMeasurementsToCloud() async {
    if (!AuthService.isLoggedIn) return;
    try {
      final measurements = await _db.getAllBodyMeasurements();
      if (measurements.isEmpty) return;

      final batch = _firestore.batch();
      for (final m in measurements) {
        batch.set(
          _userDoc.collection('body_measurements').doc(m.id.toString()),
          m.toMap(),
        );
      }
      await batch.commit();
      print('[CloudSync] ✅ Body measurements synced: ${measurements.length}');
    } catch (e) {
      print('[CloudSync] ⚠️ Body measurement sync failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SYNC DOWN — Restore Firestore → SQLite (saat login di device baru)
  // ─────────────────────────────────────────────────────────────────────────

  /// Cek apakah SQLite lokal kosong (belum ada data untuk user ini)
  static Future<bool> isLocalDataEmpty() async {
    try {
      final workouts = await _db.getAllWorkouts();
      return workouts.isEmpty;
    } catch (_) {
      return true;
    }
  }

  /// Restore semua data dari Firestore ke SQLite lokal
  /// Dipanggil saat login di device baru (jika SQLite kosong)
  static Future<void> restoreAllFromCloud() async {
    if (!AuthService.isLoggedIn) return;
    print('[CloudSync] 🔄 Restoring all data from Firestore...');

    await Future.wait([
      _restoreNutrition(),
      _restoreWorkouts(),
      _restoreSchedule(),
      _restoreBodyMeasurements(),
    ]);

    print('[CloudSync] ✅ Restore from Firestore complete.');
  }

  static Future<void> _restoreNutrition() async {
    try {
      final db = await _db.database;
      final snapshot = await _userDoc.collection('nutrition').get();
      if (snapshot.docs.isEmpty) return;

      // Bersihkan data lama, ganti dengan data cloud
      await db.delete('protein_entries');
      for (final doc in snapshot.docs) {
        final entries = doc.data()['entries'] as List<dynamic>? ?? [];
        for (final e in entries) {
          final map = Map<String, dynamic>.from(e as Map);
          map.remove('id'); // biarkan SQLite auto-generate ID baru
          try {
            await db.insert('protein_entries', map);
          } catch (_) {}
        }
      }
      print('[CloudSync] ✅ Nutrition restored from Firestore');
    } catch (e) {
      print('[CloudSync] ⚠️ Nutrition restore failed: $e');
    }
  }

  static Future<void> _restoreWorkouts() async {
    try {
      final db = await _db.database;
      final snapshot = await _userDoc.collection('workouts').get();
      if (snapshot.docs.isEmpty) return;

      await db.delete('workouts');
      for (final doc in snapshot.docs) {
        final map = Map<String, dynamic>.from(doc.data());
        map.remove('id');
        try {
          await db.insert('workouts', map);
        } catch (_) {}
      }
      print('[CloudSync] ✅ Workouts restored from Firestore');
    } catch (e) {
      print('[CloudSync] ⚠️ Workouts restore failed: $e');
    }
  }

  static Future<void> _restoreSchedule() async {
    try {
      final db = await _db.database;
      final snapshot = await _userDoc.collection('schedule_events').get();
      if (snapshot.docs.isEmpty) return;

      await db.delete('schedule_events');
      for (final doc in snapshot.docs) {
        final map = Map<String, dynamic>.from(doc.data());
        map.remove('id');
        try {
          await db.insert('schedule_events', map);
        } catch (_) {}
      }
      print('[CloudSync] ✅ Schedule restored from Firestore');
    } catch (e) {
      print('[CloudSync] ⚠️ Schedule restore failed: $e');
    }
  }

  static Future<void> _restoreBodyMeasurements() async {
    try {
      final db = await _db.database;
      final snapshot = await _userDoc.collection('body_measurements').get();
      if (snapshot.docs.isEmpty) return;

      await db.delete('body_measurements');
      for (final doc in snapshot.docs) {
        final map = Map<String, dynamic>.from(doc.data());
        map.remove('id');
        try {
          await db.insert('body_measurements', map);
        } catch (_) {}
      }
      print('[CloudSync] ✅ Body measurements restored from Firestore');
    } catch (e) {
      print('[CloudSync] ⚠️ Body measurements restore failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BACKWARD COMPAT — Stubs untuk kode lama
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> restoreProfile() async => false; // Sekarang ditangani ProfileService
  static Future<void> restoreDataFromCloud() => restoreAllFromCloud();
}
