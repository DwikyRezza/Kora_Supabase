import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout.dart';
import '../services/strava_service.dart';
import '../services/database_helper.dart';
import '../services/profile_service.dart';

class StravaImportScreen extends StatefulWidget {
  const StravaImportScreen({super.key});

  @override
  State<StravaImportScreen> createState() => _StravaImportScreenState();
}

class _StravaImportScreenState extends State<StravaImportScreen> {
  bool _isConnected = false;
  bool _isLoading = true;
  bool _isConnecting = false;
  List<Map<String, dynamic>> _activities = [];
  final Set<int> _importedIds = {};
  double _userWeight = 70.0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final profile = await ProfileService.getProfile();
    _userWeight = (profile[ProfileService.keyWeight] as num?)?.toDouble() ?? 70.0;
    final connected = await StravaService.isConnected;
    setState(() => _isConnected = connected);
    if (connected) await _loadActivities();
    setState(() => _isLoading = false);
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    final acts = await StravaService.getRecentRunActivities();
    setState(() {
      _activities = acts;
      _isLoading = false;
    });
  }

  Future<void> _connectStrava() async {
    setState(() => _isConnecting = true);
    try {
      final success = await StravaService.connectStrava();
      if (!mounted) return;
      if (success) {
        setState(() {
          _isConnected = true;
          _isConnecting = false;
        });
        await _loadActivities();
      } else {
        // User membatalkan / menutup browser
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login dibatalkan.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on StravaTokenExpiredException {
      if (!mounted) return;
      setState(() => _isConnecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi Strava kadaluwarsa. Silakan hubungkan ulang.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConnecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importActivity(Map<String, dynamic> activity) async {
    final int id = activity['id'];
    // Fetch detail untuk mendapatkan polyline yang lebih akurat
    final detail = await StravaService.getActivityDetail(id) ?? activity;

    final double distanceM = (detail['distance'] as num?)?.toDouble() ?? 0.0;
    final int movingTimeSec = (detail['moving_time'] as num?)?.toInt() ?? 0;
    final int elapsedTimeSec = (detail['elapsed_time'] as num?)?.toInt() ?? 0;
    final double elevationGain =
        (detail['total_elevation_gain'] as num?)?.toDouble() ?? 0.0;
    final double maxElev =
        (detail['elev_high'] as num?)?.toDouble() ?? 0.0;
    final String name = detail['name'] as String? ?? 'Lari via Strava';

    // Polyline — ambil dari map object
    final mapObj = detail['map'] as Map<String, dynamic>?;
    final polylineStr = mapObj?['polyline'] as String? ??
        mapObj?['summary_polyline'] as String? ?? '';

    // Splits per km dari Strava (jika ada)
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

    if (distanceKm < 0.01) {
      _showSnack('Aktivitas terlalu pendek, dilewati.');
      return;
    }

    final calories = Workout.calculateCalories('running', durationMinutes);
    final protein = Workout.calculateProteinNeeded(
      'running',
      durationMinutes,
      weight: _userWeight,
    );

    // Parse tanggal
    DateTime date;
    try {
      date = DateTime.parse(
          detail['start_date_local'] as String? ?? DateTime.now().toIso8601String());
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
    setState(() => _importedIds.add(id));

    if (mounted) {
      _showSnack('✅ "$name" berhasil diimport!');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        title: Row(
          children: [
            Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/c/cb/Strava_Logo.svg',
              height: 22,
              errorBuilder: (_, __, ___) => const Text(
                'Strava',
                style: TextStyle(
                  color: Color(0xFFFC5200),
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              '× Corefit',
              style: TextStyle(
                color: Color(0xFF39FF8F),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          if (_isConnected)
            TextButton.icon(
              onPressed: () async {
                await StravaService.disconnect();
                setState(() {
                  _isConnected = false;
                  _activities.clear();
                });
              },
              icon: const Icon(Icons.link_off, color: Colors.redAccent, size: 16),
              label: const Text('Putuskan',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFC5200)),
            )
          : !_isConnected
              ? _buildConnectPage()
              : _buildActivityList(),
    );
  }

  // ── Halaman Connect Strava ────────────────────────────────────────────
  Widget _buildConnectPage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Strava logo / icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFFC5200).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFC5200).withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Text('', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Hubungkan Strava',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Lari menggunakan Strava, lalu import data aktivitasmu langsung ke Corefit.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8892A4),
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131929),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2D3748)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _featureRow(Icons.straighten, 'Jarak & Pace'),
                  const SizedBox(height: 8),
                  _featureRow(Icons.timer_outlined, 'Waktu bergerak & total'),
                  const SizedBox(height: 8),
                  _featureRow(Icons.terrain, 'Elevasi & rute peta'),
                  const SizedBox(height: 8),
                  _featureRow(Icons.bar_chart, 'Splits per kilometer'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFC5200),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: _isConnecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.link, size: 20),
                label: Text(
                  _isConnecting ? 'Menghubungkan...' : 'Hubungkan dengan Strava',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: _isConnecting ? null : _connectStrava,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFC5200), size: 18),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
      ],
    );
  }

  // ── Daftar Aktivitas ──────────────────────────────────────────────────
  Widget _buildActivityList() {
    if (_activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_run, color: Colors.grey[700], size: 56),
            const SizedBox(height: 16),
            const Text(
              'Tidak ada aktivitas lari\ndalam 90 hari terakhir',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8892A4), fontSize: 15),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadActivities,
              icon: const Icon(Icons.refresh),
              label: const Text('Muat Ulang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFC5200),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadActivities,
      color: const Color(0xFFFC5200),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.directions_run,
                      color: Color(0xFFFC5200), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${_activities.length} aktivitas lari (90 hari terakhir)',
                    style: const TextStyle(
                        color: Color(0xFF8892A4), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildActivityCard(_activities[i]),
                childCount: _activities.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> act) {
    final int id = act['id'] as int? ?? 0;
    final String name = act['name'] as String? ?? 'Lari';
    final double distM = (act['distance'] as num?)?.toDouble() ?? 0.0;
    final int movingSec = (act['moving_time'] as num?)?.toInt() ?? 0;
    final int elapsedSec = (act['elapsed_time'] as num?)?.toInt() ?? 0;
    final double elev = (act['total_elevation_gain'] as num?)?.toDouble() ?? 0.0;
    final String pace = StravaService.formatPace(distM, movingSec);
    final String dist = StravaService.formatDistance(distM);
    final String duration = StravaService.formatDuration(elapsedSec);
    final bool alreadyImported = _importedIds.contains(id);

    DateTime? date;
    try {
      date = DateTime.parse(act['start_date_local'] as String? ?? '');
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alreadyImported
              ? const Color(0xFF39FF8F).withValues(alpha: 0.5)
              : const Color(0xFF2D3748),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFC5200).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.directions_run,
                      color: Color(0xFFFC5200), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (date != null)
                        Text(
                          DateFormat('EEEE, d MMMM yyyy • HH:mm', 'id')
                              .format(date),
                          style: const TextStyle(
                              color: Color(0xFF8892A4), fontSize: 11),
                        ),
                    ],
                  ),
                ),
                if (alreadyImported)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF39FF8F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF39FF8F).withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      '✓ Diimport',
                      style: TextStyle(
                        color: Color(0xFF39FF8F),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statChip('Jarak', dist, Icons.straighten),
                _divider(),
                _statChip('Pace', '$pace /km', Icons.speed),
                _divider(),
                _statChip('Waktu', duration, Icons.timer_outlined),
                _divider(),
                _statChip(
                    'Elevasi', '${elev.toStringAsFixed(0)}m', Icons.terrain),
              ],
            ),
          ),

          // Import button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: alreadyImported
                      ? const Color(0xFF39FF8F).withValues(alpha: 0.15)
                      : const Color(0xFFFC5200),
                  foregroundColor:
                      alreadyImported ? const Color(0xFF39FF8F) : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: alreadyImported
                        ? BorderSide(
                            color: const Color(0xFF39FF8F).withValues(alpha: 0.3))
                        : BorderSide.none,
                  ),
                  elevation: 0,
                ),
                icon: Icon(
                  alreadyImported ? Icons.check_circle_outline : Icons.download,
                  size: 18,
                ),
                label: Text(
                  alreadyImported ? 'Sudah Diimport' : 'Import ke Corefit',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                onPressed: alreadyImported ? null : () => _importActivity(act),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF8892A4), size: 14),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8892A4), fontSize: 10),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 32,
      color: const Color(0xFF2D3748),
    );
  }
}
