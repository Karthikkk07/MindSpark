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
  });

  final bool onboardingComplete;

  /// Category ids (see QuoteCategory). Empty means "no preference".
  final Set<String> interests;
  final ThemeMode themeMode;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;

  TimeOfDay get reminderTime =>
      TimeOfDay(hour: reminderHour, minute: reminderMinute);

  UserPrefs copyWith({
    bool? onboardingComplete,
    Set<String>? interests,
    ThemeMode? themeMode,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
  }) {
    return UserPrefs(
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      interests: interests ?? this.interests,
      themeMode: themeMode ?? this.themeMode,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
    );
  }
}
