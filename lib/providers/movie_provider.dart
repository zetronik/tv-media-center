import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/movie.dart';
import '../services/db_service.dart';

class MovieProvider extends ChangeNotifier {
  List<Movie> movies = [];
  bool isLoading = false;
  bool hasMore = true;

  bool isUpdatingDb = false;
  double? updateProgress;
  String updateStatus = '';

  int _currentPage = 0;
  final int _limit = 100;

  bool _disposed = false;

  /// Увеличивается при каждой смене категории или фильтра. Ответ БД, пришедший
  /// со старым токеном, отбрасывается: без этого быстрое переключение вкладок
  /// пультом домешивает в список фильмы предыдущей категории.
  int _requestToken = 0;

  String currentCategory = 'now_playing';
  List<int> currentFavoriteIds = [];

  bool filterOnlyTorrents = false;
  int? filterYearExact;
  int? filterYearStart;
  int? filterYearEnd;
  List<String> filterGenres = [];
  bool filterExcludeGenres = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// notifyListeners(), безопасный для вызова из фазы build/layout.
  ///
  /// Раньше здесь был безусловный `Future.microtask`, из-за которого состояние
  /// и слушатели расходились: `movies` уже очищен, а GridView ещё считает
  /// itemCount по старой длине. Уведомляем синхронно, а откладываем только
  /// когда мы действительно внутри кадра.
  void _notify() {
    if (_disposed) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  // Вызывается из ProxyProvider при изменении избранного
  void updateFavorites(List<int> favIds) {
    if (listEquals(currentFavoriteIds, favIds)) return;

    currentFavoriteIds = List.of(favIds);
    // Если мы находимся на вкладке Избранное, обновляем список на лету
    if (currentCategory == 'favorites') {
      _reloadCurrentCategory();
    }
  }

  Future<void> setCategory(String category) async {
    if (currentCategory == category) return;
    currentCategory = category;

    // Сбрасываем фильтры при смене категории
    filterOnlyTorrents = false;
    filterYearExact = null;
    filterYearStart = null;
    filterYearEnd = null;
    filterGenres = [];
    filterExcludeGenres = false;

    await _reloadCurrentCategory();
  }

  Future<void> _reloadCurrentCategory() async {
    _requestToken++;
    final int token = _requestToken;

    movies = const <Movie>[];
    _currentPage = 0;
    hasMore = true;
    // isLoading выставляем ДО уведомления, иначе между очисткой списка и
    // началом загрузки успевает отрисоваться кадр с «Нет контента».
    isLoading = true;
    _notify();

    await _fetchPage(token);
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
    if (isLoading || !hasMore) return;

    isLoading = true;
    _notify();
    await _fetchPage(_requestToken);
  }

  Future<void> _fetchPage(int token) async {
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

      // Категория/фильтр сменились, пока шёл запрос — результат уже не наш.
      if (token != _requestToken || _disposed) return;

      if (newMovies.isEmpty) {
        hasMore = false; // Данных больше нет
      } else {
        // Заменяем ссылку целиком, а не мутируем список, который прямо сейчас
        // читает GridView.
        movies = [...movies, ...newMovies];
        _currentPage++;
        if (newMovies.length < _limit) {
          hasMore = false; // Достигли конца списка
        }
      }
    } catch (e) {
      debugPrint('Error loading movies: $e');
      if (token == _requestToken) hasMore = false;
    } finally {
      if (token == _requestToken && !_disposed) {
        isLoading = false;
        _notify();
      }
    }
  }

  Future<int> initDbAndLoad() async {
    isUpdatingDb = true;
    updateStatus = 'Начало обновления...';
    updateProgress = 0.0;
    _notify();

    int updateResult = 0; // 0 - ошибка, 1 - обновлено, 2 - не требуется

    try {
      updateResult = await DbService.instance.updateDatabase(
        onProgress: (status, progress) {
          // Частота вызовов ограничена в DbService; здесь отсекаем повторы,
          // которые ничего не меняют на экране.
          if (updateStatus == status && updateProgress == progress) return;
          updateStatus = status;
          updateProgress = progress;
          _notify();
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
      // Список наполняется до снятия isUpdatingDb, чтобы экран прогресса
      // сменился сразу готовой сеткой, а не пустым состоянием.
      await _reloadCurrentCategory();
    } catch (e) {
      debugPrint('Error loading movies after init: $e');
    } finally {
      isUpdatingDb = false;
      _notify();
    }

    return updateResult;
  }
}
