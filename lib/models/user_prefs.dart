import 'package:flutter/material.dart';

/// Everything the user has chosen so far. Immutable; use [copyWith] to change.
class UserPrefs {
  const UserPrefs({
    this.onboardingComplete = false,
    this.interests = const <String>{},
    this.themeMode = ThemeMode.system,
    this.reminderEnabled = false,
    this.reminderHour = 8,
    this.reminderMinute = 0,
    this.analyticsEnabled = false,
    this.pushEnabled = false,
  });

  final bool onboardingComplete;

  /// Category ids (see QuoteCategory). Empty means "no preference".
  final Set<String> interests;
  final ThemeMode themeMode;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;

  /// Opt-in to anonymous usage statistics and crash reports. Stays on this
  /// device (never synced) and is off until the user turns it on.
  final bool analyticsEnabled;

  /// Push notifications for this phone. Also local to the device.
  final bool pushEnabled;

  TimeOfDay get reminderTime =>
      TimeOfDay(hour: reminderHour, minute: reminderMinute);

  UserPrefs copyWith({
    bool? onboardingComplete,
    Set<String>? interests,
    ThemeMode? themeMode,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? analyticsEnabled,
    bool? pushEnabled,
  }) {
    return UserPrefs(
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      interests: interests ?? this.interests,
      themeMode: themeMode ?? this.themeMode,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
    );
  }
}
