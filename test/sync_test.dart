import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindspark/app.dart';
import 'package:mindspark/core/network/api_client.dart';
import 'package:mindspark/core/prefs/user_prefs_controller.dart';
import 'package:mindspark/features/auth/auth_controller.dart';
import 'package:mindspark/features/auth/auth_repository.dart';
import 'package:mindspark/features/auth/token_store.dart';
import 'package:mindspark/features/favorites/favorites_providers.dart';
import 'package:mindspark/features/quotes/quote_providers.dart';
import 'package:mindspark/features/sync/account_api.dart';
import 'package:mindspark/features/sync/goals_sync.dart';
import 'package:mindspark/features/sync/sync_controller.dart';
import 'package:mindspark/features/sync/sync_state.dart';
import 'package:mindspark/models/quote.dart';
import 'package:mindspark/models/user_prefs.dart';
import 'package:mindspark/repositories/favorites_repository.dart';
import 'package:mindspark/repositories/prefs_repository.dart';
import 'package:mindspark/repositories/quote_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';
import 'support/goals_fakes.dart';

const _offline = ApiException(code: 'network', message: 'offline');
const _expired = ApiException(
  code: 'unauthorized',
  message: 'Invalid or expired token',
  status: 401,
);

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

 dynamic _overrides(
  SharedPreferences prefs,
  FakeAccountApi api, {
  required bool signedIn,
  required bool startupSync,
}) {
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    tokenStoreProvider.overrideWithValue(
      MemoryTokenStore(signedIn ? testSession : null),
    ),
    authRepositoryProvider.overrideWithValue(
      FakeAuthRepository(meError: startupSync ? null : _offline),
    ),
    accountApiProvider.overrideWithValue(api),
    goalsApiProvider.overrideWithValue(FakeGoalsApi()),
    quoteRepositoryProvider.overrideWithValue(_FakeQuoteRepository()),
  ];
}

Future<ProviderContainer> _makeContainer(
  FakeAccountApi api, {
  Map<String, Object> initial = const {},
  bool signedIn = true,
  bool startupSync = false,
}) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: _overrides(prefs, api, signedIn: signedIn, startupSync: startupSync),
  );
  addTearDown(container.dispose);
  await container.read(authControllerProvider.future);
  await pumpEventQueue();
  return container;
}

SyncState _syncState(ProviderContainer container) =>
    SyncStateRepository(container.read(sharedPreferencesProvider)).load();

Future<void> _pumpApp(WidgetTester tester, FakeAccountApi api) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    PrefsRepository.keyOnboardingComplete: true,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(prefs, api, signedIn: true, startupSync: true),
      child: const MindSparkApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('favorites sync', () {
    test('syncing merges the device favorites into the account', () async {
      final api = FakeAccountApi(serverFavorites: ['c']);
      final container = await _makeContainer(
        api,
        initial: {FavoritesRepository.keyFavoriteIds: ['a', 'b']},
      );

      await container.read(syncControllerProvider.notifier).syncNow();

      expect(api.calls, contains('merge:a,b'));
      expect(container.read(favoritesProvider), ['a', 'b', 'c']);
      expect(container.read(syncControllerProvider).phase, SyncPhase.synced);
    });

    test('removals made offline are sent first and not re-added', () async {
      final api = FakeAccountApi(serverFavorites: ['a', 'c']);
      final container = await _makeContainer(
        api,
        initial: {
          FavoritesRepository.keyFavoriteIds: ['a', 'b'],
          SyncStateRepository.keyPendingRemoves: ['a'],
        },
      );

      await container.read(syncControllerProvider.notifier).syncNow();

      expect(api.calls.take(2), ['remove:a', 'merge:b']);
      expect(container.read(favoritesProvider), ['b', 'c']);
      expect(_syncState(container).pendingRemoves, isEmpty);
    });

    test('a favorite toggled while signed in is sent to the account', () async {
      final api = FakeAccountApi();
      final container = await _makeContainer(api);

      await container.read(favoritesProvider.notifier).toggle('x');
      await pumpEventQueue();
      await container.read(favoritesProvider.notifier).toggle('x');
      await pumpEventQueue();

      expect(api.calls, ['add:x', 'remove:x']);
    });

    test('a removal made offline is queued and applied at the next sync',
        () async {
      final api = FakeAccountApi(serverFavorites: ['x']);
      final container = await _makeContainer(
        api,
        initial: {FavoritesRepository.keyFavoriteIds: ['x']},
      );

      api.failWith = _offline;
      await container.read(favoritesProvider.notifier).toggle('x');
      await pumpEventQueue();
      expect(_syncState(container).pendingRemoves, {'x'});

      api.failWith = null;
      api.calls.clear();
      await container.read(syncControllerProvider.notifier).syncNow();

      expect(api.calls.take(2), ['remove:x', 'merge:']);
      expect(container.read(favoritesProvider), isEmpty);
      expect(api.serverFavorites, isEmpty);
    });
  });

  group('settings sync', () {
    test('signing in uses the account settings', () async {
      final api = FakeAccountApi(
        serverPrefs: const UserPrefs(
          interests: {'coding'},
          themeMode: ThemeMode.dark,
        ),
      );
      final container = await _makeContainer(api);

      await container.read(syncControllerProvider.notifier).syncNow();

      final prefs = container.read(userPrefsProvider);
      expect(prefs.interests, {'coding'});
      expect(prefs.themeMode, ThemeMode.dark);
      expect(api.calls, isNot(contains('pushPrefs')));
    });

    test('a new account takes this device settings', () async {
      final api = FakeAccountApi();
      final container = await _makeContainer(
        api,
        initial: {PrefsRepository.keyInterests: ['study']},
      );

      await container.read(syncControllerProvider.notifier).syncNow(pushPrefs: true);

      expect(api.lastPushedPrefs?.interests, {'study'});
      expect(api.calls, isNot(contains('fetchPrefs')));
    });

    test('unsent local changes win over the account settings', () async {
      final api = FakeAccountApi();
      final container = await _makeContainer(
        api,
        initial: {
          PrefsRepository.keyThemeMode: 'dark',
          SyncStateRepository.keyPrefsDirty: true,
        },
      );

      await container.read(syncControllerProvider.notifier).syncNow();

      expect(api.calls, contains('pushPrefs'));
      expect(api.calls, isNot(contains('fetchPrefs')));
      expect(container.read(userPrefsProvider).themeMode, ThemeMode.dark);
      expect(_syncState(container).prefsDirty, isFalse);
    });

    test('a setting changed while signed in is sent to the account', () async {
      final api = FakeAccountApi();
      final container = await _makeContainer(api);

      await container.read(userPrefsProvider.notifier).setThemeMode(ThemeMode.dark);
      await pumpEventQueue();

      expect(api.lastPushedPrefs?.themeMode, ThemeMode.dark);
      expect(_syncState(container).prefsDirty, isFalse);
    });

    test('a setting changed offline stays unsent until the next sync', () async {
      final api = FakeAccountApi()..failWith = _offline;
      final container = await _makeContainer(api);

      await container.read(userPrefsProvider.notifier).setThemeMode(ThemeMode.dark);
      await pumpEventQueue();
      expect(_syncState(container).prefsDirty, isTrue);
      expect(container.read(syncControllerProvider).phase, SyncPhase.failed);

      api.failWith = null;
      await container.read(syncControllerProvider.notifier).syncNow();

      expect(api.lastPushedPrefs?.themeMode, ThemeMode.dark);
      expect(_syncState(container).prefsDirty, isFalse);
    });
  });

  group('sync behaviour', () {
    test('guest changes are never sent anywhere', () async {
      final api = FakeAccountApi();
      final container = await _makeContainer(api, signedIn: false);

      await container.read(favoritesProvider.notifier).toggle('x');
      await container.read(userPrefsProvider.notifier).setThemeMode(ThemeMode.dark);
      await pumpEventQueue();

      expect(api.calls, isEmpty);
    });

    test('being offline keeps local data and says so', () async {
      final api = FakeAccountApi()..failWith = _offline;
      final container = await _makeContainer(
        api,
        initial: {FavoritesRepository.keyFavoriteIds: ['a']},
      );

      await container.read(syncControllerProvider.notifier).syncNow();

      expect(container.read(favoritesProvider), ['a']);
      final status = container.read(syncControllerProvider);
      expect(status.phase, SyncPhase.failed);
      expect(status.message, 'Offline: changes will sync later.');
    });

    test('a rejected token during sync signs the user out', () async {
      final api = FakeAccountApi()..failWith = _expired;
      final container = await _makeContainer(api);

      await container.read(syncControllerProvider.notifier).syncNow();

      expect(container.read(authControllerProvider).value, isNull);
      expect(
        container.read(syncControllerProvider).message,
        'Your session expired. Please sign in again.',
      );
    });

    test('a sync runs after the token is verified at startup', () async {
      final api = FakeAccountApi();
      await _makeContainer(
        api,
        startupSync: true,
        initial: {FavoritesRepository.keyFavoriteIds: ['a']},
      );

      expect(api.calls, contains('merge:a'));
    });
  });

  group('settings screen', () {
    testWidgets('shows the sync status and a Sync now button', (tester) async {
      final api = FakeAccountApi();
      await _pumpApp(tester, api);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Synced'), findsOneWidget);

      await tester.tap(find.text('Sync now'));
      await tester.pumpAndSettle();

      final merges = api.calls.where((call) => call.startsWith('merge')).length;
      expect(merges, 2);
    });

    testWidgets('says when the account cannot be reached', (tester) async {
      final api = FakeAccountApi()..failWith = _offline;
      await _pumpApp(tester, api);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Offline: changes will sync later.'), findsOneWidget);
    });
  });
}
