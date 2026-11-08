import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'auth_models.dart';

abstract class AuthRepository {
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthSession> login({required String email, required String password});

  Future<AuthUser> currentUser(String token);
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);

  final ApiClient _api;

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final json = await _api.post(
      '/auth/register',
      body: {'name': name, 'email': email, 'password': password},
    );
    return AuthSession.fromResponse(json);
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final json = await _api.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthSession.fromResponse(json);
  }

  @override
  Future<AuthUser> currentUser(String token) async {
    final json = await _api.get('/auth/me', token: token);
    return AuthUser.fromJson(json['user'] as Map<String, dynamic>);
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(ref.watch(apiClientProvider)),
);
