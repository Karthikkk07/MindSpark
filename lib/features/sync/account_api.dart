import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/user_prefs.dart';

/// The parts of the MindSpark API used for syncing.
abstract class AccountApi {
  /// Adds these favorites to the account and returns all of the account's
  /// favorite ids, newest first.
  Future<List<String>> mergeFavorites(String token, List<String> quoteIds);

  Future<void> addFavorite(String token, String quoteId);

  Future<void> removeFavorite(String token, String quoteId);

  Future<UserPrefs> fetchPreferences(String token);

  Future<void> updatePreferences(String token, UserPrefs prefs);
}

class ApiAccountApi implements AccountApi {
  ApiAccountApi(this._api);

  final ApiClient _api;

  @override
  Future<List<String>> mergeFavorites(String token, List<String> quoteIds) async {
    final json = await _api.post(
      '/favorites/merge',
      body: {'quoteIds': quoteIds.take(100).toList()},
      token: token,
    );
    final data = (json['data'] as List<dynamic>?) ?? const [];
    return data
        .map((quote) => (quote as Map<String, dynamic>)['id'] as String)
        .toList();
  }

  @override
  Future<void> addFavorite(String token, String quoteId) async {
    await _api.post('/favorites/$quoteId', token: token);
  }

  @override
  Future<void> removeFavorite(String token, String quoteId) async {
    await _api.delete('/favorites/$quoteId', token: token);
  }

  @override
  Future<UserPrefs> fetchPreferences(String token) async {
    final json = await _api.get('/users/preferences', token: token);
    final data = json['data'] as Map<String, dynamic>;
    return UserPrefs(
      interests: ((data['interests'] as List<dynamic>?) ?? const [])
          .map((interest) => interest as String)
          .toSet(),
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == data['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      reminderEnabled: data['reminderEnabled'] as bool? ?? false,
      reminderHour: (data['reminderHour'] as num?)?.toInt() ?? 8,
      reminderMinute: (data['reminderMinute'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> updatePreferences(String token, UserPrefs prefs) async {
    await _api.patch(
      '/users/preferences',
      body: {
        'interests': prefs.interests.toList()..sort(),
        'themeMode': prefs.themeMode.name,
        'reminderEnabled': prefs.reminderEnabled,
        'reminderHour': prefs.reminderHour,
        'reminderMinute': prefs.reminderMinute,
      },
      token: token,
    );
  }
}

final accountApiProvider = Provider<AccountApi>(
  (ref) => ApiAccountApi(ref.watch(apiClientProvider)),
);
