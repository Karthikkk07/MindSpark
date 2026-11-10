import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindspark/app.dart';
import 'package:mindspark/core/network/api_client.dart';
import 'package:mindspark/core/prefs/user_prefs_controller.dart';
import 'package:mindspark/features/auth/auth_controller.dart';
import 'package:mindspark/features/auth/auth_models.dart';
import 'package:mindspark/features/auth/auth_repository.dart';
import 'package:mindspark/features/auth/token_store.dart';
import 'package:mindspark/features/quotes/quote_providers.dart';
import 'package:mindspark/models/quote.dart';
import 'package:mindspark/repositories/prefs_repository.dart';
import 'package:mindspark/repositories/quote_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _user = AuthUser(id: 'u1', name: 'Ann', email: 'ann@example.com');
const _session = AuthSession(token: 'tok', user: _user);

const _quote = Quote(
  id: 'only',
  text: 'Only test quote.',
  author: 'Tester',
  category: 'study',
  tags: ['test'],
  source: 's',
  license: 'l',
);

class _FakeQuoteRepository implements QuoteRepository {
  @override
  Future<List<Quote>> loadAll() async => const [_quote];
}

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore([this.session]);

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

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.error, this.meError});

  final ApiException? error;
  final ApiException? meError;
  final List<String> calls = [];

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    calls.add('login:$email');
    if (error != null) throw error!;
    return _session;
  }

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    calls.add('register:$name:$email');
    if (error != null) throw error!;
    return _session;
  }

  @override
  Future<AuthUser> currentUser(String token) async {
    if (meError != null) throw meError!;
    return _user;
  }
}

ProviderContainer __makeContainer({
  _MemoryTokenStore? store,
  _FakeAuthRepository? repo,
}) {
  final container = ProviderContainer(overrides: [
    tokenStoreProvider.overrideWithValue(store ?? _MemoryTokenStore()),
    authRepositoryProvider.overrideWithValue(repo ?? _FakeAuthRepository()),
  ]);
  addTearDown(container.dispose);
  return container;
}

Future<SharedPreferences> __pumpApp(
  WidgetTester tester, {
  _MemoryTokenStore? store,
  _FakeAuthRepository? repo,
  Map<String, Object> initial = const {
    PrefsRepository.keyOnboardingComplete: true,
  },
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        quoteRepositoryProvider.overrideWithValue(_FakeQuoteRepository()),
        tokenStoreProvider.overrideWithValue(store ?? _MemoryTokenStore()),
        authRepositoryProvider.overrideWithValue(repo ?? _FakeAuthRepository()),
      ],
      child: const MindSparkApp(),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

Future<void> openAuthFromSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sign in or create an account'));
  await tester.pumpAndSettle();
}

Future<void> fillSignIn(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email'),
    'ann@example.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    'password123',
  );
}

void main() {
  group('ApiClient', () {
    test('sends a JSON body and the bearer token, and parses the reply',
        () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'http://x/api',
        client: MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );

      final json = await client.post('/things', body: {'a': 1}, token: 'tok');

      expect(json, {'ok': true});
      expect(seen.url.toString(), 'http://x/api/things');
      expect(seen.headers['Authorization'], 'Bearer tok');
      expect(jsonDecode(seen.body), {'a': 1});
    });

    test('maps a server error to an ApiException', () async {
      final client = ApiClient(
        baseUrl: 'http://x/api',
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'error': {
                  'code': 'invalid_credentials',
                  'message': 'Invalid email or password',
                },
              }),
              401,
            )),
      );

      await expectLater(
        client.post('/auth/login', body: {}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'invalid_credentials')
              .having((e) => e.status, 'status', 401)
              .having((e) => e.isUnauthorized, 'isUnauthorized', true),
        ),
      );
    });

    test('a connection failure becomes a network error', () async {
      final client = ApiClient(
        baseUrl: 'http://x/api',
        client: MockClient((_) async => throw http.ClientException('down')),
      );

      await expectLater(
        client.get('/health'),
        throwsA(isA<ApiException>().having((e) => e.isNetworkError, 'network', true)),
      );
    });

    test('a non-JSON error body gives a generic error', () async {
      final client = ApiClient(
        baseUrl: 'http://x/api',
        client: MockClient((_) async => http.Response('<html>bad gateway</html>', 502)),
      );

      await expectLater(
        client.get('/health'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 502)
              .having((e) => e.code, 'code', 'error'),
        ),
      );
    });
  });

  group('AuthController', () {
    test('starts signed out', () async {
      final container = __makeContainer();
      expect(await container.read(authControllerProvider.future), isNull);
    });

    test('login keeps the session in memory and in storage', () async {
      final store = _MemoryTokenStore();
      final container = __makeContainer(store: store);
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .login(email: 'ann@example.com', password: 'password123');

      expect(container.read(authControllerProvider).value?.user.email, 'ann@example.com');
      expect(store.session?.token, 'tok');
    });

    test('register keeps the session', () async {
      final repo = _FakeAuthRepository();
      final container = __makeContainer(repo: repo);
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).register(
            name: 'Ann',
            email: 'ann@example.com',
            password: 'password123',
          );

      expect(repo.calls, ['register:Ann:ann@example.com']);
      expect(container.read(authControllerProvider).value?.user.name, 'Ann');
    });

    test('a stored session is restored on startup', () async {
      final container = __makeContainer(store: _MemoryTokenStore(_session));
      final session = await container.read(authControllerProvider.future);
      expect(session?.token, 'tok');
    });

    test('a failed login throws and leaves the user signed out', () async {
      final store = _MemoryTokenStore();
      final container = __makeContainer(
        store: store,
        repo: _FakeAuthRepository(
          error: const ApiException(
            code: 'invalid_credentials',
            message: 'Invalid email or password',
            status: 401,
          ),
        ),
      );
      await container.read(authControllerProvider.future);

      await expectLater(
        container
            .read(authControllerProvider.notifier)
            .login(email: 'ann@example.com', password: 'wrong'),
        throwsA(isA<ApiException>()),
      );

      expect(container.read(authControllerProvider).value, isNull);
      expect(store.session, isNull);
    });

    test('sign out clears the session', () async {
      final store = _MemoryTokenStore(_session);
      final container = __makeContainer(store: store);
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).signOut();

      expect(container.read(authControllerProvider).value, isNull);
      expect(store.session, isNull);
    });

    test('a rejected token signs the user out after startup', () async {
      final store = _MemoryTokenStore(_session);
      final container = __makeContainer(
        store: store,
        repo: _FakeAuthRepository(
          meError: const ApiException(
            code: 'unauthorized',
            message: 'Invalid or expired token',
            status: 401,
          ),
        ),
      );

      await container.read(authControllerProvider.future);
      await pumpEventQueue();

      expect(container.read(authControllerProvider).value, isNull);
      expect(store.session, isNull);
    });

    test('being offline at startup keeps the user signed in', () async {
      final store = _MemoryTokenStore(_session);
      final container = __makeContainer(
        store: store,
        repo: _FakeAuthRepository(
          meError: const ApiException(code: 'network', message: 'offline'),
        ),
      );

      await container.read(authControllerProvider.future);
      await pumpEventQueue();

      expect(container.read(authControllerProvider).value?.token, 'tok');
      expect(store.session, isNotNull);
    });
  });

  group('account screens', () {
    testWidgets('Settings offers sign in to guests', (tester) async {
      await __pumpApp(tester);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      expect(
        find.text('You are using MindSpark as a guest. Your data stays on this device.'),
        findsOneWidget,
      );
      expect(find.text('Sign in or create an account'), findsOneWidget);
    });

    testWidgets('sign in checks the input before calling the server',
        (tester) async {
      final repo = _FakeAuthRepository();
      await __pumpApp(tester, repo: repo);
      await openAuthFromSettings(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('signing in reaches Home and shows the account in Settings',
        (tester) async {
      final repo = _FakeAuthRepository();
      await __pumpApp(tester, repo: repo);
      await openAuthFromSettings(tester);

      await fillSignIn(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['login:ann@example.com']);
      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('ann@example.com'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('a failed sign in shows the server message', (tester) async {
      await __pumpApp(
        tester,
        repo: _FakeAuthRepository(
          error: const ApiException(
            code: 'invalid_credentials',
            message: 'Invalid email or password',
            status: 401,
          ),
        ),
      );
      await openAuthFromSettings(tester);

      await fillSignIn(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('creating an account needs a name and a longer password',
        (tester) async {
      final repo = _FakeAuthRepository();
      await __pumpApp(tester, repo: repo);
      await openAuthFromSettings(tester);

      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Name'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Ann');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'ann@example.com',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'short');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Use at least 8 characters'), findsOneWidget);
      expect(repo.calls, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['register:Ann:ann@example.com']);
    });

    testWidgets('sign out returns to guest mode', (tester) async {
      final store = _MemoryTokenStore(_session);
      await __pumpApp(tester, store: store);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in or create an account'), findsOneWidget);
      expect(store.session, isNull);
    });

    testWidgets('onboarding can lead to sign in and then finishes',
        (tester) async {
      final prefs = await __pumpApp(tester, initial: {});

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Sign in or create an account'));
      await tester.pumpAndSettle();

      await fillSignIn(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(prefs.getBool(PrefsRepository.keyOnboardingComplete), isTrue);
    });
  });
}
