import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout.dart';
import 'database_helper.dart';

class StravaService {
  static const String _baseUrl = 'https://www.strava.com/api/v3';
  static const String _tokenUrl = 'https://www.strava.com/oauth/token';

  static const String _clientId = '223195';
  static const String _clientSecret = '15d386f56ea6dbb7f7b5d730d88f85567b3020d1';

  static const String _prefAccessTokenKey = 'strava_access_token';
  static const String _prefRefreshTokenKey = 'strava_refresh_token';
  static const String _prefExpiresAtKey = 'strava_expires_at';

  // ── Hapus SEMUA token tersimpan (reset setup) ─────────────────────────
  static Future<void> clearAllTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefAccessTokenKey);
    await prefs.remove(_prefRefreshTokenKey);
    await prefs.remove(_prefExpiresAtKey);
  }

  // ── Cek apakah sudah ada refresh token yang tersimpan ─────────────────
  static Future<bool> hasRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_prefRefreshTokenKey);
  }

  // ── Simpan refresh token baru dari input user ─────────────────────────
  // Langsung verifikasi dengan menukarnya ke access token baru
  static Future<void> saveRefreshToken(String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefRefreshTokenKey, refreshToken);
    // Validasi langsung
    await _refreshAccessToken(refreshToken);
  }

  // ── Dapatkan Access Token yang valid (auto-refresh jika diperlukan) ────
  static Future<String> getValidAccessToken() async {
    final prefs = await SharedPreferences.getInstance();

    final accessToken = prefs.getString(_prefAccessTokenKey);
    final expiresAt = prefs.getInt(_prefExpiresAtKey);
    final refreshToken = prefs.getString(_prefRefreshTokenKey);

    // Jika belum ada refresh token sama sekali
    if (refreshToken == null) {
      throw const _NoRefreshTokenException();
    }

    // Cek apakah access token masih valid (dengan buffer 60 detik)
    if (accessToken != null && expiresAt != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now < expiresAt - 60) {
        return accessToken;
      }
    }

    // Access token expired atau belum ada, refresh sekarang
    return await _refreshAccessToken(refreshToken);
  }

  // ── Tukar refresh token dengan access token baru ──────────────────────
  static Future<String> _refreshAccessToken(String refreshToken) async {
    http.Response response;

    try {
      response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception('Tidak dapat terhubung ke Strava. Periksa koneksi internet. ($e)');
    }

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      await _saveTokens(data);
      return data['access_token'] as String;
    } else {
      // Refresh token tidak valid/kadaluwarsa — hapus semua dan minta ulang
      await clearAllTokens();

      String errMsg = 'Tidak diketahui';
      try {
        final body = json.decode(response.body);
        errMsg = body['message'] ?? body['errors']?.toString() ?? errMsg;
      } catch (_) {}

      throw const _InvalidRefreshTokenException();
    }
  }

  // ── Simpan semua token ke SharedPreferences ───────────────────────────
  static Future<void> _saveTokens(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefAccessTokenKey, data['access_token'] as String);
    // Strava kadang mengirim refresh_token baru, simpan jika ada
    if (data.containsKey('refresh_token')) {
      await prefs.setString(_prefRefreshTokenKey, data['refresh_token'] as String);
    }
    await prefs.setInt(_prefExpiresAtKey, data['expires_at'] as int);
  }

  // ── Tarik aktivitas terbaru dari Strava dan simpan ke DB ──────────────
  static Future<int> importRecentActivities() async {
    final accessToken = await getValidAccessToken();

    http.Response response;
    try {
      response = await http.get(
        Uri.parse('$_baseUrl/athlete/activities?per_page=20'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 20));
    } catch (e) {
      throw Exception('Gagal terhubung ke Strava API: $e');
    }

    if (response.statusCode != 200) {
      String errMsg = 'HTTP ${response.statusCode}';
      try {
        final body = json.decode(response.body);
        errMsg = body['message'] ?? errMsg;
      } catch (_) {}
      throw Exception('Strava API Error: $errMsg');
    }

    final List<dynamic> data = json.decode(response.body);
    int imported = 0;
    final db = DatabaseHelper();

    // Cegah duplikat: kumpulkan notes yang sudah ada
    final existingWorkouts = await db.getRecentWorkouts(limit: 200);
    final existingNotes = existingWorkouts.map((w) => w.notes).toSet();

    for (final activity in data) {
      final activityId = activity['id']?.toString() ?? '';
      final activityName = (activity['name'] ?? 'Workout') as String;
      final notes = 'Strava#$activityId: $activityName';

      if (existingNotes.contains(notes)) continue;

      // Mapping tipe aktivitas Strava → AthleteSync
      String type = 'running';
      final stravaType = activity['type'] ?? activity['sport_type'] ?? '';
      if (stravaType == 'Walk') {
        type = 'walking';
      } else if (stravaType == 'WeightTraining' || stravaType == 'Workout') {
        type = 'weightlifting';
      } else if (stravaType == 'Ride' || stravaType == 'VirtualRide' || stravaType == 'EBikeRide') {
        type = 'cycling';
      } else if (stravaType == 'Hike') {
        type = 'hiking';
      }

      final durationMins = ((activity['elapsed_time'] as int? ?? 0)) / 60.0;
      final distanceKm = ((activity['distance'] as num?) ?? 0.0) / 1000.0;
      final date = DateTime.tryParse(activity['start_date_local'] as String? ?? '') ?? DateTime.now();

      final workout = Workout(
        type: type,
        duration: durationMins,
        distance: distanceKm,
        caloriesBurned: Workout.calculateCalories(type, durationMins),
        proteinNeeded: Workout.calculateProteinNeeded(type, durationMins, weight: 70.0),
        date: date,
        notes: notes,
        polyline: null,
      );

      await db.insertWorkout(workout);
      imported++;
    }

    return imported;
  }
}

// ── Exception Classes ─────────────────────────────────────────────────────

/// Belum ada refresh token (belum setup)
class _NoRefreshTokenException implements Exception {
  const _NoRefreshTokenException();
}

/// Refresh token yang tersimpan tidak valid / sudah kadaluwarsa
class _InvalidRefreshTokenException implements Exception {
  const _InvalidRefreshTokenException();
}
