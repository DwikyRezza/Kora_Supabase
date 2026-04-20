import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

class StorageService {
  static final _firestore = FirebaseFirestore.instance;

  /// Upload foto profil dengan menyimpan sebagai base64 string di Firestore.
  /// Tidak membutuhkan Firebase Storage Rules.
  /// Return: data URI "data:image/jpeg;base64,..." yang bisa langsung dipakai sebagai URL
  static Future<String?> uploadProfilePhoto(String localFilePath) async {
    if (!AuthService.isLoggedIn) {
      print('[StorageService] User belum login, skip upload.');
      return null;
    }

    final file = File(localFilePath);
    if (!file.existsSync()) {
      print('[StorageService] File tidak ditemukan: $localFilePath');
      return null;
    }

    try {
      print('[StorageService] Mengkonversi foto ke base64...');
      final bytes = await file.readAsBytes();

      // Batasi ukuran: jika > 200KB, kompresi lebih kecil
      if (bytes.length > 200 * 1024) {
        print('[StorageService] File terlalu besar: ${bytes.length} bytes. Pastikan maxWidth/maxHeight sudah di-set.');
      }

      final base64Str = base64Encode(bytes);
      final dataUri = 'data:image/jpeg;base64,$base64Str';

      // Simpan ke Firestore (field terpisah agar tidak ganggu query profil)
      final uid = AuthService.uid;
      await _firestore.collection('users').doc(uid).set(
        {'photoBase64': base64Str},
        SetOptions(merge: true),
      );

      print('[StorageService] ✅ Foto tersimpan ke Firestore sebagai base64 (${bytes.length} bytes).');
      return dataUri; // kembalikan data URI untuk ditampilkan langsung
    } catch (e) {
      print('[StorageService] ❌ Error upload: $e');
      return null;
    }
  }

  /// Ambil foto profil dari Firestore (base64) → data URI
  static Future<String?> getProfilePhotoDataUri() async {
    if (!AuthService.isLoggedIn) return null;
    try {
      final uid = AuthService.uid;
      final doc = await _firestore.collection('users').doc(uid).get();
      final base64Str = doc.data()?['photoBase64'] as String?;
      if (base64Str != null && base64Str.isNotEmpty) {
        return 'data:image/jpeg;base64,$base64Str';
      }
    } catch (e) {
      print('[StorageService] Error get photo: $e');
    }
    return null;
  }

  /// Hapus foto profil dari Firestore
  static Future<void> deleteProfilePhoto() async {
    if (!AuthService.isLoggedIn) return;
    try {
      final uid = AuthService.uid;
      await _firestore.collection('users').doc(uid).update({'photoBase64': FieldValue.delete()});
    } catch (e) {
      // Abaikan jika gagal
    }
  }
}
