import 'package:equatable/equatable.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettings extends SettingsEvent {}

class ToggleDarkMode extends SettingsEvent {
  final bool isDark;

  const ToggleDarkMode(this.isDark);

  @override
  List<Object?> get props => [isDark];
}

class ToggleNotification extends SettingsEvent {
  final bool isEnabled;

  const ToggleNotification(this.isEnabled);

  @override
  List<Object?> get props => [isEnabled];
}

class SignOutRequested extends SettingsEvent {}
