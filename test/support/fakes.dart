import 'package:mindspark/core/network/api_client.dart';
import 'package:mindspark/features/auth/auth_models.dart';
import 'package:mindspark/features/auth/auth_repository.dart';
import 'package:mindspark/features/auth/token_store.dart';
import 'package:mindspark/features/sync/account_api.dart';
import 'package:mindspark/models/user_prefs.dart';

const testUser = AuthUser(id: 'u1', name: 'Ann', email: 'ann@example.com');
const testSession = AuthSession(token: 'tok', user: testUser);

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.session]);

  AuthSession? session;

  @override
  Future<AuthSession?> read() async {
    return session;
  }

  @override
  Future<void> write(AuthSession value) async {
    session = value;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.meError});

  /// When set, verifying the token at startup fails with this error.
  final ApiException? meError;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return testSession;
  }

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return testSession;
  }

  @override
  Future<AuthUser> currentUser(String token) async {
    if (meError != null) throw meError!;
    return testUser;
  }
}

/// An in-memory stand-in for the account on the server.
class FakeAccountApi implements AccountApi {
  FakeAccountApi({
    List<String> serverFavorites = const [],
    this.serverPrefs = const UserPrefs(),
  }) : serverFavorites = [...serverFavorites];

  /// Favorite ids on the "server", newest first.
  List<String> serverFavorites;
  UserPrefs serverPrefs;

  /// When set, every call fails with this error (after being recorded).
  ApiException? failWith;

  final List<String> calls = [];
  UserPrefs? lastPushedPrefs;

  void _maybeFail() {
    if (failWith != null) throw failWith!;
  }

  @override
  Future<List<String>> mergeFavorites(String token, List<String> quoteIds) async {
    calls.add('merge:${quoteIds.join(',')}');
    _maybeFail();
    final fresh = quoteIds.where((id) => !serverFavorites.contains(id)).toList();
    serverFavorites = [...fresh, ...serverFavorites];
    return [...serverFavorites];
  }

  @override
  Future<void> addFavorite(String token, String quoteId) async {
    calls.add('add:$quoteId');
    _maybeFail();
    serverFavorites = [quoteId, ...serverFavorites.where((id) => id != quoteId)];
  }

  @override
  Future<void> removeFavorite(String token, String quoteId) async {
    calls.add('remove:$quoteId');
    _maybeFail();
    serverFavorites = serverFavorites.where((id) => id != quoteId).toList();
  }

  @override
  Future<UserPrefs> fetchPreferences(String token) async {
    calls.add('fetchPrefs');
    _maybeFail();
    return serverPrefs;
  }

  @override
  Future<void> updatePreferences(String token, UserPrefs prefs) async {
    calls.add('pushPrefs');
    _maybeFail();
    lastPushedPrefs = prefs;
    serverPrefs = prefs;
  }
}
