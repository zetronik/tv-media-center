import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesProvider extends ChangeNotifier {
  List<int> _favoriteIds = [];
  List<int> get favoriteIds => _favoriteIds;

  FavoritesProvider() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? favs = prefs.getStringList('favorites_movies');
    if (favs != null) {
      _favoriteIds = favs.map((id) => int.parse(id)).toList();
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(int id) async {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final List<String> stringFavs = _favoriteIds
        .map((id) => id.toString())
        .toList();
    await prefs.setStringList('favorites_movies', stringFavs);
  }

  bool isFavorite(int id) {
    return _favoriteIds.contains(id);
  }
}
