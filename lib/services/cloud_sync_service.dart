import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import 'auth_service.dart';

// ── Top-level function required by compute() — must be static/top-level ──
// This runs on a background Isolate to keep UI thread free from CPU load.
Future<String?> _cropAndCompressToBase64(Uint8List rawBytes) async {
  try {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return null;

    // Crop to 16:9 aspect ratio
    final targetWidth = decoded.width;
    final targetHeight = (decoded.width * 9 ~/ 16);
    final cropY = ((decoded.height - targetHeight) ~/ 2).clamp(0, decoded.height - 1);
    final safeHeight = targetHeight.clamp(1, decoded.height - cropY);
    final cropped = img.copyCrop(decoded, x: 0, y: cropY, width: targetWidth, height: safeHeight);

    // Guarded compression loop
    int quality = 70;
    int maxWidth = 600;
    const int maxIterations = 5;
    const int qualityFloor = 30;
    const int widthFloor = 300;
    const int maxBase64Bytes = 200 * 1024; // 200KB

    for (int i = 0; i < maxIterations; i++) {
      final resizeWidth = maxWidth.clamp(widthFloor, 600);
      final resized = img.copyResize(cropped, width: resizeWidth);
      final jpegBytes = img.encodeJpg(resized, quality: quality);
      final base64Str = base64Encode(jpegBytes);

      if (base64Str.length <= maxBase64Bytes || quality <= qualityFloor) {
        // Either small enough or floor reached — accept result
        return base64Str;
      }

      // Reduce quality and width for next attempt
      quality = (quality - 10).clamp(qualityFloor, 100);
      maxWidth = (maxWidth - 50).clamp(widthFloor, 600);
    }

    // After max iterations, return last attempt regardless of size
    final finalResized = img.copyResize(cropped, width: maxWidth.clamp(widthFloor, 600));
    return base64Encode(img.encodeJpg(finalResized, quality: quality));
  } catch (_) {
    return null;
  }
}

/// CloudSyncService — Opsi B Strategy
///
/// SQLite = primary storage (cepat, offline)
/// Firestore = cloud backup (sync otomatis di background)
///
/// Alur:
/// - WRITE: tulis ke SQLite dulu → langsung trigger background sync ke Firestore
/// - READ: selalu dari SQLite (cepat)
/// - LOGIN (device baru): restore semua dari Firestore → tulis ke SQLite → UI load
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
      
      // Get dates that have unsynced entries
      final unsynced = await db.query('protein_entries', columns: ['date'], where: 'is_synced = 0 OR is_synced IS NULL');
      if (unsynced.isEmpty) return;

      final Set<String> datesToSync = unsynced.map((e) => (e['date'] as String).substring(0, 10)).toSet();

      final batch = _firestore.batch();
      for (final dateKey in datesToSync) {
        // Query ALL entries for this date
        final entriesForDate = await db.query('protein_entries', where: 'date LIKE ?', whereArgs: ['$dateKey%'], orderBy: 'date ASC');
        final entriesList = entriesForDate.map((e) => Map<String, dynamic>.from(e)..remove('is_synced')).toList();
        
        batch.set(
          _userDoc.collection('nutrition').doc(dateKey),
          {'date': dateKey, 'entries': entriesList},
        );
      }
      await batch.commit();
      
      // Mark as synced
      for (final dateKey in datesToSync) {
         await db.update('protein_entries', {'is_synced': 1}, where: 'date LIKE ?', whereArgs: ['$dateKey%']);
      }
      print('[CloudSync] ✅ Nutrition synced for dates: $datesToSync');
    } catch (e) {
      print('[CloudSync] ⚠️ Nutrition sync failed: $e');
    }
  }

  /// Sync workouts → Firestore
  static Future<void> syncWorkoutsToCloud() async {
    if (!AuthService.isLoggedIn) return;
    try {
      final db = await _db.database;
      
      final deleted = await db.query('deleted_records', where: 'table_name = ?', whereArgs: ['workouts']);
      if (deleted.isNotEmpty) {
        final deleteBatch = _firestore.batch();
        for (final row in deleted) {
          deleteBatch.delete(_userDoc.collection('workouts').doc(row['record_id'].toString()));
        }
        await deleteBatch.commit();
        final deletedIds = deleted.map((e) => e['id'] as int).toList();
        final placeholders = deletedIds.map((_) => '?').join(',');
        await db.delete('deleted_records', where: 'id IN ($placeholders)', whereArgs: deletedIds);
      }

      final workouts = await db.query('workouts', where: 'is_synced = 0 OR is_synced IS NULL');
      if (workouts.isEmpty) return;

      final batch = _firestore.batch();
      for (final w in workouts) {
        batch.set(
          _userDoc.collection('workouts').doc(w['id'].toString()),
          Map<String, dynamic>.from(w)..remove('is_synced'),
        );
      }
      await batch.commit();

      // Sync workout_photos
      for (final w in workouts) {
        if (w['id'] == null) continue;
        final photos = await db.query('workout_photos', where: 'workout_id = ?', whereArgs: [w['id']]);
        if (photos.isNotEmpty) {
          final photoBatch = _firestore.batch();
          for (final p in photos) {
            photoBatch.set(
              _userDoc.collection('workouts').doc(w['id'].toString()).collection('photos').doc(p['id'].toString()),
              Map<String, dynamic>.from(p)..remove('id')..remove('is_synced'),
            );
          }
          await photoBatch.commit();
        }
      }
      
      final ids = workouts.map((e) => e['id'] as int).toList();
      await _db.markAsSynced('workouts', ids);
      print('[CloudSync] ✅ Workouts synced: ${workouts.length}');
    } catch (e) {
      print('[CloudSync] ⚠️ Workout sync failed: $e');
    }
  }

  /// Hapus satu workout dari Firestore
  static Future<void> deleteWorkout(int workoutId) async {
    if (!AuthService.isLoggedIn) return;
    try {
      final workoutRef = _userDoc.collection('workouts').doc(workoutId.toString());
      // Hapus photos subcollection dulu
      final photosSnap = await workoutRef.collection('photos').get();
      if (photosSnap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final p in photosSnap.docs) {
          batch.delete(p.reference);
        }
        await batch.commit();
      }
      await workoutRef.delete();
      print('[CloudSync] ✅ Workout $workoutId deleted from Firestore');
    } catch (e) {
      print('[CloudSync] ⚠️ Delete workout failed: $e');
    }
  }

  /// Sync schedule events → Firestore
  static Future<void> syncScheduleToCloud() async {
    if (!AuthService.isLoggedIn) return;
    try {
      final db = await _db.database;
      
      final deleted = await db.query('deleted_records', where: 'table_name = ?', whereArgs: ['schedule_events']);
      if (deleted.isNotEmpty) {
        final deleteBatch = _firestore.batch();
        for (final row in deleted) {
          deleteBatch.delete(_userDoc.collection('schedule_events').doc(row['record_id'].toString()));
        }
        await deleteBatch.commit();
        final deletedIds = deleted.map((e) => e['id'] as int).toList();
        final placeholders = deletedIds.map((_) => '?').join(',');
        await db.delete('deleted_records', where: 'id IN ($placeholders)', whereArgs: deletedIds);
      }

      final events = await db.query('schedule_events', where: 'is_synced = 0 OR is_synced IS NULL');
      if (events.isEmpty) return;

      final batch = _firestore.batch();
      for (final e in events) {
        batch.set(
          _userDoc.collection('schedule_events').doc(e['id'].toString()),
          Map<String, dynamic>.from(e)..remove('is_synced'),
        );
      }
      await batch.commit();
      
      final ids = events.map((e) => e['id'] as int).toList();
      await _db.markAsSynced('schedule_events', ids);
      print('[CloudSync] ✅ Schedule synced: ${events.length} events');
    } catch (e) {
      print('[CloudSync] ⚠️ Schedule sync failed: $e');
    }
  }

  /// Hapus satu schedule event dari Firestore
  static Future<void> deleteScheduleEvent(int eventId) async {
    if (!AuthService.isLoggedIn) return;
    try {
      await _userDoc.collection('schedule_events').doc(eventId.toString()).delete();
      print('[CloudSync] ✅ Schedule event $eventId deleted from Firestore');
    } catch (e) {
      print('[CloudSync] ⚠️ Delete schedule event failed: $e');
    }
  }

  /// Sync body measurements → Firestore
  static Future<void> syncBodyMeasurementsToCloud() async {
    if (!AuthService.isLoggedIn) return;
    try {
      final db = await _db.database;
      
      final deleted = await db.query('deleted_records', where: 'table_name = ?', whereArgs: ['body_measurements']);
      if (deleted.isNotEmpty) {
        final deleteBatch = _firestore.batch();
        for (final row in deleted) {
          deleteBatch.delete(_userDoc.collection('body_measurements').doc(row['record_id'].toString()));
        }
        await deleteBatch.commit();
        final deletedIds = deleted.map((e) => e['id'] as int).toList();
        final placeholders = deletedIds.map((_) => '?').join(',');
        await db.delete('deleted_records', where: 'id IN ($placeholders)', whereArgs: deletedIds);
      }

      final measurements = await db.query('body_measurements', where: 'is_synced = 0 OR is_synced IS NULL');
      if (measurements.isEmpty) return;

      final batch = _firestore.batch();
      for (final m in measurements) {
        batch.set(
          _userDoc.collection('body_measurements').doc(m['id'].toString()),
          Map<String, dynamic>.from(m)..remove('is_synced'),
        );
      }
      await batch.commit();
      
      final ids = measurements.map((e) => e['id'] as int).toList();
      await _db.markAsSynced('body_measurements', ids);
      print('[CloudSync] ✅ Body measurements synced: ${measurements.length}');
    } catch (e) {
      print('[CloudSync] ⚠️ Body measurement sync failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SYNC DOWN — Restore Firestore → SQLite (saat login di device baru)
  // ─────────────────────────────────────────────────────────────────────────

  /// Cek apakah SQLite lokal kosong (belum ada data untuk user ini)
  /// Mengecek SEMUA koleksi utama — jika salah satu ada data cloud, perlu restore
  static Future<bool> isLocalDataEmpty() async {
    try {
      final workouts = await _db.getAllWorkouts();
      if (workouts.isNotEmpty) return false;

      final db = await _db.database;
      final schedules = await db.query('schedule_events', limit: 1);
      if (schedules.isNotEmpty) return false;

      final nutrition = await db.query('protein_entries', limit: 1);
      if (nutrition.isNotEmpty) return false;

      return true;
    } catch (_) {
      return true;
    }
  }

  /// Restore semua data dari Firestore ke SQLite lokal.
  /// Selalu dijalankan saat login — data cloud SELALU menang (merge strategy).
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
      // Also clean workout_photos table
      await db.delete('workout_photos');

      for (final doc in snapshot.docs) {
        final map = Map<String, dynamic>.from(doc.data());
        map.remove('id');
        try {
          final localId = await db.insert('workouts', map);

          // Restore photos subcollection for this workout
          final photosSnap = await doc.reference.collection('photos').get();
          for (final photoDoc in photosSnap.docs) {
            final photoMap = Map<String, dynamic>.from(photoDoc.data());
            photoMap.remove('id');
            photoMap['workout_id'] = localId; // Relink ke ID lokal baru
            try {
              await db.insert('workout_photos', photoMap);
            } catch (_) {}
          }
        } catch (_) {}
      }
      print('[CloudSync] ✅ Workouts + photos restored from Firestore');
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
  // MAP SNAPSHOT — Compress & convert to Base64 using background Isolate
  // ─────────────────────────────────────────────────────────────────────────

  /// Takes raw PNG bytes from GoogleMapController.takeSnapshot(),
  /// crops to 16:9, compresses as JPEG, returns a Base64 string.
  /// Runs entirely on a background Isolate via compute() — zero UI lag.
  /// Returns null if processing fails (e.g. insufficient route data).
  static Future<String?> compressMapSnapshotToBase64(Uint8List rawBytes) async {
    try {
      return await compute(_cropAndCompressToBase64, rawBytes);
    } catch (e) {
      debugPrint('[CloudSync] ⚠️ Map snapshot compression failed: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BACKWARD COMPAT — Stubs untuk kode lama
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> restoreProfile() async => false; // Sekarang ditangani ProfileService
  static Future<void> restoreDataFromCloud() => restoreAllFromCloud();
}
