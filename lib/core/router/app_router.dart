import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_screen.dart';
import '../../features/favorites/favorites_screen.dart';
import '../../features/goals/goal_detail_screen.dart';
import '../../features/goals/goal_edit_screen.dart';
import '../../features/goals/goals_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/quotes/library_screen.dart';
import '../../features/quotes/quote_detail_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../prefs/user_prefs_controller.dart';
import '../shell/main_shell.dart';
import 'app_routes.dart';

GoRouter createRouter({required bool Function() onboardingComplete}) {
  return GoRouter(
    initialLocation:
        onboardingComplete() ? AppRoutes.home : AppRoutes.onboarding,
    redirect: (context, state) {
      final location = state.matchedLocation;
      // New users start with onboarding, which may lead to the sign-in screen.
      if (!onboardingComplete() &&
          location != AppRoutes.onboarding &&
          location != AppRoutes.auth) {
        return AppRoutes.onboarding;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.library,
              builder: (context, state) => const LibraryScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.favorites,
              builder: (context, state) => const FavoritesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.goals,
              builder: (context, state) => const GoalsScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: AppRoutes.quoteDetail,
        builder: (context, state) =>
            QuoteDetailScreen(quoteId: state.pathParameters['id']!),
      ),
      // The fixed path must come before the :id path.
      GoRoute(
        path: AppRoutes.goalNew,
        builder: (context, state) => const GoalEditScreen(),
      ),
      GoRoute(
        path: AppRoutes.goalDetail,
        builder: (context, state) =>
            GoalDetailScreen(goalId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.goalEdit,
        builder: (context, state) =>
            GoalEditScreen(goalId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthScreen(),
      ),
    ],
  );
}

/// One router per ProviderScope, so tests start from a clean state.
final routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter(
    onboardingComplete: () => ref.read(userPrefsProvider).onboardingComplete,
  );
  ref.onDispose(router.dispose);
  return router;
});
