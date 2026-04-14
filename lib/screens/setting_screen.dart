import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../services/database_helper.dart';
import '../models/schedule_event.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _darkMode       = true;
  bool _notifWorkout   = true;
  bool _notifProgress  = true;
  bool _notifStrava    = false;
  bool _metricUnit     = true;
  bool _isLoading      = true;
  int  _advanceMinutes = 30;

  TimeOfDay _progressTime    = const TimeOfDay(hour: 8, minute: 0);
  int       _progressWeekday = DateTime.monday;

  // Jadwal mendatang untuk preview
  List<ScheduleEvent> _upcomingEvents = [];

  final _db = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final darkMode        = await SettingsService.getDarkMode();
    final notifWorkout    = await SettingsService.getNotifWorkout();
    final notifProgress   = await SettingsService.getNotifProgress();
    final notifStrava     = await SettingsService.getNotifStrava();
    final metricUnit      = await SettingsService.getMetricUnit();
    final advanceMinutes  = await SettingsService.getWorkoutAdvanceMinutes();
    final progressTime    = await SettingsService.getProgressTime();
    final progressWeekday = await SettingsService.getProgressWeekday();
    final events          = await _db.getUpcomingEvents();

    if (mounted) {
      setState(() {
        _darkMode        = darkMode;
        _notifWorkout    = notifWorkout;
        _notifProgress   = notifProgress;
        _notifStrava     = notifStrava;
        _metricUnit      = metricUnit;
        _advanceMinutes  = advanceMinutes;
        _progressTime    = progressTime;
        _progressWeekday = progressWeekday;
        _upcomingEvents  = events;
        _isLoading       = false;
      });
    }
  }

  // ── Dark Mode ─────────────────────────────────────────────────────────────
  void _onDarkModeChanged(bool value) {
    setState(() => _darkMode = value);
    SettingsService.setDarkMode(value);
    _showFeedback(value ? '🌙 Mode Gelap diaktifkan' : '☀️ Mode Terang diaktifkan');
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
        '🔔 Pengingat jadwal diaktifkan (${SettingsService.advanceLabel(_advanceMinutes)})',
      );
    } else {
      // Batalkan semua notif jadwal
      for (final e in _upcomingEvents) {
        if (e.id != null) await NotificationService().cancelEventReminder(e.id!);
      }
      _showFeedback('🔕 Semua pengingat jadwal dimatikan');
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
      _showFeedback('✅ Pengingat diperbarui: ${SettingsService.advanceLabel(picked)}');
    }
  }

  // ── Notif Progress ────────────────────────────────────────────────────────
  void _onNotifProgressChanged(bool value) async {
    setState(() => _notifProgress = value);
    await SettingsService.setNotifProgress(value);
    if (value) {
      await _rescheduleProgress();
      _showFeedback(
        '📊 Laporan diaktifkan (${SettingsService.weekdayName(_progressWeekday)}, ${_fmtTime(_progressTime)})',
      );
    } else {
      await NotificationService().cancelWeeklyProgressReminder();
      _showFeedback('🔕 Laporan mingguan dimatikan');
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
      hour:    _progressTime.hour,
      minute:  _progressTime.minute,
    );
  }

  // ── Strava ────────────────────────────────────────────────────────────────
  void _onNotifStravaChanged(bool value) async {
    setState(() => _notifStrava = value);
    await SettingsService.setNotifStrava(value);
    _showFeedback(value ? '🔗 Notifikasi Strava aktif' : '🔕 Notifikasi Strava nonaktif');
  }

  // ── Satuan ────────────────────────────────────────────────────────────────
  void _onMetricUnitChanged(bool value) async {
    setState(() => _metricUnit = value);
    await SettingsService.setMetricUnit(value);
    _showFeedback(value ? '📏 Metrik (km, kg, cm)' : '📏 Imperial (mi, lbs, in)');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _showFeedback(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
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
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SettingsService.advanceOptions.map((minutes) {
            final isSelected = minutes == current;
            return ListTile(
              onTap: () => Navigator.of(ctx).pop(minutes),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFC5200).withValues(alpha: 0.15)
                      : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.alarm_rounded,
                  color: isSelected ? const Color(0xFFFC5200) : AppTheme.textMuted,
                  size: 18,
                ),
              ),
              title: Text(
                SettingsService.advanceLabel(minutes),
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFC5200) : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFC5200), size: 20)
                  : null,
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<int?> _showWeekdayPicker(int current) async {
    const days = [
      (1, 'Senin'),  (2, 'Selasa'), (3, 'Rabu'),
      (4, 'Kamis'),  (5, 'Jumat'),  (6, 'Sabtu'), (7, 'Minggu'),
    ];
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Pilih Hari Laporan',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: days.map((entry) {
            final (num, name) = entry;
            final isSel = num == current;
            return ListTile(
              onTap: () => Navigator.of(ctx).pop(num),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isSel
                      ? const Color(0xFFFC5200).withValues(alpha: 0.15)
                      : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(name.substring(0, 2),
                      style: TextStyle(
                        color: isSel ? const Color(0xFFFC5200) : AppTheme.textMuted,
                        fontWeight: FontWeight.w700, fontSize: 12,
                      )),
                ),
              ),
              title: Text(name,
                  style: TextStyle(
                    color: isSel ? const Color(0xFFFC5200) : AppTheme.textPrimary,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  )),
              trailing: isSel
                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFC5200), size: 20)
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
              ? Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Tampilan ─────────────────────────────────────────
                      _sectionTitle(_darkMode ? '🌙 Tampilan' : '☀️ Tampilan'),
                      const SizedBox(height: 8),
                      _buildCard([
                        _switchTile(
                          icon:      _darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          iconColor: _darkMode ? Colors.deepPurple[300]! : Colors.orange[400]!,
                          title:     _darkMode ? 'Mode Gelap' : 'Mode Terang',
                          subtitle:  _darkMode ? 'Tampilan latar belakang gelap' : 'Tampilan latar belakang cerah',
                          value:     _darkMode,
                          onChanged: _onDarkModeChanged,
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // ── Pengingat Jadwal ──────────────────────────────────
                      _sectionTitle('🗓️ Pengingat Jadwal Latihan'),
                      const SizedBox(height: 8),
                      _buildCard([
                        _switchTile(
                          icon:      Icons.notifications_active_rounded,
                          iconColor: const Color(0xFFFC5200),
                          title:     'Pengingat Jadwal',
                          subtitle:  _notifWorkout
                              ? 'Aktif — ${SettingsService.advanceLabel(_advanceMinutes)}'
                              : 'Nonaktif — jadwal tidak akan diingatkan',
                          value:     _notifWorkout,
                          onChanged: _onNotifWorkoutChanged,
                        ),
                        // Sub-baris advance notice
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          child: _notifWorkout
                              ? _actionTile(
                                  label: 'Ingatkan saya',
                                  value: SettingsService.advanceLabel(_advanceMinutes),
                                  icon: Icons.alarm_rounded,
                                  color: const Color(0xFFFC5200),
                                  onTap: _pickAdvanceNotice,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ]),

                      const SizedBox(height: 12),

                      // Preview jadwal mendatang
                      if (_notifWorkout) ...[
                        _sectionTitle('📋 Jadwal yang akan diingatkan'),
                        const SizedBox(height: 8),
                        _buildCard(
                          _upcomingEvents.isEmpty
                              ? [
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      children: [
                                        Icon(Icons.calendar_today_rounded,
                                            color: AppTheme.textMuted, size: 36),
                                        const SizedBox(height: 8),
                                        Text('Belum ada jadwal mendatang',
                                            style: TextStyle(
                                                color: AppTheme.textMuted, fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Text('Buat jadwal di tab Jadwal',
                                            style: TextStyle(
                                                color: AppTheme.textMuted.withValues(alpha: 0.6),
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ]
                              : _upcomingEvents.take(5).map((e) => _eventPreviewTile(e)).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],

                      const SizedBox(height: 12),

                      // ── Notifikasi lain ───────────────────────────────────
                      _sectionTitle('🔔 Notifikasi Lain'),
                      const SizedBox(height: 8),
                      _buildCard([
                        _switchTile(
                          icon:      Icons.bar_chart_rounded,
                          iconColor: AppTheme.neonGreen,
                          title:     'Laporan Progress Mingguan',
                          subtitle:  _notifProgress
                              ? 'Aktif — ${SettingsService.weekdayName(_progressWeekday)}, ${_fmtTime(_progressTime)}'
                              : 'Nonaktif',
                          value:     _notifProgress,
                          onChanged: _onNotifProgressChanged,
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          child: _notifProgress
                              ? Column(children: [
                                  _actionTile(
                                    label: 'Jam laporan',
                                    value: _fmtTime(_progressTime),
                                    icon: Icons.access_time_rounded,
                                    color: AppTheme.neonGreen,
                                    onTap: _pickProgressTime,
                                  ),
                                  _actionTile(
                                    label: 'Hari laporan',
                                    value: SettingsService.weekdayName(_progressWeekday),
                                    icon: Icons.calendar_today_rounded,
                                    color: AppTheme.neonGreen,
                                    onTap: _pickProgressWeekday,
                                  ),
                                ])
                              : const SizedBox.shrink(),
                        ),
                        _divider(),
                        _switchTile(
                          icon:      Icons.sync_rounded,
                          iconColor: AppTheme.electricBlue,
                          title:     'Sinkronisasi Strava',
                          subtitle:  _notifStrava ? 'Aktif — notif setelah import' : 'Nonaktif',
                          value:     _notifStrava,
                          onChanged: _onNotifStravaChanged,
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // ── Satuan ─────────────────────────────────────────
                      _sectionTitle('📏 Satuan'),
                      const SizedBox(height: 8),
                      _buildCard([
                        _switchTile(
                          icon:      Icons.straighten_rounded,
                          iconColor: AppTheme.accentOrange,
                          title:     _metricUnit ? 'Satuan Metrik' : 'Satuan Imperial',
                          subtitle:  _metricUnit ? 'km, cm, kg' : 'mi, in, lbs',
                          value:     _metricUnit,
                          onChanged: _onMetricUnitChanged,
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // ── Tentang ────────────────────────────────────────
                      _sectionTitle('ℹ️ Tentang'),
                      const SizedBox(height: 8),
                      _buildCard([
                        _infoTile(icon: Icons.info_outline_rounded,  iconColor: AppTheme.electricBlue, title: 'Versi Aplikasi', trailing: '1.0.0'),
                        _divider(),
                        _infoTile(icon: Icons.code_rounded, iconColor: AppTheme.neonGreen, title: 'Developer', trailing: 'AthleteSync Team'),
                      ]),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
        );
      },
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text,
            style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      );

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
    required Color    iconColor,
    required String   title,
    required String   subtitle,
    required bool     value,
    required ValueChanged<bool> onChanged,
  }) =>
      ListTile(
        leading: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 40, height: 40,
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
    required String   label,
    required String   value,
    required IconData icon,
    required Color    color,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            border: Border(top: BorderSide(color: AppTheme.border.withValues(alpha: 0.5))),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
    final isWorkout  = event.type == 'workout';
    final accentColor = isWorkout ? const Color(0xFFFC5200) : AppTheme.neonGreen;
    final notifTime  = event.dateTime.subtract(Duration(minutes: _advanceMinutes));
    final nowStr     = DateFormat('d MMM • HH:mm').format(event.dateTime);
    final notifStr   = DateFormat('HH:mm').format(notifTime);

    return Column(
      children: [
        Divider(height: 1, color: AppTheme.border, indent: 16),
        ListTile(
          dense: true,
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(event.typeEmoji, style: const TextStyle(fontSize: 16)),
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
                Icon(Icons.alarm_rounded, size: 12, color: const Color(0xFFFC5200)),
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
    required Color    iconColor,
    required String   title,
    required String   trailing,
  }) =>
      ListTile(
        leading: Container(
          width: 40, height: 40,
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
}
