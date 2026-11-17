import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/prefs/user_prefs_controller.dart';
import '../auth/auth_controller.dart';
import 'devices_api.dart';
import 'push_messaging.dart';

enum PushEnableResult { enabled, notSignedIn, permissionDenied, unavailable }

/// Connects this phone to the account's push notifications. Every server
/// call is best effort: being offline never blocks the user, and the next
/// start, sign-in or token refresh tries again.
class PushRegistration {
  PushRegistration(this._ref);

  final Ref _ref;

  /// Asks for permission, switches push on and registers this phone.
  Future<PushEnableResult> enable() async {
    final session = _ref.read(currentSessionProvider);
    if (session == null) return PushEnableResult.notSignedIn;

    final messaging = _ref.read(pushMessagingProvider);
    if (!await messaging.requestPermission()) {
      return PushEnableResult.permissionDenied;
    }
    if (await messaging.token() == null) return PushEnableResult.unavailable;

    await _ref.read(userPrefsProvider.notifier).setPushEnabled(true);
    // pushSyncProvider notices the switch and registers this phone.
    return PushEnableResult.enabled;
  }

  /// Switches push off and tells the server to stop sending to this phone.
  Future<void> disable() async {
    await _ref.read(userPrefsProvider.notifier).setPushEnabled(false);
    final session = _ref.read(currentSessionProvider);
    if (session == null) return;
    final token = await _ref.read(pushMessagingProvider).token();
    if (token != null) await _unregister(session.token, token);
  }

  /// Registers this phone when push is on and someone is signed in.
  Future<void> syncToken() async {
    if (!_ref.read(userPrefsProvider).pushEnabled) return;
    final session = _ref.read(currentSessionProvider);
    if (session == null) return;
    final token = await _ref.read(pushMessagingProvider).token();
    if (token != null) await _register(session.token, token);
  }

  /// Used on sign-out, when the session is already gone.
  Future<void> unregisterFor(String authToken) async {
    final token = await _ref.read(pushMessagingProvider).token();
    if (token != null) await _unregister(authToken, token);
  }

  /// Sends a test push to the signed-in account. Null when it could not be sent.
  Future<int?> sendTest() async {
    final session = _ref.read(currentSessionProvider);
    if (session == null) return null;
    try {
      return await _ref.read(devicesApiProvider).sendTest(session.token);
    } on ApiException {
      return null;
    }
  }

  Future<void> _register(String authToken, String pushToken) async {
    try {
      await _ref.read(devicesApiProvider).register(authToken, pushToken);
    } on ApiException {
      // Retried later.
    }
  }

  Future<void> _unregister(String authToken, String pushToken) async {
    try {
      await _ref.read(devicesApiProvider).unregister(authToken, pushToken);
    } on ApiException {
      // The server also drops tokens it can no longer reach.
    }
  }
}

final pushRegistrationProvider = Provider<PushRegistration>(
  PushRegistration.new,
);

/// Keeps the server's list of devices in step with sign-in, sign-out, the
/// push switch and Firebase token changes. Started with the router.
final pushSyncProvider = Provider<void>((ref) {
  final registration = ref.read(pushRegistrationProvider);

  ref.listen(currentSessionProvider, (previous, next) {
    if (next == null) {
      if (previous != null) unawaited(registration.unregisterFor(previous.token));
    } else if (previous?.token != next.token) {
      unawaited(registration.syncToken());
    }
  }, fireImmediately: true);

  ref.listen(userPrefsProvider.select((prefs) => prefs.pushEnabled), (
    previous,
    next,
  ) {
    if (next) unawaited(registration.syncToken());
  });

  final refreshes = ref.read(pushMessagingProvider).onTokenRefresh.listen(
        (_) => unawaited(registration.syncToken()),
      );
  ref.onDispose(refreshes.cancel);
});
