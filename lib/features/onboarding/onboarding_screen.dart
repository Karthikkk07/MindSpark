import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/prefs/user_prefs_controller.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/theme_mode_selector.dart';
import '../../models/quote_category.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _pageCount = 5;

  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    await ref.read(userPrefsProvider.notifier).completeOnboarding();
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) => setState(() => _page = index),
                children: [
                  const _WelcomePage(),
                  const _InterestsPage(),
                  const _LookPage(),
                  const _ReminderPage(),
                  _StartPage(onGuest: _finish),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 88,
                    child: _page > 0
                        ? TextButton(
                            onPressed: () => _goTo(_page - 1),
                            child: const Text('Back'),
                          )
                        : null,
                  ),
                  Expanded(child: _Dots(count: _pageCount, index: _page)),
                  SizedBox(
                    width: 88,
                    child: isLast
                        ? null
                        : FilledButton(
                            onPressed: () => _goTo(_page + 1),
                            child: const Text('Next'),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (child != null) ...[
            const SizedBox(height: 24),
            child!,
          ],
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return const _PageFrame(
      icon: Icons.auto_awesome,
      title: 'Welcome to MindSpark',
      subtitle: 'A little motivation each day, shaped around what matters '
          'to you. It takes under a minute to set up.',
    );
  }
}

class _InterestsPage extends ConsumerWidget {
  const _InterestsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interests =
        ref.watch(userPrefsProvider.select((prefs) => prefs.interests));
    final notifier = ref.read(userPrefsProvider.notifier);

    return _PageFrame(
      icon: Icons.interests_outlined,
      title: 'What are you into?',
      subtitle: 'Pick any that fit. Quotes on Home will favour these.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final category in QuoteCategory.values)
            FilterChip(
              label: Text(category.label),
              selected: interests.contains(category.id),
              onSelected: (_) => notifier.toggleInterest(category.id),
            ),
        ],
      ),
    );
  }
}

class _LookPage extends StatelessWidget {
  const _LookPage();

  @override
  Widget build(BuildContext context) {
    return const _PageFrame(
      icon: Icons.palette_outlined,
      title: 'Pick your look',
      subtitle: 'Follow your phone, or choose light or dark.',
      child: ThemeModeSelector(),
    );
  }
}

class _ReminderPage extends ConsumerWidget {
  const _ReminderPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(userPrefsProvider);
    final notifier = ref.read(userPrefsProvider.notifier);

    return _PageFrame(
      icon: Icons.notifications_none,
      title: 'A gentle daily nudge',
      subtitle: 'Choose a time and MindSpark will remind you once a day. '
          'We ask for notification permission only when reminders are '
          'turned on, and you can switch them off at any time.',
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Daily reminder'),
            value: prefs.reminderEnabled,
            onChanged: notifier.setReminderEnabled,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: prefs.reminderEnabled,
            leading: const Icon(Icons.schedule),
            title: const Text('Time'),
            trailing: Text(prefs.reminderTime.format(context)),
            onTap: prefs.reminderEnabled
                ? () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: prefs.reminderTime,
                    );
                    if (picked != null) await notifier.setReminderTime(picked);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _StartPage extends StatelessWidget {
  const _StartPage({required this.onGuest});

  final VoidCallback onGuest;

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      icon: Icons.rocket_launch_outlined,
      title: 'How would you like to start?',
      subtitle: 'You can use MindSpark right away as a guest. Accounts, for '
          'syncing across devices, are optional.',
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onGuest,
              child: const Text('Continue as guest'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push(AppRoutes.auth),
              child: const Text('Sign in or create an account'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Step ${index + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final active = i == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}
