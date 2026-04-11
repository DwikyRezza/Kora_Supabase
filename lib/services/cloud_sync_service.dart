import 'package:cloud_firestore/cloud_firestore.dart';
import 'database_helper.dart';
import 'auth_service.dart';

class CloudSyncService {
  static final _firestore = FirebaseFirestore.instance;
  static final _dbHelper = DatabaseHelper();

  /// Menyimpan seluruh data lokal ke Firebase Firestore
  static Future<void> backupToCloud() async {
    if (!AuthService.isLoggedIn) return;
    
    final uid = AuthService.uid;
    final userDoc = _firestore.collection('users').doc(uid);
    final db = await _dbHelper.database;
    
    // 1. Profil
    final profile = await _dbHelper.getUserProfile(uid);
    if (profile != null) {
      await userDoc.set({'profile': profile}, SetOptions(merge: true));
    }
    
    final batch = _firestore.batch();
    int opsCount = 0;
    
    Future<void> commitBatchIfFull(WriteBatch b) async {
       if (opsCount >= 400) {
          await b.commit();
          opsCount = 0;
       }
    }
    
    // 2. Workouts
    try {
      final workouts = await _dbHelper.getAllWorkouts();
      for (var w in workouts) {
        batch.set(userDoc.collection('workouts').doc(w.id.toString()), w.toMap());
        opsCount++;
        await commitBatchIfFull(batch);
      }
    } catch (e) {
      print("Error backing up workouts: $e");
    }
    
    // 3. Body Measurements
    try {
      final measurements = await _dbHelper.getAllBodyMeasurements();
      for (var m in measurements) {
        batch.set(userDoc.collection('body_measurements').doc(m.id.toString()), m.toMap());
        opsCount++;
        await commitBatchIfFull(batch);
      }
    } catch (e) {
      // Ignore
    }
    
    // 4. Protein Entries
    try {
      final proteinsMap = await db.query('protein_entries');
      for (var map in proteinsMap) {
        batch.set(userDoc.collection('protein_entries').doc(map['id'].toString()), map);
        opsCount++;
        await commitBatchIfFull(batch);
      }
    } catch (e) {}
    
    // 5. Schedule
    try {
      final schedulesMap = await db.query('schedule_events');
      for (var map in schedulesMap) {
        batch.set(userDoc.collection('schedule_events').doc(map['id'].toString()), map);
        opsCount++;
        await commitBatchIfFull(batch);
      }
    } catch (e) {}
    
    if (opsCount > 0) {
      await batch.commit();
    }
  }

  /// Mengambil kembali profil user saja
  static Future<bool> restoreProfile() async {
    if (!AuthService.isLoggedIn) return false;
    final uid = AuthService.uid;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data()!.containsKey('profile')) {
        final profile = doc.data()!['profile'] as Map<String, dynamic>;
        await _dbHelper.upsertUserProfile(profile);
        return true;
      }
    } catch (e) {
      print("Error restoring profile: $e");
    }
    return false;
  }

  /// Memulihkan semua data dari Firebase Cloud Firestore ke lokal DB
  static Future<void> restoreDataFromCloud() async {
    if (!AuthService.isLoggedIn) return;
    
    final uid = AuthService.uid;
    final userDoc = _firestore.collection('users').doc(uid);
    final db = await _dbHelper.database;
    
    try {
      await db.transaction((txn) async {
        // Workouts
        final wokroutsSnap = await userDoc.collection('workouts').get();
        if (wokroutsSnap.docs.isNotEmpty) {
          await txn.delete('workouts'); 
          for (var doc in wokroutsSnap.docs) {
            await txn.insert('workouts', doc.data());
          }
        }
        
        // Body Measurements
        final bodySnap = await userDoc.collection('body_measurements').get();
        if (bodySnap.docs.isNotEmpty) {
          await txn.delete('body_measurements');
          for (var doc in bodySnap.docs) {
            await txn.insert('body_measurements', doc.data());
          }
        }
        
        // Protein
        final proteinSnap = await userDoc.collection('protein_entries').get();
        if (proteinSnap.docs.isNotEmpty) {
          await txn.delete('protein_entries');
          for (var doc in proteinSnap.docs) {
            await txn.insert('protein_entries', doc.data());
          }
        }
        
        // Schedule
        final scheduleSnap = await userDoc.collection('schedule_events').get();
        if (scheduleSnap.docs.isNotEmpty) {
          await txn.delete('schedule_events');
          for (var doc in scheduleSnap.docs) {
            await txn.insert('schedule_events', doc.data());
          }
        }
      });
    } catch (e) {
      print("Error restoring all data: $e");
    }
  }
}
