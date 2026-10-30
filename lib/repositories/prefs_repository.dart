import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_prefs.dart';

/// Reads and writes [UserPrefs] using on-device storage.
class PrefsRepository {
  PrefsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const keyOnboardingComplete = 'onboarding_complete';
  static const keyInterests = 'interests';
  static const keyThemeMode = 'theme_mode';
  static const keyReminderEnabled = 'reminder_enabled';
  static const keyReminderHour = 'reminder_hour';
  static const keyReminderMinute = 'reminder_minute';

  UserPrefs load() {
    final themeName = _prefs.getString(keyThemeMode);
    return UserPrefs(
      onboardingComplete: _prefs.getBool(keyOnboardingComplete) ?? false,
      interests:
          (_prefs.getStringList(keyInterests) ?? const <String>[]).toSet(),
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == themeName,
        orElse: () => ThemeMode.system,
      ),
      reminderEnabled: _prefs.getBool(keyReminderEnabled) ?? false,
      reminderHour: _prefs.getInt(keyReminderHour) ?? 8,
      reminderMinute: _prefs.getInt(keyReminderMinute) ?? 0,
    );
  }

  Future<void> save(UserPrefs prefs) async {
    await _prefs.setBool(keyOnboardingComplete, prefs.onboardingComplete);
    await _prefs.setStringList(keyInterests, prefs.interests.toList()..sort());
    await _prefs.setString(keyThemeMode, prefs.themeMode.name);
    await _prefs.setBool(keyReminderEnabled, prefs.reminderEnabled);
    await _prefs.setInt(keyReminderHour, prefs.reminderHour);
    await _prefs.setInt(keyReminderMinute, prefs.reminderMinute);
  }
}
