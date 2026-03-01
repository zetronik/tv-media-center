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
  final int _limit = 100;

  String currentCategory = 'movies';
  List<int> currentFavoriteIds = [];

  bool filterOnlyTorrents = false;
  int? filterYearExact;
  int? filterYearStart;
  int? filterYearEnd;
  List<String> filterGenres = [];
  bool filterExcludeGenres = false;

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

  void toggleTorrentFilter() {
    filterOnlyTorrents = !filterOnlyTorrents;
    _reloadCurrentCategory();
  }

  void setYearFilter(int? exact, int? start, int? end) {
    filterYearExact = exact;
    filterYearStart = start;
    filterYearEnd = end;
    _reloadCurrentCategory();
  }

  void setGenreFilter(List<String> genres, bool exclude) {
    filterGenres = genres;
    filterExcludeGenres = exclude;
    _reloadCurrentCategory();
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
        onlyWithTorrents: filterOnlyTorrents,
        yearExact: filterYearExact,
        yearStart: filterYearStart,
        yearEnd: filterYearEnd,
        genres: filterGenres,
        excludeGenres: filterExcludeGenres,
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

  Future<int> initDbAndLoad() async {
    isUpdatingDb = true;
    updateStatus = 'Начало обновления...';
    updateProgress = 0.0;
    notifyListeners();

    int updateResult = 0; // 0 - ошибка, 1 - обновлено, 2 - не требуется

    try {
      updateResult = await DbService.instance.updateDatabase(
        onProgress: (status, progress) {
          updateStatus = status;
          updateProgress = progress;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Update failed: $e, falling back to local DB');
      try {
        await DbService.instance.init();
      } catch (innerE) {
        debugPrint('Local DB init also failed: $innerE');
      }
    }

    try {
      dbStats = await DbService.instance.getDbStats();
      movies.clear();
      _currentPage = 0;
      await loadMoreMovies();
    } catch (e) {
      debugPrint('Error loading movies after init: $e');
    } finally {
      isUpdatingDb = false;
      notifyListeners();
    }

    return updateResult;
  }
}
