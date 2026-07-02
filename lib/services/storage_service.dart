import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class StorageService {
  static final _firestore = FirebaseFirestore.instance;

  /// Meminta signature dari Vercel lalu meng-upload foto profil langsung ke Cloudinary
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
      print('[StorageService] Meminta signature dari Vercel...');
      final vercelUrl = dotenv.env['VERCEL_URL'];
      if (vercelUrl == null || vercelUrl.isEmpty) {
        throw Exception('VERCEL_URL is not defined in .env');
      }

      final sigRes = await http.get(Uri.parse('$vercelUrl/api/cloudinary-signature'));
      if (sigRes.statusCode != 200) {
        throw Exception('Failed to get signature from Vercel: ${sigRes.body}');
      }

      final sigData = jsonDecode(sigRes.body);
      final signature = sigData['signature'];
      final timestamp = sigData['timestamp'].toString();
      final cloudName = sigData['cloudName'];
      final apiKey = sigData['apiKey'];

      print('[StorageService] Uploading image to Cloudinary ($cloudName)...');
      
      final uploadUrl = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uploadUrl)
        ..fields['api_key'] = apiKey
        ..fields['timestamp'] = timestamp
        ..fields['signature'] = signature
        ..fields['folder'] = 'kora_app'
        ..files.add(await http.MultipartFile.fromPath('file', localFilePath));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        throw Exception('Cloudinary upload failed: $responseBody');
      }

      final cloudinaryData = jsonDecode(responseBody);
      final secureUrl = cloudinaryData['secure_url'];

      // Simpan URL ke Firestore
      final uid = AuthService.uid;
      await _firestore.collection('users').doc(uid).set(
        {'photoUrl': secureUrl, 'photoBase64': FieldValue.delete()},
        SetOptions(merge: true),
      );

      print('[StorageService] ✅ Foto tersimpan di Cloudinary: $secureUrl');
      return secureUrl;
    } catch (e) {
      print('[StorageService] ❌ Error upload: $e');
      return null;
    }
  }

  /// Ambil foto profil dari Firestore
  static Future<String?> getProfilePhotoDataUri() async {
    if (!AuthService.isLoggedIn) return null;
    try {
      final uid = AuthService.uid;
      final doc = await _firestore.collection('users').doc(uid).get();
      
      // Ambil Cloudinary URL (photoUrl)
      final url = doc.data()?['photoUrl'] as String?;
      if (url != null && url.isNotEmpty) return url;
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
      await _firestore.collection('users').doc(uid).update({
        'photoUrl': FieldValue.delete(),
        'photoBase64': FieldValue.delete()
      });
    } catch (e) {
      // Abaikan jika gagal
    }
  }
}
