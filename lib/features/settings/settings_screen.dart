import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/prefs/user_prefs_controller.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/theme_mode_selector.dart';
import '../auth/auth_controller.dart';
import '../push/push_registration.dart';
import '../quotes/quote_providers.dart';
import '../reminders/reminder_messages.dart';
import '../reminders/reminder_service.dart';
import '../sync/sync_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Account', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const _AccountSection(),
          const SizedBox(height: 32),
          Text('Appearance', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const ThemeModeSelector(),
          const SizedBox(height: 32),
          Text('Daily reminder', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const _ReminderSection(),
          const SizedBox(height: 32),
          Text('Push notifications', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const _PushSection(),
          const SizedBox(height: 32),
          Text('Privacy', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const _PrivacySection(),
        ],
      ),
    );
  }
}

class _PushSection extends ConsumerStatefulWidget {
  const _PushSection();

  @override
  ConsumerState<_PushSection> createState() => _PushSectionState();
}

class _PushSectionState extends ConsumerState<_PushSection> {
  String? _problem;
  bool _busy = false;

  Future<void> _toggle(bool on) async {
    final registration = ref.read(pushRegistrationProvider);
    setState(() {
      _busy = true;
      _problem = null;
    });
    String? problem;
    if (on) {
      switch (await registration.enable()) {
        case PushEnableResult.enabled:
          break;
        case PushEnableResult.notSignedIn:
          problem = 'Sign in to get push notifications.';
        case PushEnableResult.permissionDenied:
          problem = 'Notifications are blocked for MindSpark. '
              'Allow them in system settings.';
        case PushEnableResult.unavailable:
          problem = 'Push notifications are not available right now.';
      }
    } else {
      await registration.disable();
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _problem = problem;
      });
    }
  }

  Future<void> _sendTest({int delaySeconds = 0}) async {
    final messenger = ScaffoldMessenger.of(context);
    final sent = await ref
        .read(pushRegistrationProvider)
        .sendTest(delaySeconds: delaySeconds);
    final text = switch (sent) {
      null => 'Could not reach the server. Try again in a moment.',
      0 => 'No device is registered yet. Try again in a few seconds.',
      _ when delaySeconds > 0 =>
        'Push scheduled. Press Home now: it arrives in $delaySeconds seconds.',
      _ => 'Test push sent. It appears in the app while it is open.',
    };
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signedIn = ref.watch(currentSessionProvider) != null;
    final enabled = ref.watch(userPrefsProvider.select((p) => p.pushEnabled));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Push notifications'),
          subtitle: Text(
            signedIn
                ? 'Occasional motivation and news from MindSpark'
                : 'Sign in to turn this on',
          ),
          value: enabled && signedIn,
          onChanged: signedIn && !_busy ? _toggle : null,
        ),
        if (_problem != null)
          Text(
            _problem!,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
          ),
        if (enabled && signedIn) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _sendTest,
            child: const Text('Send a test push'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _sendTest(delaySeconds: 10),
            child: const Text('Send in 10 seconds (leave the app)'),
          ),
        ],
      ],
    );
  }
}

class _PrivacySection extends ConsumerWidget {
  const _PrivacySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final enabled = ref.watch(userPrefsProvider.select((p) => p.analyticsEnabled));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Share usage and crash reports'),
          subtitle: const Text('Anonymous. Helps us find and fix problems.'),
          value: enabled,
          onChanged: (on) =>
              ref.read(userPrefsProvider.notifier).setAnalyticsEnabled(on),
        ),
        Text(
          'Reports never include your goals, quotes, name or email. '
          'Nothing is sent unless you turn this on.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ReminderSection extends ConsumerStatefulWidget {
  const _ReminderSection();

  @override
  ConsumerState<_ReminderSection> createState() => _ReminderSectionState();
}

class _ReminderSectionState extends ConsumerState<_ReminderSection>
    with WidgetsBindingObserver {
  /// Whether notifications can be shown; null until checked.
  bool? _allowed;

  /// The user tried to switch reminders on but the permission was refused.
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from system settings: check again.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final allowed = await ref.read(reminderServiceProvider).notificationsAllowed();
    if (mounted) setState(() => _allowed = allowed);
  }

  Future<void> _toggle(bool on) async {
    final prefsController = ref.read(userPrefsProvider.notifier);
    if (!on) {
      setState(() => _denied = false);
      await prefsController.setReminderEnabled(false);
      return;
    }
    final service = ref.read(reminderServiceProvider);
    var allowed = await service.notificationsAllowed();
    if (!allowed) allowed = await service.requestPermission();
    if (!mounted) return;
    setState(() {
      _allowed = allowed;
      _denied = !allowed;
    });
    if (allowed) await prefsController.setReminderEnabled(true);
  }

  Future<void> _pickTime() async {
    final prefs = ref.read(userPrefsProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: prefs.reminderHour, minute: prefs.reminderMinute),
    );
    if (picked != null) {
      await ref.read(userPrefsProvider.notifier).setReminderTime(picked);
    }
  }

  Future<void> _sendTest() async {
    final prefs = ref.read(userPrefsProvider);
    final quotes = ref.read(allQuotesProvider).value ?? const [];
    final messages = reminderMessages(quotes, prefs.interests);
    await ref.read(reminderServiceProvider).showNow(
          messages.isEmpty ? 'Your daily motivation is ready.' : messages.first,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = ref.watch(userPrefsProvider);
    final blocked = _allowed == false && (prefs.reminderEnabled || _denied);
    final time = TimeOfDay(hour: prefs.reminderHour, minute: prefs.reminderMinute);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Remind me every day'),
          subtitle: const Text('A motivational quote at the time you choose'),
          value: prefs.reminderEnabled,
          onChanged: _toggle,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: prefs.reminderEnabled,
          leading: const Icon(Icons.schedule),
          title: const Text('Reminder time'),
          trailing: Text(time.format(context), style: theme.textTheme.titleMedium),
          onTap: prefs.reminderEnabled ? _pickTime : null,
        ),
        if (blocked) ...[
          const SizedBox(height: 8),
          Text(
            'Notifications are blocked for MindSpark, so reminders cannot appear. '
            'Allow them in system settings.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
          ),
          TextButton(
            onPressed: () => ref.read(reminderServiceProvider).openNotificationSettings(),
            child: const Text('Open settings'),
          ),
        ],
        if (_allowed == true) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _sendTest,
            child: const Text('Send a test reminder'),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Reminders can arrive a few minutes late when your phone is saving battery.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  static String _syncLabel(BuildContext context, SyncStatus sync) {
    switch (sync.phase) {
      case SyncPhase.syncing:
        return 'Syncing...';
      case SyncPhase.failed:
        return sync.message ?? 'Sync failed. Try again later.';
      case SyncPhase.synced:
        final at = sync.lastSyncedAt;
        return at == null
            ? 'Synced'
            : 'Synced at ${TimeOfDay.fromDateTime(at).format(context)}';
      case SyncPhase.idle:
        return 'Not synced yet';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(currentSessionProvider);

    if (session == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You are using MindSpark as a guest. Your data stays on this device.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => context.push(AppRoutes.auth),
            child: const Text('Sign in or create an account'),
          ),
        ],
      );
    }

    final sync = ref.watch(syncControllerProvider);
    final name = session.user.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
          ),
          title: Text(name),
          subtitle: Text(session.user.email),
        ),
        Text(
          _syncLabel(context, sync),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
              child: const Text('Sign out'),
            ),
            TextButton(
              onPressed: sync.phase == SyncPhase.syncing
                  ? null
                  : () => ref.read(syncControllerProvider.notifier).syncNow(),
              child: const Text('Sync now'),
            ),
          ],
        ),
      ],
    );
  }
}
