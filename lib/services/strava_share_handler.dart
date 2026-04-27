import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/workout.dart';
import '../services/strava_service.dart';
import '../services/database_helper.dart';
import '../services/profile_service.dart';

/// Service untuk menangani incoming share dari Strava
/// Skenario: User lari pakai Strava → tap Share → pilih Kora → auto-import
class StravaShareHandler {
  static final StravaShareHandler _instance = StravaShareHandler._();
  StravaShareHandler._();
  static StravaShareHandler get instance => _instance;

  // Regex untuk mendeteksi URL aktivitas Strava
  // Format: https://www.strava.com/activities/1234567890
  static final _stravaActivityUrlRegex = RegExp(
    r'strava\.com/activities/(\d+)',
    caseSensitive: false,
  );

  /// Ekstrak activity ID dari teks yang di-share
  /// Strava biasanya share teks seperti:
  /// "Morning Run - 5.2 km https://www.strava.com/activities/12345678"
  /// atau langsung URL: "https://www.strava.com/activities/12345678"
  static int? extractActivityId(String text) {
    final match = _stravaActivityUrlRegex.firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  /// Proses & import aktivitas dari Strava berdasarkan ID
  static Future<ImportResult> importActivityById(int activityId,
      {double userWeight = 70.0}) async {
    // Cek apakah sudah terhubung ke Strava
    final connected = await StravaService.isConnected;
    if (!connected) {
      return ImportResult.needsAuth;
    }

    // Fetch detail aktivitas dari API Strava
    final detail = await StravaService.getActivityDetail(activityId);
    if (detail == null) {
      return ImportResult.fetchFailed;
    }

    // Pastikan ini aktivitas lari
    final sportType = detail['sport_type'] as String? ?? detail['type'] as String? ?? '';
    if (!sportType.toLowerCase().contains('run')) {
      return ImportResult.notARun;
    }

    // Ambil semua field
    final double distanceM = (detail['distance'] as num?)?.toDouble() ?? 0.0;
    final int movingTimeSec = (detail['moving_time'] as num?)?.toInt() ?? 0;
    final int elapsedTimeSec = (detail['elapsed_time'] as num?)?.toInt() ?? 0;
    final double elevationGain =
        (detail['total_elevation_gain'] as num?)?.toDouble() ?? 0.0;
    final double maxElev = (detail['elev_high'] as num?)?.toDouble() ?? 0.0;
    final String name = detail['name'] as String? ?? 'Lari via Strava';

    if (distanceM < 10) return ImportResult.tooShort;

    // Polyline rute
    final mapObj = detail['map'] as Map<String, dynamic>?;
    final polylineStr = mapObj?['polyline'] as String? ??
        mapObj?['summary_polyline'] as String? ?? '';

    // Splits per km
    String? splitsJson;
    final rawSplits = detail['splits_metric'] as List<dynamic>?;
    if (rawSplits != null) {
      final splits = rawSplits.map((s) {
        final dist = (s['distance'] as num?)?.toDouble() ?? 1000.0;
        final sec = (s['moving_time'] as num?)?.toInt() ?? 0;
        final pace = StravaService.formatPace(dist, sec);
        return '$pace /km';
      }).toList();
      splitsJson = jsonEncode(splits);
    }

    final durationMinutes = elapsedTimeSec / 60.0;
    final distanceKm = distanceM / 1000.0;
    final calories = Workout.calculateCalories('running', durationMinutes);
    final protein = Workout.calculateProteinNeeded(
      'running',
      durationMinutes,
      weight: userWeight,
    );

    DateTime date;
    try {
      date = DateTime.parse(detail['start_date_local'] as String? ??
          DateTime.now().toIso8601String());
    } catch (_) {
      date = DateTime.now();
    }

    final workout = Workout(
      type: 'running',
      duration: durationMinutes,
      distance: distanceKm,
      caloriesBurned: calories,
      proteinNeeded: protein,
      date: date,
      title: name,
      notes: 'Diimport dari Strava. Jarak: ${distanceKm.toStringAsFixed(2)} km',
      movingTime: movingTimeSec / 60.0,
      elevationGain: elevationGain,
      maxElevation: maxElev,
      splitsStr: splitsJson,
      polyline: polylineStr.isNotEmpty ? polylineStr : null,
    );

    await DatabaseHelper().insertWorkout(workout);
    return ImportResult.success(
      activityName: name,
      distanceKm: distanceKm,
      durationSec: elapsedTimeSec,
    );
  }
}

/// Hasil import
abstract class ImportResult {
  const ImportResult();

  static const needsAuth = _NeedsAuth();
  static const fetchFailed = _FetchFailed();
  static const notARun = _NotARun();
  static const tooShort = _TooShort();
  static ImportResult success({
    required String activityName,
    required double distanceKm,
    required int durationSec,
  }) =>
      _Success(
        activityName: activityName,
        distanceKm: distanceKm,
        durationSec: durationSec,
      );
}

class _Success extends ImportResult {
  final String activityName;
  final double distanceKm;
  final int durationSec;
  _Success({
    required this.activityName,
    required this.distanceKm,
    required this.durationSec,
  });
}

class _NeedsAuth extends ImportResult {
  const _NeedsAuth();
}

class _FetchFailed extends ImportResult {
  const _FetchFailed();
}

class _NotARun extends ImportResult {
  const _NotARun();
}

class _TooShort extends ImportResult {
  const _TooShort();
}

// ── Widget: Overlay / Dialog yang muncul saat share masuk ─────────────────────
class StravaShareOverlay extends StatefulWidget {
  final String sharedText;
  final VoidCallback? onConnectStrava;

  const StravaShareOverlay({
    super.key,
    required this.sharedText,
    this.onConnectStrava,
  });

  @override
  State<StravaShareOverlay> createState() => _StravaShareOverlayState();
}

class _StravaShareOverlayState extends State<StravaShareOverlay> {
  _State _state = _State.detecting;
  String _message = 'Mendeteksi aktivitas Strava...';
  ImportResult? _result;
  double _userWeight = 70.0;

  @override
  void initState() {
    super.initState();
    _process();
  }

  Future<void> _process() async {
    final activityId = StravaShareHandler.extractActivityId(widget.sharedText);
    if (activityId == null) {
      setState(() {
        _state = _State.error;
        _message = 'Tidak ada link aktivitas Strava yang ditemukan.\n\n'
            'Pastikan kamu share link aktivitas dari Strava.';
      });
      return;
    }

    setState(() {
      _state = _State.importing;
      _message = 'Mengambil data aktivitas...';
    });

    final profile = await ProfileService.getProfile();
    _userWeight = (profile[ProfileService.keyWeight] as num?)?.toDouble() ?? 70.0;

    final result = await StravaShareHandler.importActivityById(
      activityId,
      userWeight: _userWeight,
    );

    _result = result;

    if (result is _Success) {
      setState(() {
        _state = _State.success;
        _message = 'Berhasil diimport!';
      });
    } else if (result is _NeedsAuth) {
      setState(() {
        _state = _State.needsAuth;
        _message = 'Hubungkan akun Strava terlebih dahulu.';
      });
    } else if (result is _NotARun) {
      setState(() {
        _state = _State.error;
        _message = 'Aktivitas ini bukan lari. Hanya aktivitas lari yang bisa diimport.';
      });
    } else {
      setState(() {
        _state = _State.error;
        _message = 'Gagal mengambil data dari Strava. Pastikan koneksi internet aktif.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF131929),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF2D3748),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFC5200).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_run,
                  color: Color(0xFFFC5200),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import dari Strava',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Kora',
                    style: TextStyle(
                      color: Color(0xFF39FF8F),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Status content
          if (_state == _State.detecting || _state == _State.importing) ...[
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: Color(0xFFFC5200),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _message,
              style: const TextStyle(color: Color(0xFF8892A4), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ] else if (_state == _State.success && _result is _Success) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D3320),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF39FF8F).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text('✅', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  Text(
                    (_result as _Success).activityName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _miniStat(
                        '${(_result as _Success).distanceKm.toStringAsFixed(2)} km',
                        'Jarak',
                      ),
                      _miniStat(
                        StravaService.formatDuration(
                            (_result as _Success).durationSec),
                        'Durasi',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Aktivitas berhasil disimpan ke riwayat Kora! ',
                    style: TextStyle(color: Color(0xFF39FF8F), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF39FF8F),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Tutup',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ] else if (_state == _State.needsAuth) ...[
            const Text('', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text(
              'Hubungkan akun Strava kamu terlebih dahulu agar Kora bisa mengambil data aktivitas.',
              style: TextStyle(color: Color(0xFF8892A4), fontSize: 14, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFC5200),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.link, size: 18),
                label: const Text(
                  'Hubungkan Strava',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onConnectStrava?.call();
                },
              ),
            ),
          ] else ...[
            // Error state
            const Text('⚠️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              _message,
              style: const TextStyle(
                  color: Color(0xFF8892A4), fontSize: 14, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF2D3748)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900)),
        Text(label,
            style: const TextStyle(color: Color(0xFF8892A4), fontSize: 11)),
      ],
    );
  }
}

enum _State { detecting, importing, success, needsAuth, error }
