/// Route paths used across the app.
class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const library = '/library';
  static const favorites = '/favorites';
  static const goals = '/goals';
  static const settings = '/settings';
  static const auth = '/auth';
  static const quoteDetail = '/quote/:id';
  static const goalNew = '/goal/new';
  static const goalDetail = '/goal/:id';
  static const goalEdit = '/goal/:id/edit';

  static String quotePath(String id) => '/quote/${Uri.encodeComponent(id)}';
  static String goalPath(String id) => '/goal/${Uri.encodeComponent(id)}';
  static String goalEditPath(String id) =>
      '/goal/${Uri.encodeComponent(id)}/edit';
}
