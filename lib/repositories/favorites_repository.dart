import 'package:shared_preferences/shared_preferences.dart';

/// Stores the ids of favourite quotes, newest first.
class FavoritesRepository {
  FavoritesRepository(this._prefs);

  final SharedPreferences _prefs;

  static const keyFavoriteIds = 'favorite_ids';

  List<String> load() {
    final stored = _prefs.getStringList(keyFavoriteIds) ?? const <String>[];
    // A set removes duplicates while keeping the stored order.
    return {...stored}.toList();
  }

  Future<void> save(List<String> ids) =>
      _prefs.setStringList(keyFavoriteIds, ids);
}
