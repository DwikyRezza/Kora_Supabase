import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../services/database_helper.dart';
import '../services/strava_service.dart';
import '../services/auth_service.dart';
import '../models/schedule_event.dart';
import '../services/profile_service.dart';
import '../services/storage_service.dart';
import 'dart:convert';
import 'profile_screen.dart';
import 'landing_screen.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _darkMode = true;
  bool _notifWorkout = true;
  bool _notifProgress = true;
  bool _notifStrava = false;
  bool _notifHydration = false;
  bool _metricUnit = true;
  bool _isLoading = true;
  bool _stravaConnected = false;
  bool _stravaSyncing = false;
  int _advanceMinutes = 30;
  String _dataSource = 'corefit';
  String _language = 'id';

  TimeOfDay _progressTime = const TimeOfDay(hour: 8, minute: 0);
  int _progressWeekday = DateTime.monday;
  List<ScheduleEvent> _upcomingEvents = [];
  Map<String, dynamic> _profile = {};
  bool _whistleAlarm = true;
  bool _notif1800 = true;
  String? _customPhotoDataUri;

  final _db = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final darkMode = await SettingsService.getDarkMode();
    final notifWorkout = await SettingsService.getNotifWorkout();
    final notifProgress = await SettingsService.getNotifProgress();
    final notifStrava = await SettingsService.getNotifStrava();
    final notifHydration = await SettingsService.getNotifHydration();
    final metricUnit = await SettingsService.getMetricUnit();
    final advanceMinutes = await SettingsService.getWorkoutAdvanceMinutes();
    final progressTime = await SettingsService.getProgressTime();
    final progressWeekday = await SettingsService.getProgressWeekday();
    final events = await _db.getUpcomingEvents();
    final stravaConnected = await StravaService.isConnected;
    final language = await SettingsService.getLanguage();
    final whistleAlarm = await SettingsService.getWhistleAlarm();
    final notif1800 = await SettingsService.getNotif1800();
    final profile = await ProfileService.getProfile();
    final customPhotoDataUri = await StorageService.getProfilePhotoDataUri();

    if (mounted) {
      setState(() {
        _darkMode = darkMode;
        _notifWorkout = notifWorkout;
        _notifProgress = notifProgress;
        _notifStrava = notifStrava;
        _notifHydration = notifHydration;
        _metricUnit = metricUnit;
        _advanceMinutes = advanceMinutes;
        _progressTime = progressTime;
        _progressWeekday = progressWeekday;
        _upcomingEvents = events;
        _stravaConnected = stravaConnected;
        _language = language;
        _whistleAlarm = whistleAlarm;
        _notif1800 = notif1800;
        _profile = profile;
        _customPhotoDataUri = customPhotoDataUri;
        _isLoading = false;
      });
    }
  }

  // ── Dark Mode ─────────────────────────────────────────────────────────────
  void _onDarkModeChanged(bool value) {
    setState(() => _darkMode = value);
    SettingsService.setDarkMode(value);
    _showFeedback(
        value ? ' Mode Gelap diaktifkan' : ' Mode Terang diaktifkan');
  }

  // ── Master switch: Pengingat Jadwal ───────────────────────────────────────
  void _onNotifWorkoutChanged(bool value) async {
    setState(() => _notifWorkout = value);
    await SettingsService.setNotifWorkout(value);

    if (value) {
      // Jadwalkan ulang SEMUA event mendatang sesuai advance notice saat ini
      await NotificationService().rescheduleAllEvents(
        _upcomingEvents,
        advanceMinutes: _advanceMinutes,
      );
      _showFeedback(
        ' Pengingat jadwal diaktifkan (${SettingsService.advanceLabel(_advanceMinutes)})',
      );
    } else {
      // Batalkan semua notif jadwal
      for (final e in _upcomingEvents) {
        if (e.id != null) {
          await NotificationService().cancelEventReminder(e.id!);
        }
      }
      _showFeedback(' Semua pengingat jadwal dimatikan');
    }
  }

  // ── Advance notice picker ─────────────────────────────────────────────────
  Future<void> _pickAdvanceNotice() async {
    final picked = await _showAdvancePicker(_advanceMinutes);
    if (picked == null || !mounted) return;

    setState(() => _advanceMinutes = picked);
    await SettingsService.setWorkoutAdvanceMinutes(picked);

    if (_notifWorkout) {
      await NotificationService().rescheduleAllEvents(
        _upcomingEvents,
        advanceMinutes: picked,
      );
      _showFeedback(
          '✅ Pengingat diperbarui: ${SettingsService.advanceLabel(picked)}');
    }
  }

  // ── Notif Progress ────────────────────────────────────────────────────────
  void _onNotifProgressChanged(bool value) async {
    setState(() => _notifProgress = value);
    await SettingsService.setNotifProgress(value);
    if (value) {
      await _rescheduleProgress();
      _showFeedback(
        ' Laporan diaktifkan (${SettingsService.weekdayName(_progressWeekday)}, ${_fmtTime(_progressTime)})',
      );
    } else {
      await NotificationService().cancelWeeklyProgressReminder();
      _showFeedback(' Laporan mingguan dimatikan');
    }
  }

  Future<void> _pickProgressTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _progressTime,
      helpText: 'PILIH JAM LAPORAN MINGGUAN',
      builder: (ctx, child) => _timePickerTheme(ctx, child),
    );
    if (picked == null || !mounted) return;
    setState(() => _progressTime = picked);
    await SettingsService.setProgressTime(picked);
    if (_notifProgress) {
      await _rescheduleProgress();
      _showFeedback('✅ Jam laporan diperbarui: ${_fmtTime(picked)}');
    }
  }

  Future<void> _pickProgressWeekday() async {
    final picked = await _showWeekdayPicker(_progressWeekday);
    if (picked == null || !mounted) return;
    setState(() => _progressWeekday = picked);
    await SettingsService.setProgressWeekday(picked);
    if (_notifProgress) {
      await _rescheduleProgress();
      _showFeedback('✅ Hari laporan: ${SettingsService.weekdayName(picked)}');
    }
  }

  Future<void> _rescheduleProgress() async {
    await NotificationService().cancelWeeklyProgressReminder();
    await NotificationService().scheduleWeeklyProgressReminder(
      weekday: _progressWeekday,
      hour: _progressTime.hour,
      minute: _progressTime.minute,
    );
  }

  // ── Strava ────────────────────────────────────────────────────────────────
  void _onNotifStravaChanged(bool value) async {
    setState(() => _notifStrava = value);
    await SettingsService.setNotifStrava(value);
    _showFeedback(value ? ' Notifikasi Strava aktif' : ' Notifikasi Strava nonaktif');
  }

  void _onNotifHydrationChanged(bool value) async {
    setState(() => _notifHydration = value);
    await SettingsService.setNotifHydration(value);
    _showFeedback(value ? 'Pengingat minum air aktif' : 'Pengingat minum air nonaktif');
  }

  Future<void> _connectStrava() async {
    try {
      final ok = await StravaService.connectStrava();
      if (ok && mounted) { setState(() => _stravaConnected = true); _showFeedback('Strava berhasil terhubung!'); }
    } catch (e) { if (mounted) _showFeedback('Gagal: $e'); }
  }

  Future<void> _disconnectStrava() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Putuskan Strava?', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('Koneksi Strava akan diputus. Data yang sudah diimpor tidak dihapus.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Batal', style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed), child: const Text('Putuskan', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm == true) {
      await StravaService.disconnect();
      if (mounted) { setState(() => _stravaConnected = false); _showFeedback('Strava diputuskan'); }
    }
  }

  Future<void> _syncStrava() async {
    setState(() => _stravaSyncing = true);
    try {
      final count = await StravaService.importRecentActivities();
      if (mounted) _showFeedback('$count aktivitas diimpor dari Strava');
    } catch (e) {
      if (mounted) _showFeedback('Gagal sync: $e');
    } finally {
      if (mounted) setState(() => _stravaSyncing = false);
    }
  }

  Future<void> _showLanguagePicker() async {
    const opts = [('id', 'Bahasa Indonesia', '🇮🇩'), ('en', 'English', '🇬🇧'), ('system', 'Ikuti Sistem', '🌐')];
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Pilih Bahasa', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: opts.map((o) {
            final isSel = o.$1 == _language;
            return ListTile(
              onTap: () => Navigator.pop(ctx, o.$1),
              leading: Text(o.$3, style: const TextStyle(fontSize: 22)),
              title: Text(o.$2, style: TextStyle(color: isSel ? const Color(0xFFFC5200) : AppTheme.textPrimary, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500)),
              trailing: isSel ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFC5200)) : null,
            );
          }).toList(),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _language = picked);
      await SettingsService.setLanguage(picked);
      _showFeedback('Bahasa: ${SettingsService.languageLabel(picked)}');
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.warning_rounded, color: AppTheme.accentRed),
          const SizedBox(width: 8),
          Text('Hapus Akun?', style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.w700)),
        ]),
        content: Text('PERMANEN: semua data latihan, nutrisi, dan profil akan dihapus selamanya dan tidak dapat dipulihkan.', style: TextStyle(color: AppTheme.textSecondary, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Batal', style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            child: const Text('Hapus Permanen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        final uid = AuthService.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        await AuthService.signOut();
        if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LandingScreen()), (_) => false);
      } catch (e) {
        if (mounted) _showFeedback('Gagal hapus akun: $e');
      }
    }
  }

  Future<void> _exportData() async {
    _showFeedback('Fitur ekspor data segera hadir di versi berikutnya!');
  }

  // ── Satuan ────────────────────────────────────────────────────────────────
  void _onMetricUnitChanged(bool value) async {
    setState(() => _metricUnit = value);
    await SettingsService.setMetricUnit(value);
    _showFeedback(value ? 'Metrik (km, kg, cm)' : 'Imperial (mi, lbs, in)');
  }

  void _onWhistleAlarmChanged(bool value) async {
    setState(() => _whistleAlarm = value);
    await SettingsService.setWhistleAlarm(value);
    _showFeedback(value ? 'Alarm Peluit diaktifkan' : 'Alarm Peluit dimatikan');
  }

  void _onNotif1800Changed(bool value) async {
    setState(() => _notif1800 = value);
    await SettingsService.setNotif1800(value);
    _showFeedback(value ? 'Notifikasi 18:00 diaktifkan' : 'Notifikasi 18:00 dimatikan');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _showFeedback(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
      backgroundColor: AppTheme.surface,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.border),
      ),
      duration: const Duration(seconds: 2),
    ));
  }

  Widget _timePickerTheme(BuildContext ctx, Widget? child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFFFC5200),
            onPrimary: Colors.white,
            surface: AppTheme.surface,
            onSurface: AppTheme.textPrimary,
          ),
          dialogTheme: DialogThemeData(backgroundColor: AppTheme.surface),
        ),
        child: child!,
      );

  Future<int?> _showAdvancePicker(int current) async {
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Berapa menit sebelum jadwal?',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SettingsService.advanceOptions.map((minutes) {
            final isSelected = minutes == current;
            return ListTile(
              onTap: () => Navigator.of(ctx).pop(minutes),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFC5200).withValues(alpha: 0.15)
                      : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.alarm_rounded,
                  color:
                      isSelected ? const Color(0xFFFC5200) : AppTheme.textMuted,
                  size: 18,
                ),
              ),
              title: Text(
                SettingsService.advanceLabel(minutes),
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFFC5200)
                      : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle_rounded,
                      color: Color(0xFFFC5200), size: 20)
                  : null,
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<int?> _showWeekdayPicker(int current) async {
    const days = [
      (1, 'Senin'),
      (2, 'Selasa'),
      (3, 'Rabu'),
      (4, 'Kamis'),
      (5, 'Jumat'),
      (6, 'Sabtu'),
      (7, 'Minggu'),
    ];
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Pilih Hari Laporan',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: days.map((entry) {
            final (num, name) = entry;
            final isSel = num == current;
            return ListTile(
              onTap: () => Navigator.of(ctx).pop(num),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSel
                      ? const Color(0xFFFC5200).withValues(alpha: 0.15)
                      : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(name.substring(0, 2),
                      style: TextStyle(
                        color: isSel
                            ? const Color(0xFFFC5200)
                            : AppTheme.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      )),
                ),
              ),
              title: Text(name,
                  style: TextStyle(
                    color:
                        isSel ? const Color(0xFFFC5200) : AppTheme.textPrimary,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  )),
              trailing: isSel
                  ? const Icon(Icons.check_circle_rounded,
                      color: Color(0xFFFC5200), size: 20)
                  : null,
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (_, __, ___) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.background,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text('Pengaturan',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 20)),
          ),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AppTheme.neonGreen))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ━━━ HEADER PROFIL ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                        _buildProfileHeader(),
                        const SizedBox(height: 24),

                        // ━━━ 1. TARGET & BUDGET ━━━━━━━━━━━━━━━━━━━━━━━━━
                        _sectionTitle('🎯  TARGET & BUDGET'),
                        const SizedBox(height: 8),
                        _buildCard([
                          _navTile(
                              icon: Icons.track_changes_rounded,
                              iconColor: AppTheme.neonGreen,
                              title: 'Goal Latihan',
                              subtitle: _profile[ProfileService.keyGoal] ?? 'Belum diatur',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) => _loadAll())),
                          _divider(),
                          _navTile(
                              icon: Icons.account_balance_wallet_rounded,
                              iconColor: AppTheme.accentOrange,
                              title: 'Budget Harian',
                              subtitle: NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(_profile[ProfileService.keyDailyBudget] ?? 0),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) => _loadAll())),
                        ]),
                        const SizedBox(height: 24),

                        // ━━━ 2. KONFIGURASI APP ━━━━━━━━━━━━━━━━━━━━━━━━━━
                        _sectionTitle('⚙️  KONFIGURASI APP'),
                        const SizedBox(height: 8),
                        _buildCard([
                          _switchTile(
                            icon: Icons.sports_rounded,
                            iconColor: AppTheme.electricBlue,
                            title: 'Alarm Peluit',
                            subtitle: 'Suara peluit saat jadwal tiba',
                            value: _whistleAlarm,
                            onChanged: _onWhistleAlarmChanged,
                          ),
                          _divider(),
                          _switchTile(
                            icon: Icons.notifications_active_rounded,
                            iconColor: AppTheme.accentPurple,
                            title: 'Notifikasi Jam 18:00',
                            subtitle: 'Pengingat rutin setiap sore',
                            value: _notif1800,
                            onChanged: _onNotif1800Changed,
                          ),
                          _divider(),
                          _switchTile(
                            icon: _darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            iconColor: _darkMode ? Colors.deepPurple[300]! : Colors.orange[400]!,
                            title: 'Mode Gelap',
                            subtitle: _darkMode ? 'Tampilan gelap premium' : 'Tampilan cerah bersih',
                            value: _darkMode,
                            onChanged: _onDarkModeChanged,
                          ),
                          _divider(),
                          _navTile(
                            icon: Icons.language_rounded,
                            iconColor: AppTheme.neonGreen,
                            title: 'Bahasa',
                            subtitle: SettingsService.languageLabel(_language),
                            onTap: _showLanguagePicker,
                          ),
                        ]),
                        const SizedBox(height: 24),

                        // ━━━ 3. PUSAT NOTIFIKASI ━━━━━━━━━━━━━━━━━━━━━━━━━
                        _sectionTitle('🔔  PUSAT NOTIFIKASI'),
                        const SizedBox(height: 8),
                        _buildCard([
                          _navTile(
                            icon: Icons.history_rounded,
                            iconColor: AppTheme.accentOrange,
                            title: 'Riwayat Notifikasi',
                            subtitle: 'Lihat pesan dan pengingat terakhir',
                            onTap: () => _showFeedback('Fitur riwayat segera hadir!'),
                          ),
                          _divider(),
                          _switchTile(
                              icon: Icons.fitness_center_rounded,
                              iconColor: const Color(0xFFFC5200),
                              title: 'Pengingat Jadwal',
                              subtitle: _notifWorkout ? 'Aktif (${SettingsService.advanceLabel(_advanceMinutes)})' : 'Nonaktif',
                              value: _notifWorkout,
                              onChanged: _onNotifWorkoutChanged),
                        ]),
                        const SizedBox(height: 24),

                        // ━━━ 4. INTEGRASI & LAINNYA ━━━━━━━━━━━━━━━━━━━━━━
                        _sectionTitle('🔗  INTEGRASI & LAINNYA'),
                        const SizedBox(height: 8),
                        _buildCard([
                          ListTile(
                            leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFFC5200).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.directions_run_rounded, color: Color(0xFFFC5200), size: 20)),
                            title: Text('Strava', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(_stravaConnected ? 'Terhubung' : 'Belum terhubung', style: TextStyle(color: _stravaConnected ? AppTheme.neonGreen : AppTheme.textMuted, fontSize: 12)),
                            trailing: _stravaConnected
                                ? Row(mainAxisSize: MainAxisSize.min, children: [
                                    IconButton(icon: _stravaSyncing ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.neonGreen)) : Icon(Icons.sync_rounded, color: AppTheme.neonGreen, size: 20), onPressed: _stravaSyncing ? null : _syncStrava),
                                    IconButton(icon: Icon(Icons.link_off_rounded, color: AppTheme.accentRed, size: 20), onPressed: _disconnectStrava),
                                  ])
                                : ElevatedButton(onPressed: _connectStrava, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFC5200), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Connect', style: TextStyle(color: Colors.white, fontSize: 11))),
                          ),
                          _divider(),
                          _navTile(icon: Icons.help_outline_rounded, iconColor: AppTheme.electricBlue, title: 'Pusat Bantuan', subtitle: 'FAQ & Tutorial', onTap: () => _showFeedback('Bantuan segera hadir!')),
                        ]),
                        const SizedBox(height: 32),

                        // ━━━ ZONA BAHAYA ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                        _sectionTitle('⚠️  ZONA BAHAYA'),
                        const SizedBox(height: 8),
                        _buildCard([
                          ListTile(
                            onTap: () async {
                              final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(backgroundColor: AppTheme.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Text('Keluar?', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)), content: Text('Anda akan keluar dari akun.', style: TextStyle(color: AppTheme.textSecondary)), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Batal', style: TextStyle(color: AppTheme.textMuted))), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed), child: const Text('Keluar', style: TextStyle(color: Colors.white)))]));
                              if (confirm == true) { await AuthService.signOut(); if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LandingScreen()), (_) => false); }
                            },
                            leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.accentRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.logout_rounded, color: AppTheme.accentRed, size: 20)),
                            title: Text('Logout', style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Text('Keluar dari sesi saat ini', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                            trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.accentRed.withValues(alpha: 0.5)),
                          ),
                          _divider(),
                          ListTile(
                            onTap: _showDeleteAccountDialog,
                            leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.accentRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.delete_forever_rounded, color: AppTheme.accentRed, size: 20)),
                            title: Text('Hapus Akun', style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Text('Hapus semua data permanen', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                            trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.accentRed.withValues(alpha: 0.5)),
                          ),
                        ]),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
        );
      },
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
        child: Text(text,
            style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1)),
      );

  Widget _buildProfileHeader() {
    final name = _profile[ProfileService.keyName] ?? AuthService.displayName;
    final status = _profile[ProfileService.keyStatus] ?? 'Status belum diatur';
    final photoUrl = _profile['photoUrl'];
    final email = AuthService.email;
    final googlePhotoUrl = AuthService.photoUrl;

    Widget photoWidget;
    if (_customPhotoDataUri != null && _customPhotoDataUri!.startsWith('data:image')) {
      final base64Str = _customPhotoDataUri!.split(',').last;
      try {
        final bytes = base64Decode(base64Str);
        photoWidget = Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _googleOrDefaultAvatar(googlePhotoUrl, name),
        );
      } catch (_) {
        photoWidget = _googleOrDefaultAvatar(googlePhotoUrl, name);
      }
    } else if (photoUrl != null && photoUrl.startsWith('http')) {
      photoWidget = Image.network(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _googleOrDefaultAvatar(googlePhotoUrl, name),
      );
    } else {
      photoWidget = _googleOrDefaultAvatar(googlePhotoUrl, name);
    }

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) => _loadAll()),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.neonGreen.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.neonGreen.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.neonGreenGrad,
                border: Border.all(color: AppTheme.neonGreen, width: 2),
              ),
              padding: const EdgeInsets.all(2),
              child: ClipOval(
                child: photoWidget,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      color: AppTheme.neonGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    return Container(
      color: AppTheme.surfaceVariant,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _googleOrDefaultAvatar(String? googleUrl, String name) {
    if (googleUrl != null && googleUrl.startsWith('http')) {
      return Image.network(
        googleUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultAvatar(name),
      );
    }
    return _defaultAvatar(name);
  }

  Widget _buildCard(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(children: children),
      );

  Widget _divider() => Divider(height: 1, color: AppTheme.border, indent: 60);

  Widget _switchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      ListTile(
        leading: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title,
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
        subtitle: Text(subtitle,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: const Color(0xFFFC5200),
          inactiveThumbColor: AppTheme.textMuted,
          inactiveTrackColor: AppTheme.border,
        ),
      );

  /// Baris klik untuk mengubah suatu nilai (waktu / hari / advance)
  Widget _actionTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            border: Border(
                top: BorderSide(color: AppTheme.border.withValues(alpha: 0.5))),
          ),
          child: Row(
            children: [
              const SizedBox(width: 56),
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 8),
              // Label fleksibel — tidak meluber
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Badge nilai — dibatasi agar tidak overflow
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 140),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_rounded, color: color, size: 11),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  /// Preview satu jadwal mendatang
  Widget _eventPreviewTile(ScheduleEvent event) {
    final isWorkout = event.type == 'workout';
    final accentColor =
        isWorkout ? const Color(0xFFFC5200) : AppTheme.neonGreen;
    final notifTime =
        event.dateTime.subtract(Duration(minutes: _advanceMinutes));
    final nowStr = DateFormat('d MMM • HH:mm').format(event.dateTime);
    final notifStr = DateFormat('HH:mm').format(notifTime);

    return Column(
      children: [
        Divider(height: 1, color: AppTheme.border, indent: 16),
        ListTile(
          dense: true,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child:
                  Icon(event.typeIcon, size: 16),
            ),
          ),
          title: Text(event.title,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          subtitle: Text(nowStr,
              style: TextStyle(color: AppTheme.electricBlue, fontSize: 11)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFC5200).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.alarm_rounded,
                    size: 12, color: Color(0xFFFC5200)),
                const SizedBox(width: 4),
                Text(notifStr,
                    style: const TextStyle(
                        color: Color(0xFFFC5200),
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String trailing,
  }) =>
      ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title,
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
        trailing: Text(trailing,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
      );

  Widget _navTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title,
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
        subtitle: Text(subtitle,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
      );

  Widget _dataSourceTile({
    required String value,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _dataSource == value;
    return InkWell(
      onTap: () => setState(() => _dataSource = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isSelected ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? iconColor : AppTheme.border,
                  width: isSelected ? 2 : 1.5,
                ),
                color: isSelected ? iconColor.withValues(alpha: 0.15) : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: iconColor,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
