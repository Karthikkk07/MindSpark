import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/widgets/theme_mode_selector.dart';
import '../auth/auth_controller.dart';

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
        ],
      ),
    );
  }
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

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

    final name = session.user.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Text(name.isEmpty ? '?' : name[0].toUpperCase())),
          title: Text(name),
          subtitle: Text(session.user.email),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
