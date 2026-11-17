import 'dart:async';

import 'package:flutter/material.dart' show SnackBar, Text, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/prefs/user_prefs_controller.dart';
import '../../core/widgets/root_messenger.dart';
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
    if (token == null) {
      _setStatus('Firebase did not give this phone a push token.');
      return;
    }
    await _register(session.token, token);
  }

  /// Used on sign-out, when the session is already gone.
  Future<void> unregisterFor(String authToken) async {
    final token = await _ref.read(pushMessagingProvider).token();
    if (token != null) await _unregister(authToken, token);
  }

  /// The last characters of this phone's push token, to compare with the
  /// server's report.
  Future<String?> tokenTail() async {
    final token = await _ref.read(pushMessagingProvider).token();
    if (token == null) return null;
    return token.substring(token.length - 6);
  }

  /// Sends a test push to the signed-in account. Null when it could not be sent.
  Future<PushTestResult?> sendTest({int delaySeconds = 0}) async {
    final session = _ref.read(currentSessionProvider);
    if (session == null) return null;
    try {
      return await _ref
          .read(devicesApiProvider)
          .sendTest(session.token, delaySeconds: delaySeconds);
    } on ApiException {
      return null;
    }
  }

  Future<void> _register(String authToken, String pushToken) async {
    final tail = pushToken.substring(pushToken.length - 6);
    try {
      await _ref.read(devicesApiProvider).register(authToken, pushToken);
      _setStatus('This phone is registered with the server (token ...$tail).');
    } on ApiException catch (error) {
      // Retried at the next start, sign-in or token change.
      _setStatus('Could not register this phone: ${error.message}');
    }
  }

  void _setStatus(String text) {
    debugPrint('Push: $text');
    if (_ref.mounted) _ref.read(pushStatusProvider.notifier).set(text);
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

/// A short, human-readable line about whether this phone is registered.
class PushStatus extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? text) => state = text;
}

final pushStatusProvider = NotifierProvider<PushStatus, String?>(PushStatus.new);

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

  // Android only shows pushes in the notification shade while the app is in
  // the background, so a push that arrives now is shown in the app instead.
  final incoming = ref.read(pushMessagingProvider).onForegroundMessage.listen((message) {
    final text = [message.title, message.body]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(': ');
    if (text.isEmpty) return;
    ref.read(rootMessengerKeyProvider).currentState?.showSnackBar(
          SnackBar(content: Text(text), duration: const Duration(seconds: 6)),
        );
  });
  ref.onDispose(incoming.cancel);
});
