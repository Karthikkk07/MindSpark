import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/user_prefs_controller.dart';
import '../../models/quote.dart';
import '../quotes/quote_providers.dart';
import 'reminder_messages.dart';
import 'reminder_service.dart';

/// Keeps the phone's daily alarm in step with the reminder settings: on
/// startup, when the switch, time or interests change, and when quotes load.
final reminderSyncProvider = Provider<void>((ref) {
  var generation = 0;

  Future<void> reconcile() async {
    final mine = ++generation;
    final service = ref.read(reminderServiceProvider);
    final prefs = ref.read(userPrefsProvider);

    if (!prefs.reminderEnabled) {
      await service.cancel();
      return;
    }
    // Without permission nothing is scheduled; Settings explains why.
    if (!await service.notificationsAllowed()) return;
    if (mine != generation || !ref.mounted) return;

    final quotes = ref.read(allQuotesProvider).value ?? const <Quote>[];
    await service.schedule(
      hour: prefs.reminderHour,
      minute: prefs.reminderMinute,
      messages: reminderMessages(quotes, prefs.interests),
    );
  }

  ref.listen(
    userPrefsProvider.select(
      (p) => (
        p.reminderEnabled,
        p.reminderHour,
        p.reminderMinute,
        (p.interests.toList()..sort()).join(','),
      ),
    ),
    (previous, next) => unawaited(reconcile()),
    fireImmediately: true,
  );
  ref.listen(allQuotesProvider, (previous, next) => unawaited(reconcile()));
});
