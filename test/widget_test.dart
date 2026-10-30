import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindspark/app.dart';
import 'package:mindspark/features/settings/settings_screen.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: MindSparkApp()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts on Home with the navigation bar', (tester) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Sample quote'), findsOneWidget);
  });

  testWidgets('bottom navigation switches tabs', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Library'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Quote library'), findsOneWidget);
  });

  testWidgets('theme can be switched to dark in Settings', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SettingsScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
