import 'package:flutter/foundation.dart';
import '../models/movie.dart';
import '../services/db_service.dart';

class MovieProvider extends ChangeNotifier {
  List<Movie> movies = [];
  bool isLoading = false;

  bool isUpdatingDb = false;
  double? updateProgress;
  String updateStatus = '';

  int _currentPage = 0;
  final int _limit = 20;

  String currentCategory = 'movies';
  List<int> currentFavoriteIds = [];
  Map<String, int>? dbStats;

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

  Future<bool> initDbAndLoad() async {
    isUpdatingDb = true;
    updateStatus = 'Начало обновления...';
    updateProgress = 0.0;
    notifyListeners();

    bool updatedSuccessfully = false;

    try {
      await DbService.instance.updateDatabase(
        onProgress: (status, progress) {
          updateStatus = status;
          updateProgress = progress;
          notifyListeners();
        },
      );
      updatedSuccessfully = true;
    } catch (e) {
      debugPrint('Update failed: \$e, falling back to local DB');
      try {
        await DbService.instance.init();
      } catch (innerE) {
        debugPrint('Local DB init also failed: \$innerE');
      }
    }

    try {
      dbStats = await DbService.instance.getDbStats();
      movies.clear();
      _currentPage = 0;
      await loadMoreMovies();
    } catch (e) {
      debugPrint('Error loading movies after init: \$e');
    } finally {
      isUpdatingDb = false;
      notifyListeners();
    }

    return updatedSuccessfully;
  }
}
