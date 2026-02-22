import 'package:flutter/foundation.dart';
import '../models/movie.dart';
import '../services/db_service.dart';

class MovieProvider extends ChangeNotifier {
  List<Movie> movies = [];
  bool isLoading = false;
  int _currentPage = 0;
  final int _limit = 20;

  String currentCategory = 'movies';
  List<int> currentFavoriteIds = [];

  // Вызывается из ProxyProvider при изменении избранного
  void updateFavorites(List<int> favIds) {
    if (listEquals(currentFavoriteIds, favIds)) return;

    currentFavoriteIds = List.from(favIds);
    // Если мы находимся на вкладке Избранное, обновляем список на лету
    if (currentCategory == 'favorites') {
      Future.microtask(() => _reloadCurrentCategory());
    }
  }

  Future<void> setCategory(String category) async {
    if (currentCategory == category) return;
    currentCategory = category;
    await _reloadCurrentCategory();
  }

  Future<void> _reloadCurrentCategory() async {
    movies.clear();
    _currentPage = 0;
    notifyListeners(); // Очищаем экран
    await loadMoreMovies();
  }

  Future<void> loadMoreMovies() async {
    if (isLoading) return;

    isLoading = true;
    Future.microtask(() => notifyListeners());
    try {
      final newMovies = await DbService.instance.getMovies(
        limit: _limit,
        offset: _currentPage * _limit,
        category: currentCategory,
        favoriteIds: currentFavoriteIds,
      );
      if (newMovies.isNotEmpty) {
        movies.addAll(newMovies);
        _currentPage++;
      }
    } catch (e) {
      debugPrint('Error loading movies: \$e');
    } finally {
      isLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

  Future<void> initDbAndLoad() async {
    isLoading = true;
    notifyListeners();
    try {
      await DbService.instance.init();
      isLoading = false; // Сбрасываем флаг, чтобы loadMoreMovies() отработал
      await loadMoreMovies();
    } catch (e) {
      debugPrint('Error: \$e');
      isLoading = false;
      notifyListeners();
    }
  }
}
