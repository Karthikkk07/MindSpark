import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/widgets/root_messenger.dart';
import 'features/widget/widget_sync.dart';
import 'features/quotes/quote_providers.dart';

class MindSparkApp extends ConsumerWidget {
  const MindSparkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    // Keeps the Android home-screen widget's quotes up to date.
    ref.watch(widgetSyncProvider);
    // Downloads the latest quotes in the background.
    ref.watch(quoteRefreshProvider);

    return MaterialApp.router(
      title: 'MindSpark',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
    scaffoldMessengerKey: ref.watch(rootMessengerKeyProvider),
      routerConfig: router,
    );
  }
}
