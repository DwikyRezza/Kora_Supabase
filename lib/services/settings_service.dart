import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Mengelola semua pengaturan aplikasi ─ disimpan di SharedPreferences
/// agar persisten antar sesi.
class SettingsService {
  // ── Keys ──────────────────────────────────────────────────────────────────
  static const _kDarkMode            = 'setting_dark_mode';
  static const _kNotifWorkout        = 'setting_notif_workout';
  static const _kNotifWorkoutAdvance = 'setting_notif_workout_advance';
  static const _kNotifProgress       = 'setting_notif_progress';
  static const _kNotifStrava         = 'setting_notif_strava';
  static const _kNotifHydration      = 'setting_notif_hydration';
  static const _kMetricUnit          = 'setting_metric_unit';
  static const _kLanguage            = 'setting_language'; // 'id', 'en', 'system'
  static const _kWhistleAlarm        = 'setting_whistle_alarm';
  static const _kNotif1800           = 'setting_notif_1800';

  // Waktu & hari notifikasi progress mingguan
  static const _kProgressHour        = 'setting_progress_hour';
  static const _kProgressMinute      = 'setting_progress_minute';
  static const _kProgressWeekday     = 'setting_progress_weekday';

  // ── Load semua pengaturan saat startup ────────────────────────────────────
  static Future<void> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final darkMode = prefs.getBool(_kDarkMode) ?? true;
    final desiredMode = darkMode ? ThemeMode.dark : ThemeMode.light;
    if (AppTheme.themeNotifier.value != desiredMode) {
      AppTheme.themeNotifier.value = desiredMode;
    }
  }

  // ── Dark Mode ─────────────────────────────────────────────────────────────
  static Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDarkMode) ?? true;
  }

  static Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkMode, value);
    AppTheme.themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  // ── Master switch Notif Workout ───────────────────────────────────────────
  /// True = semua notifikasi jadwal workout aktif
  static Future<bool> getNotifWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kNotifWorkout) ?? true;
  }

  static Future<void> setNotifWorkout(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifWorkout, value);
  }

  /// Berapa menit sebelum jadwal notifikasi dikirim (default 30 menit)
  static Future<int> getWorkoutAdvanceMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kNotifWorkoutAdvance) ?? 30;
  }

  static Future<void> setWorkoutAdvanceMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kNotifWorkoutAdvance, minutes);
  }

  // ── Toggle Notif Progress ─────────────────────────────────────────────────
  static Future<bool> getNotifProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kNotifProgress) ?? true;
  }

  static Future<void> setNotifProgress(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifProgress, value);
  }

  // ── Waktu & Hari Notif Progress ───────────────────────────────────────────
  static Future<TimeOfDay> getProgressTime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour:   prefs.getInt(_kProgressHour)   ?? 8,
      minute: prefs.getInt(_kProgressMinute) ?? 0,
    );
  }

  static Future<void> setProgressTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kProgressHour,   time.hour);
    await prefs.setInt(_kProgressMinute, time.minute);
  }

  /// Hari dalam seminggu: 1=Senin, 2=Selasa, ... 7=Minggu
  static Future<int> getProgressWeekday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kProgressWeekday) ?? DateTime.monday;
  }

  static Future<void> setProgressWeekday(int weekday) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kProgressWeekday, weekday);
  }

  // ── Toggle Notif Strava ───────────────────────────────────────────────────
  static Future<bool> getNotifStrava() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kNotifStrava) ?? false;
  }

  static Future<void> setNotifStrava(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifStrava, value);
  }

  // ── Toggle Notif Hydration ────────────────────────────────────────────────
  static Future<bool> getNotifHydration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kNotifHydration) ?? false;
  }

  static Future<void> setNotifHydration(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifHydration, value);
  }

  // ── Satuan ────────────────────────────────────────────────────────────────
  static Future<bool> getMetricUnit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kMetricUnit) ?? true;
  }

  static Future<void> setMetricUnit(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMetricUnit, value);
  }

  // ── Bahasa ────────────────────────────────────────────────────────────────
  /// 'id' = Indonesia, 'en' = English, 'system' = Ikuti Sistem
  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLanguage) ?? 'id';
  }

  static Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguage, lang);
  }

  // ── Toggle Whistle Alarm ──────────────────────────────────────────────────
  static Future<bool> getWhistleAlarm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kWhistleAlarm) ?? true;
  }

  static Future<void> setWhistleAlarm(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWhistleAlarm, value);
  }

  // ── Toggle 18:00 Notif ────────────────────────────────────────────────────
  static Future<bool> getNotif1800() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kNotif1800) ?? true;
  }

  static Future<void> setNotif1800(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotif1800, value);
  }

  static String languageLabel(String code) {
    switch (code) {
      case 'en': return 'English';
      case 'system': return 'Ikuti Sistem';
      default: return 'Bahasa Indonesia';
    }
  }

  /// Format jarak sesuai satuan yang dipilih user.
  static Future<String> formatDistance(double km) async {
    final metric = await getMetricUnit();
    if (metric) return '${km.toStringAsFixed(2)} km';
    return '${(km * 0.621371).toStringAsFixed(2)} mi';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String weekdayName(int weekday) {
    const names = ['', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return names[weekday.clamp(1, 7)];
  }

  /// Label untuk advance notice
  static String advanceLabel(int minutes) {
    if (minutes < 60) return '$minutes menit sebelumnya';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h jam sebelumnya' : '$h jam $m menit sebelumnya';
  }

  /// Pilihan advance notice yang tersedia
  static const List<int> advanceOptions = [5, 10, 15, 30, 60, 120];
}
