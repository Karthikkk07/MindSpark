import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindspark/app.dart';
import 'package:mindspark/core/platform/share_service.dart';
import 'package:mindspark/core/prefs/user_prefs_controller.dart';
import 'package:mindspark/features/favorites/favorites_providers.dart';
import 'package:mindspark/features/quotes/quote_providers.dart';
import 'package:mindspark/features/quotes/widgets/quote_tile.dart';
import 'package:mindspark/models/quote.dart';
import 'package:mindspark/repositories/favorites_repository.dart';
import 'package:mindspark/repositories/prefs_repository.dart';
import 'package:mindspark/repositories/quote_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _only = Quote(
  id: 'only',
  text: 'Only test quote.',
  author: 'Tester',
  category: 'study',
  tags: ['test'],
  source: 'Test source',
  license: 'Test license',
);

class _FakeQuoteRepository implements QuoteRepository {
  @override
  Future<List<Quote>> loadAll() async => const [_only];
}

class _FakeShareService implements ShareService {
  _FakeShareService({this.fail = false});

  final bool fail;
  final List<String> shared = [];

  @override
  Future<void> shareText(String text) async {
    if (fail) throw PlatformException(code: 'unavailable');
    shared.add(text);
  }
}

Future<SharedPreferences> pumpApp(
  WidgetTester tester, {
  Map<String, Object> initial = const {
    PrefsRepository.keyOnboardingComplete: true,
  },
  ShareService? share,
}) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        quoteRepositoryProvider.overrideWithValue(_FakeQuoteRepository()),
        if (share != null) shareServiceProvider.overrideWithValue(share),
      ],
      child: const MindSparkApp(),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

Future<void> goToTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('favorites storage and state', () {
    test('toggle adds newest first and removes on the second toggle',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      final controller = container.read(favoritesProvider.notifier);
      await controller.toggle('a');
      await controller.toggle('b');
      expect(container.read(favoritesProvider), ['b', 'a']);

      await controller.toggle('a');
      expect(container.read(favoritesProvider), ['b']);
      expect(prefs.getStringList(FavoritesRepository.keyFavoriteIds), ['b']);
    });

    test('the repository drops duplicate ids when loading', () async {
      SharedPreferences.setMockInitialValues({
        FavoritesRepository.keyFavoriteIds: ['a', 'b', 'a'],
      });
      final repo = FavoritesRepository(await SharedPreferences.getInstance());

      expect(repo.load(), ['a', 'b']);
    });
  });

  group('native share service', () {
    test('calls the native shareText method with the text', () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('com.karthik.mindspark/share');
      MethodCall? received;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        received = call;
        return null;
      });
      addTearDown(() {
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      });

      await PlatformShareService().shareText('hello');

      expect(received?.method, 'shareText');
      expect(received?.arguments, {'text': 'hello'});
    });
  });

  group('favorites in the app', () {
    testWidgets('a quote can be saved and removed on Home', (tester) async {
      final prefs = await pumpApp(tester);

      await tester.tap(find.byTooltip('Add to favorites'));
      await tester.pumpAndSettle();
      expect(
        prefs.getStringList(FavoritesRepository.keyFavoriteIds),
        ['only'],
      );
      expect(find.byTooltip('Remove from favorites'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove from favorites'));
      await tester.pumpAndSettle();
      expect(prefs.getStringList(FavoritesRepository.keyFavoriteIds), isEmpty);
    });

    testWidgets('the Favorites tab starts empty, then lists saved quotes',
        (tester) async {
      await pumpApp(tester);

      await goToTab(tester, 'Favorites');
      expect(find.text('No favorites yet'), findsOneWidget);

      await goToTab(tester, 'Home');
      await tester.tap(find.byTooltip('Add to favorites'));
      await tester.pumpAndSettle();

      await goToTab(tester, 'Favorites');
      expect(find.byType(QuoteTile), findsOneWidget);
      expect(find.text(_only.text), findsOneWidget);
    });

    testWidgets('saved favorites are loaded when the app starts',
        (tester) async {
      await pumpApp(tester, initial: {
        PrefsRepository.keyOnboardingComplete: true,
        FavoritesRepository.keyFavoriteIds: ['only'],
      });

      expect(find.byTooltip('Remove from favorites'), findsOneWidget);
    });

    testWidgets('a favorite can be removed from the Favorites list',
        (tester) async {
      await pumpApp(tester, initial: {
        PrefsRepository.keyOnboardingComplete: true,
        FavoritesRepository.keyFavoriteIds: ['only'],
      });

      await goToTab(tester, 'Favorites');
      await tester.tap(find.byTooltip('Remove from favorites'));
      await tester.pumpAndSettle();

      expect(find.text('No favorites yet'), findsOneWidget);
    });
  });

  group('sharing in the app', () {
    testWidgets('Share sends the quote text to the share service',
        (tester) async {
      final share = _FakeShareService();
      await pumpApp(tester, share: share);

      await tester.tap(find.byTooltip('Share quote'));
      await tester.pumpAndSettle();

      expect(share.shared, ['"Only test quote." - Tester']);
    });

    testWidgets('a failed share shows a friendly message', (tester) async {
      await pumpApp(tester, share: _FakeShareService(fail: true));

      await tester.tap(find.byTooltip('Share quote'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Sharing is not available on this device'),
        findsOneWidget,
      );
    });
  });
}
