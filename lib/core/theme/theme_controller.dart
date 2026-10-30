import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs/user_prefs_controller.dart';

/// The theme mode the app should use, derived from the saved preferences.
final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(userPrefsProvider.select((prefs) => prefs.themeMode)),
);
