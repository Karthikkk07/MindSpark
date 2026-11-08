import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'auth_models.dart';
import 'auth_repository.dart';
import 'token_store.dart';

/// The signed-in session, or null for a guest.
class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    AuthSession? session;
    try {
      session = await ref.read(tokenStoreProvider).read();
    } catch (_) {
      session = null; // secure storage unavailable: behave as a guest
    }
    if (session != null) {
      final stored = session;
      // After startup finishes, confirm the token is still accepted.
      unawaited(Future<void>(() => _verify(stored)));
    }
    return session;
  }

  Future<void> _verify(AuthSession session) async {
    try {
      await ref.read(authRepositoryProvider).currentUser(session.token);
    } on ApiException catch (error) {
      // Only a rejected token signs the user out; being offline does not.
      if (error.isUnauthorized) await signOut();
    }
  }

  Future<void> login({required String email, required String password}) async {
    final session = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    await _save(session);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final session = await ref
        .read(authRepositoryProvider)
        .register(name: name, email: email, password: password);
    await _save(session);
  }

  Future<void> signOut() async {
    try {
      await ref.read(tokenStoreProvider).clear();
    } catch (_) {
      // Nothing more to clear.
    }
    state = const AsyncData(null);
  }

  Future<void> _save(AuthSession session) async {
    try {
      await ref.read(tokenStoreProvider).write(session);
    } catch (_) {
      // Could not persist: the user stays signed in until the app closes.
    }
    state = AsyncData(session);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

/// The current session (null for a guest or while loading).
final currentSessionProvider = Provider<AuthSession?>(
  (ref) => ref.watch(authControllerProvider).value,
);
