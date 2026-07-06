import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../services/auth_service.dart';
import '../../../../../services/settings_service.dart';
import '../../../../../theme/app_theme.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc() : super(const SettingsState()) {
    on<LoadSettings>(_onLoadSettings);
    on<ToggleDarkMode>(_onToggleDarkMode);
    on<ToggleNotification>(_onToggleNotification);
    on<SignOutRequested>(_onSignOutRequested);
  }

  Future<void> _onLoadSettings(LoadSettings event, Emitter<SettingsState> emit) async {
    try {
      final isDark = await SettingsService.getDarkMode();
      final notif = await SettingsService.getNotifWorkout();
      emit(state.copyWith(darkMode: isDark, notifEnabled: notif));
    } catch (_) {
      // Ignore errors for settings
    }
  }

  Future<void> _onToggleDarkMode(ToggleDarkMode event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(darkMode: event.isDark));
    AppTheme.themeNotifier.value = event.isDark ? ThemeMode.dark : ThemeMode.light;
    await SettingsService.setDarkMode(event.isDark);
  }

  Future<void> _onToggleNotification(ToggleNotification event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(notifEnabled: event.isEnabled));
    await SettingsService.setNotifWorkout(event.isEnabled);
  }

  Future<void> _onSignOutRequested(SignOutRequested event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isSigningOut: true));
    try {
      await AuthService.signOut();
      emit(state.copyWith(isSigningOut: false, isSignOutSuccess: true));
    } catch (e) {
      emit(state.copyWith(
        isSigningOut: false,
        errorMessage: 'Gagal keluar: ${e.toString()}',
      ));
      emit(state.copyWith(errorMessage: null));
    }
  }
}
