import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

/// The server's answer to a test push.
class PushTestResult {
  const PushTestResult({required this.sent, required this.devices, this.errors = const []});

  /// Devices Firebase accepted the message for.
  final int sent;

  /// Devices registered for the account.
  final int devices;

  /// Why Firebase refused some devices, as "token ending: reason".
  final List<String> errors;
}

/// The parts of the MindSpark API used for push notifications.
abstract class DevicesApi {
  /// Tells the server to send push notifications to this install.
  Future<void> register(String authToken, String pushToken);

  Future<void> unregister(String authToken, String pushToken);

  /// Sends a test push to the account's devices.
  /// With [delaySeconds] the server waits first, so the app can be closed.
  Future<PushTestResult> sendTest(String authToken, {int delaySeconds = 0});
}

class ApiDevicesApi implements DevicesApi {
  ApiDevicesApi(this._api);

  final ApiClient _api;

  @override
  Future<void> register(String authToken, String pushToken) async {
    await _api.post('/devices', body: {'token': pushToken}, token: authToken);
  }

  @override
  Future<void> unregister(String authToken, String pushToken) async {
    await _api.post(
      '/devices/unregister',
      body: {'token': pushToken},
      token: authToken,
    );
  }

  @override
  Future<PushTestResult> sendTest(String authToken, {int delaySeconds = 0}) async {
    final json = await _api.post(
      '/devices/test',
      body: {if (delaySeconds > 0) 'delaySeconds': delaySeconds},
      token: authToken,
    );
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      return const PushTestResult(sent: 0, devices: 0);
    }
    return PushTestResult(
      sent: data['sent'] as int? ?? 0,
      devices: data['devices'] as int? ?? 0,
      errors: [for (final e in (data['errors'] as List<dynamic>? ?? const [])) '$e'],
    );
  }
}

final devicesApiProvider = Provider<DevicesApi>(
  (ref) => ApiDevicesApi(ref.watch(apiClientProvider)),
);
