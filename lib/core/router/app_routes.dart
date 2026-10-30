/// Route paths used across the app.
class AppRoutes {
  AppRoutes._();

  static const onboarding = '/onboarding';
  static const home = '/home';
  static const library = '/library';
  static const favorites = '/favorites';
  static const goals = '/goals';
  static const settings = '/settings';
  static const quoteDetail = '/quote/:id';

  static String quotePath(String id) => '/quote/${Uri.encodeComponent(id)}';
}
