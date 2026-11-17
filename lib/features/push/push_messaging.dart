import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A push notification that arrived while the app was open.
class PushMessage {
  const PushMessage({this.title, this.body});

  final String? title;
  final String? body;
}

/// The phone's side of push notifications (Firebase Cloud Messaging).
abstract class PushMessaging {
  /// Asks for the notification permission (Android 13 and newer).
  Future<bool> requestPermission();

  /// This install's registration token, or null when push is unavailable.
  Future<String?> token();

  /// Emits whenever Firebase issues a new token for this install.
  Stream<String> get onTokenRefresh;

  /// Pushes that arrive while the app is open. Android does not show those
  /// in the notification shade, so the app shows them itself.
  Stream<PushMessage> get onForegroundMessage;
}

/// Used in tests and when Firebase is not set up.
class NoopPushMessaging implements PushMessaging {
  const NoopPushMessaging();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream<String>.empty();

  @override
  Stream<PushMessage> get onForegroundMessage => const Stream<PushMessage>.empty();
}

class FirebasePushMessaging implements PushMessaging {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() async {
    try {
      // getToken is deprecated in favour of installation IDs, which the
      // server (firebase-admin token sends) does not use yet.
      // ignore: deprecated_member_use
      return await _messaging.getToken();
    } catch (error) {
      debugPrint('Could not get a push token: $error');
      return null;
    }
  }

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushMessage> get onForegroundMessage => FirebaseMessaging.onMessage.map(
        (message) => PushMessage(
          title: message.notification?.title,
          body: message.notification?.body,
        ),
      );
}

/// Overridden in main() with [FirebasePushMessaging] when Firebase started.
final pushMessagingProvider = Provider<PushMessaging>(
  (ref) => const NoopPushMessaging(),
);
