import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    state = next;
    await ref.read(prefsRepositoryProvider).save(next);
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
}

final userPrefsProvider =
    NotifierProvider<UserPrefsController, UserPrefs>(UserPrefsController.new);
