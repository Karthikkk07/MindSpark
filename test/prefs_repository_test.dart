import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindspark/models/user_prefs.dart';
import 'package:mindspark/repositories/prefs_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saved preferences load back unchanged', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = PrefsRepository(await SharedPreferences.getInstance());

    await repo.save(const UserPrefs(
      onboardingComplete: true,
      interests: {'coding', 'study'},
      themeMode: ThemeMode.dark,
      reminderEnabled: true,
      reminderHour: 7,
      reminderMinute: 30,
    ));

    final loaded = repo.load();
    expect(loaded.onboardingComplete, isTrue);
    expect(loaded.interests, {'coding', 'study'});
    expect(loaded.themeMode, ThemeMode.dark);
    expect(loaded.reminderEnabled, isTrue);
    expect(loaded.reminderHour, 7);
    expect(loaded.reminderMinute, 30);
  });

  test('empty storage gives sensible defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = PrefsRepository(await SharedPreferences.getInstance());

    final loaded = repo.load();
    expect(loaded.onboardingComplete, isFalse);
    expect(loaded.interests, isEmpty);
    expect(loaded.themeMode, ThemeMode.system);
    expect(loaded.reminderEnabled, isFalse);
  });

  test('an unknown saved theme falls back to system', () async {
    SharedPreferences.setMockInitialValues({
      PrefsRepository.keyThemeMode: 'sepia',
    });
    final repo = PrefsRepository(await SharedPreferences.getInstance());

    expect(repo.load().themeMode, ThemeMode.system);
  });
}
