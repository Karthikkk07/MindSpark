import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindspark/core/prefs/user_prefs_controller.dart';
import 'package:mindspark/core/telemetry/telemetry_service.dart';
import 'package:mindspark/features/auth/auth_controller.dart';
import 'package:mindspark/features/auth/token_store.dart';
import 'package:mindspark/features/auth/auth_repository.dart';
import 'package:mindspark/features/push/devices_api.dart';
import 'package:mindspark/features/push/push_messaging.dart';
import 'package:mindspark/features/push/push_registration.dart';
import 'package:mindspark/features/settings/settings_screen.dart';
import 'package:mindspark/features/sync/account_api.dart';
import 'package:mindspark/features/sync/goals_sync.dart';
import 'package:mindspark/repositories/prefs_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';
import 'support/goals_fakes.dart';

class _RecordingTelemetry extends NoopTelemetryService {
  _RecordingTelemetry();

  final List<bool> enabledCalls = [];
  final List<String> events = [];

  @override
  Future<void> setEnabled(bool enabled) async => enabledCalls.add(enabled);

  @override
  Future<void> logEvent(String name, [Map<String, Object>? params]) async =>
      events.add(name);
}

class _FakePush implements PushMessaging {
  _FakePush({this.allowed = true});

  bool allowed;
  String? pushToken = 'fcm-token';
  final refreshes = StreamController<String>.broadcast();

  @override
  Future<bool> requestPermission() async => allowed;

  @override
  Future<String?> token() async => pushToken;

  @override
  Stream<String> get onTokenRefresh => refreshes.stream;
}

class _FakeDevicesApi implements DevicesApi {
  final List<String> calls = [];
  int testResult = 1;

  @override
  Future<void> register(String authToken, String pushToken) async =>
      calls.add('register:$authToken:$pushToken');

  @override
  Future<void> unregister(String authToken, String pushToken) async =>
      calls.add('unregister:$authToken:$pushToken');

  @override
  Future<int> sendTest(String authToken) async {
    calls.add('test:$authToken');
    return testResult;
  }
}

class _Setup {
  _Setup(this.container, this.telemetry, this.push, this.devices, this.store);

  final ProviderContainer container;
  final _RecordingTelemetry telemetry;
  final _FakePush push;
  final _FakeDevicesApi devices;
  final MemoryTokenStore store;

  UserPrefsController get prefs => container.read(userPrefsProvider.notifier);
}

Future<_Setup> _setup({bool signedIn = false, _FakePush? push}) async {
  SharedPreferences.setMockInitialValues({'onboarding_complete': true});
  final prefs = await SharedPreferences.getInstance();
  final telemetry = _RecordingTelemetry();
  final fakePush = push ?? _FakePush();
  final devices = _FakeDevicesApi();
  final store = MemoryTokenStore(signedIn ? testSession : null);

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      telemetryServiceProvider.overrideWithValue(telemetry),
      pushMessagingProvider.overrideWithValue(fakePush),
      devicesApiProvider.overrideWithValue(devices),
      tokenStoreProvider.overrideWithValue(store),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      accountApiProvider.overrideWithValue(FakeAccountApi()),
      goalsApiProvider.overrideWithValue(FakeGoalsApi()),
    ],
  );
  addTearDown(container.dispose);
  // Wait for the stored session to load, then start push syncing.
  await container.read(authControllerProvider.future);
  container.read(pushSyncProvider);
  await Future<void>.delayed(Duration.zero);
  return _Setup(container, telemetry, fakePush, devices, store);
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('privacy switch', () {
    test('collection is off by default and the choice is remembered', () async {
      final s = await _setup();
      expect(s.container.read(userPrefsProvider).analyticsEnabled, isFalse);

      await s.prefs.setAnalyticsEnabled(true);
      expect(s.telemetry.enabledCalls, [true]);
      final saved = PrefsRepository(s.container.read(sharedPreferencesProvider)).load();
      expect(saved.analyticsEnabled, isTrue);

      await s.prefs.setAnalyticsEnabled(false);
      expect(s.telemetry.enabledCalls, [true, false]);
      expect(s.container.read(userPrefsProvider).analyticsEnabled, isFalse);
    });

    test('the choice stays on the device and is not synced', () async {
      final s = await _setup();
      await s.prefs.setAnalyticsEnabled(true);
      await s.prefs.setPushEnabled(true);

      // Applying the account's settings keeps the local choices.
      await s.prefs.applyRemote(s.container.read(userPrefsProvider).copyWith(
            analyticsEnabled: false,
            pushEnabled: false,
          ));
      final prefs = s.container.read(userPrefsProvider);
      expect(prefs.analyticsEnabled, isTrue);
      expect(prefs.pushEnabled, isTrue);
    });
  });

  group('push registration', () {
    test('guests cannot switch push on', () async {
      final s = await _setup();
      final result = await s.container.read(pushRegistrationProvider).enable();
      expect(result, PushEnableResult.notSignedIn);
      expect(s.container.read(userPrefsProvider).pushEnabled, isFalse);
      expect(s.devices.calls, isEmpty);
    });

    test('a refused permission leaves push off', () async {
      final s = await _setup(signedIn: true, push: _FakePush(allowed: false));
      final result = await s.container.read(pushRegistrationProvider).enable();
      expect(result, PushEnableResult.permissionDenied);
      expect(s.container.read(userPrefsProvider).pushEnabled, isFalse);
      expect(s.devices.calls, isEmpty);
    });

    test('switching on registers this phone, and a new token replaces it', () async {
      final s = await _setup(signedIn: true);
      final result = await s.container.read(pushRegistrationProvider).enable();
      await _settle();

      expect(result, PushEnableResult.enabled);
      expect(s.container.read(userPrefsProvider).pushEnabled, isTrue);
      expect(s.devices.calls, ['register:tok:fcm-token']);

      s.push.pushToken = 'fcm-token-2';
      s.push.refreshes.add('fcm-token-2');
      await _settle();
      expect(s.devices.calls.last, 'register:tok:fcm-token-2');
    });

    test('switching off unregisters this phone', () async {
      final s = await _setup(signedIn: true);
      final registration = s.container.read(pushRegistrationProvider);
      await registration.enable();
      await _settle();
      s.devices.calls.clear();

      await registration.disable();
      expect(s.container.read(userPrefsProvider).pushEnabled, isFalse);
      expect(s.devices.calls, ['unregister:tok:fcm-token']);
    });

    test('signing out unregisters this phone', () async {
      final s = await _setup(signedIn: true);
      await s.container.read(pushRegistrationProvider).enable();
      await _settle();
      s.devices.calls.clear();

      await s.container.read(authControllerProvider.notifier).signOut();
      // Unit tests have no frames, so derived providers update when read.
      expect(s.container.read(currentSessionProvider), isNull);
      await _settle();
      expect(s.devices.calls, ['unregister:tok:fcm-token']);
    });

    test('nothing is registered while push is off', () async {
      final s = await _setup(signedIn: true);
      s.push.refreshes.add('other');
      await _settle();
      expect(s.devices.calls, isEmpty);
    });

    test('a phone with push already on registers itself at start-up', () async {
      SharedPreferences.setMockInitialValues({'push_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final devices = _FakeDevicesApi();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          pushMessagingProvider.overrideWithValue(_FakePush()),
          devicesApiProvider.overrideWithValue(devices),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore(testSession)),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          accountApiProvider.overrideWithValue(FakeAccountApi()),
          goalsApiProvider.overrideWithValue(FakeGoalsApi()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      container.read(pushSyncProvider);
      await _settle();
      expect(devices.calls, ['register:tok:fcm-token']);
    });
  });

  group('settings screen', () {
    Future<_Setup> pumpSettings(WidgetTester tester, {bool signedIn = false}) async {
      late _Setup setup;
      await tester.runAsync(() async => setup = await _setup(signedIn: signedIn));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: setup.container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      return setup;
    }

    testWidgets('the privacy switch turns reports on and off', (tester) async {
      final s = await pumpSettings(tester);
      final finder = find.widgetWithText(SwitchListTile, 'Share usage and crash reports');
      await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);

      expect(tester.widget<SwitchListTile>(finder).value, isFalse);
      await tester.tap(finder);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(finder).value, isTrue);
      expect(s.telemetry.enabledCalls, [true]);
    });

    testWidgets('guests see the push switch disabled', (tester) async {
      await pumpSettings(tester);
      final finder = find.widgetWithText(SwitchListTile, 'Push notifications');
      await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);

      final tile = tester.widget<SwitchListTile>(finder);
      expect(tile.onChanged, isNull);
      expect(find.text('Sign in to turn this on'), findsOneWidget);
    });

    testWidgets('signed-in users can turn push on and send a test', (tester) async {
      final s = await pumpSettings(tester, signedIn: true);
      final finder = find.widgetWithText(SwitchListTile, 'Push notifications');
      await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);

      await tester.tap(finder);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(s.container.read(userPrefsProvider).pushEnabled, isTrue);

      final testButton = find.text('Send a test push');
      await tester.scrollUntilVisible(testButton, 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(testButton);
      await tester.pump();
      expect(s.devices.calls, contains('test:tok'));
      expect(find.text('Test push sent. It should arrive in a moment.'), findsOneWidget);
    });
  });
}
