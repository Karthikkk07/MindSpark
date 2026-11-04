import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/widget_service.dart';
import '../../core/prefs/user_prefs_controller.dart';
import '../quotes/quote_pool.dart';
import '../quotes/quote_providers.dart';

/// Keeps the home-screen widget's quotes in sync with the user's interests.
final widgetSyncProvider = FutureProvider<void>((ref) async {
  final interests =
      ref.watch(userPrefsProvider.select((prefs) => prefs.interests));
  final all = await ref.watch(allQuotesProvider.future);
  try {
    await ref
        .read(widgetServiceProvider)
        .updateQuotes(quotesForInterests(all, interests));
  } catch (_) {
    // No widget support here (tests, other platforms): nothing to update.
  }
});
