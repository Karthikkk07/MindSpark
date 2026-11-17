import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

/// The parts of the MindSpark API used for push notifications.
abstract class DevicesApi {
  /// Tells the server to send push notifications to this install.
  Future<void> register(String authToken, String pushToken);

  Future<void> unregister(String authToken, String pushToken);

  /// Sends a test push to the account's devices. Returns how many got it.
  /// With [delaySeconds] the server waits first, so the app can be closed.
  Future<int> sendTest(String authToken, {int delaySeconds = 0});
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
  Future<int> sendTest(String authToken, {int delaySeconds = 0}) async {
    final json = await _api.post(
      '/devices/test',
      body: {if (delaySeconds > 0) 'delaySeconds': delaySeconds},
      token: authToken,
    );
    final data = json['data'];
    return data is Map<String, dynamic> ? (data['sent'] as int? ?? 0) : 0;
  }
}

final devicesApiProvider = Provider<DevicesApi>(
  (ref) => ApiDevicesApi(ref.watch(apiClientProvider)),
);
