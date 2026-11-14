import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Daily reminder notifications. Implemented natively on Android.
abstract class ReminderService {
  /// True when notifications can be shown right now.
  Future<bool> notificationsAllowed();

  /// Asks for the notification permission (Android 13 and newer).
  Future<bool> requestPermission();

  /// Sets a daily reminder. [messages] are quotes the phone rotates through.
  Future<void> schedule({
    required int hour,
    required int minute,
    required List<String> messages,
  });

  Future<void> cancel();

  /// Shows a notification immediately (used to test). Returns whether it was
  /// allowed to appear.
  Future<bool> showNow(String message);

  Future<void> openNotificationSettings();
}

class PlatformReminderService implements ReminderService {
  static const MethodChannel _channel =
      MethodChannel('com.karthik.mindspark/reminder');

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null; // not running on Android (or in tests)
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<bool> notificationsAllowed() async =>
      (await _invoke<bool>('notificationsAllowed')) ?? false;

  @override
  Future<bool> requestPermission() async =>
      (await _invoke<bool>('requestPermission')) ?? false;

  @override
  Future<void> schedule({
    required int hour,
    required int minute,
    required List<String> messages,
  }) async {
    await _invoke<bool>('schedule', {
      'hour': hour,
      'minute': minute,
      'messages': messages,
    });
  }

  @override
  Future<void> cancel() async {
    await _invoke<bool>('cancel');
  }

  @override
  Future<bool> showNow(String message) async =>
      (await _invoke<bool>('showNow', {'message': message})) ?? false;

  @override
  Future<void> openNotificationSettings() async {
    await _invoke<bool>('openNotificationSettings');
  }
}

final reminderServiceProvider =
    Provider<ReminderService>((ref) => PlatformReminderService());
