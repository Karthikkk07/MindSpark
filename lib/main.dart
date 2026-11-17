import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/prefs/user_prefs_controller.dart';
import 'core/telemetry/telemetry_service.dart';
import 'features/push/push_messaging.dart';
import 'repositories/prefs_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Collection starts only if the user opted in earlier.
  final telemetry = await FirebaseTelemetryService.start(
    enabled: PrefsRepository(prefs).load().analyticsEnabled,
  );
  installErrorReporting(telemetry);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        telemetryServiceProvider.overrideWithValue(telemetry),
        if (telemetry is FirebaseTelemetryService)
          pushMessagingProvider.overrideWithValue(FirebasePushMessaging()),
      ],
      child: const MindSparkApp(),
    ),
  );
}
