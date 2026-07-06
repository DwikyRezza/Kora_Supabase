import 'package:equatable/equatable.dart';

class SettingsState extends Equatable {
  final bool darkMode;
  final bool notifEnabled;
  final bool isSigningOut;
  final bool isSignOutSuccess;
  final String? errorMessage;

  const SettingsState({
    this.darkMode = true,
    this.notifEnabled = true,
    this.isSigningOut = false,
    this.isSignOutSuccess = false,
    this.errorMessage,
  });

  SettingsState copyWith({
    bool? darkMode,
    bool? notifEnabled,
    bool? isSigningOut,
    bool? isSignOutSuccess,
    String? errorMessage,
  }) {
    return SettingsState(
      darkMode: darkMode ?? this.darkMode,
      notifEnabled: notifEnabled ?? this.notifEnabled,
      isSigningOut: isSigningOut ?? this.isSigningOut,
      isSignOutSuccess: isSignOutSuccess ?? this.isSignOutSuccess,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        darkMode,
        notifEnabled,
        isSigningOut,
        isSignOutSuccess,
        errorMessage,
      ];
}
