import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Anonymous usage statistics and crash reports (Firebase Analytics and
/// Crashlytics). Everything is off until the user opts in under Settings.
abstract class TelemetryService {
  /// Switches collection on or off. Nothing is sent while it is off.
  Future<void> setEnabled(bool enabled);

  /// Records a named event. Never put personal text (goal titles, quotes
  /// typed by the user, emails) in [params].
  Future<void> logEvent(String name, [Map<String, Object>? params]);

  Future<void> logScreen(String name);

  Future<void> recordError(Object error, StackTrace? stack, {bool fatal = false});
}

/// Used in tests and when Firebase is not set up (for example a fresh clone
/// without google-services.json).
class NoopTelemetryService implements TelemetryService {
  const NoopTelemetryService();

  @override
  Future<void> setEnabled(bool enabled) async {}

  @override
  Future<void> logEvent(String name, [Map<String, Object>? params]) async {}

  @override
  Future<void> logScreen(String name) async {}

  @override
  Future<void> recordError(Object error, StackTrace? stack, {bool fatal = false}) async {}
}

class FirebaseTelemetryService implements TelemetryService {
  bool _enabled = false;

  /// Starts Firebase. Falls back to [NoopTelemetryService] when the app was
  /// built without a Firebase configuration.
  static Future<TelemetryService> start({required bool enabled}) async {
    try {
      await Firebase.initializeApp();
    } catch (error) {
      debugPrint('Firebase is not available, telemetry is off: $error');
      return const NoopTelemetryService();
    }
    final service = FirebaseTelemetryService();
    await service.setEnabled(enabled);
    return service;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    await _guard(() async {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
    });
  }

  @override
  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    if (!_enabled) return;
    await _guard(
      () => FirebaseAnalytics.instance.logEvent(name: name, parameters: params),
    );
  }

  @override
  Future<void> logScreen(String name) async {
    if (!_enabled) return;
    await _guard(() => FirebaseAnalytics.instance.logScreenView(screenName: name));
  }

  @override
  Future<void> recordError(Object error, StackTrace? stack, {bool fatal = false}) async {
    if (!_enabled) return;
    await _guard(
      () => FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal),
    );
  }

  /// Reporting must never break the app, so failures are only logged.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('Telemetry call failed: $error');
    }
  }
}

/// Sends uncaught errors to [service] (which ignores them when switched off).
void installErrorReporting(TelemetryService service) {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (previous != null) {
      previous(details);
    } else {
      FlutterError.presentError(details);
    }
    service.recordError(details.exception, details.stack, fatal: true);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    service.recordError(error, stack, fatal: true);
    return false;
  };
}

/// Overridden in main() with the Firebase implementation when available.
final telemetryServiceProvider = Provider<TelemetryService>(
  (ref) => const NoopTelemetryService(),
);
