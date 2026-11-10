import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/sync/sync_controller.dart';
import '../../models/user_prefs.dart';
import '../../repositories/prefs_repository.dart';

/// Must be overridden in main() (and in tests) with a loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'Override sharedPreferencesProvider with a loaded SharedPreferences.',
  ),
);

final prefsRepositoryProvider = Provider<PrefsRepository>(
  (ref) => PrefsRepository(ref.watch(sharedPreferencesProvider)),
);

/// Single source of truth for the user's choices. Saves on every change.
class UserPrefsController extends Notifier<UserPrefs> {
  @override
  UserPrefs build() => ref.watch(prefsRepositoryProvider).load();

  Future<void> _update(UserPrefs next) async {
    final previous = state;
    state = next;
    await ref.read(prefsRepositoryProvider).save(next);
    if (_syncedFieldsChanged(previous, next)) {
      // Signed-in users: send the change to the account (kept if offline).
      unawaited(ref.read(syncControllerProvider.notifier).onPrefsChanged());
    }
  }

  static bool _syncedFieldsChanged(UserPrefs a, UserPrefs b) {
    return !setEquals(a.interests, b.interests) ||
        a.themeMode != b.themeMode ||
        a.reminderEnabled != b.reminderEnabled ||
        a.reminderHour != b.reminderHour ||
        a.reminderMinute != b.reminderMinute;
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _update(state.copyWith(themeMode: mode));

  Future<void> toggleInterest(String id) {
    final next = {...state.interests};
    if (!next.add(id)) next.remove(id);
    return _update(state.copyWith(interests: next));
  }

  Future<void> setReminderEnabled(bool enabled) =>
      _update(state.copyWith(reminderEnabled: enabled));

  Future<void> setReminderTime(TimeOfDay time) => _update(
        state.copyWith(reminderHour: time.hour, reminderMinute: time.minute),
      );

  Future<void> completeOnboarding() =>
      _update(state.copyWith(onboardingComplete: true));

  /// Applies the account's settings. Used by sync; does not push back.
  Future<void> applyRemote(UserPrefs remote) async {
    final next = state.copyWith(
      interests: remote.interests,
      themeMode: remote.themeMode,
      reminderEnabled: remote.reminderEnabled,
      reminderHour: remote.reminderHour,
      reminderMinute: remote.reminderMinute,
    );
    state = next;
    await ref.read(prefsRepositoryProvider).save(next);
  }
}

final userPrefsProvider =
    NotifierProvider<UserPrefsController, UserPrefs>(UserPrefsController.new);
