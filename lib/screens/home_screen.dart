import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/movie_provider.dart';
import 'package:flutter/services.dart';
import '../widgets/movie_card.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  String _appVersion = '';
  late final MovieProvider _movieProvider;

  Future<void> _initAppVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'v${info.version} (build ${info.buildNumber})';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _movieProvider = context.read<MovieProvider>();
    _initAppVersion();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performStartupUpdate();
    });
  }

  /// Слушатель вызывается на каждый кадр прокрутки, а зона в 200 px на коротком
  /// списке — это почти весь его хвост. Провайдер берём из поля, а не через
  /// context.read на каждый тик, и выходим по дешёвым флагам до обращения к
  /// position.
  void _onScroll() {
    if (!_movieProvider.hasMore || _movieProvider.isLoading) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _movieProvider.loadMoreMovies();
    }
  }

  Future<void> _performStartupUpdate() async {
    await _movieProvider.initDbAndLoad();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildMenuButton(
    BuildContext context,
    String title,
    String category,
    String activeCategory,
  ) {
    return _MenuButton(
      title: title,
      isActive: activeCategory == category,
      onTap: () {
        context.read<MovieProvider>().setCategory(category);
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      },
    );
  }

  /// Год и список жанров не меняются между открытиями диалога — держим их
  /// статикой, чтобы не пересобирать ~66 DropdownMenuItem на каждый
  /// setDialogState прямо во время анимации открытия.
  static final List<int> _allYears = () {
    final int currentYear = DateTime.now().year;
    return List<int>.generate(currentYear - 1959, (i) => currentYear - i);
  }();

  static const List<String> _allGenres = [
    'боевик',
    'комедия',
    'драма',
    'фантастика',
    'триллер',
    'ужасы',
    'мелодрама',
    'детектив',
    'приключения',
    'фэнтези',
    'криминал',
    'семейный',
  ];

  void _resetScroll() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  /// Смена фильтра меняет длину списка, а позиция скролла остаётся прежней.
  /// Без сброса ScrollPosition после короткого результата приходится
  /// корректировать себя самому — на ТВ это выглядит как рывок сетки.
  void _toggleTorrentFilter(MovieProvider provider) {
    _resetScroll();
    provider.toggleTorrentFilter();
  }

  Future<void> _showYearFilterDialog(
    BuildContext context,
    MovieProvider provider,
  ) async {
    int? exactYear = provider.filterYearExact;
    int? startYear = provider.filterYearStart;
    int? endYear = provider.filterYearEnd;
    bool isRange =
        provider.filterYearStart != null ||
        provider.filterYearEnd != null ||
        (provider.filterYearExact == null &&
            (provider.filterYearStart != null ||
                provider.filterYearEnd != null));
    // Also treat as range if toggle was previously in range mode
    if (provider.filterYearStart != null || provider.filterYearEnd != null) {
      isRange = true;
    }

    final result = await showDialog<_YearFilterResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Years available for "До": must be >= startYear+1 (if startYear set)
          final List<int> toYears = startYear != null
              ? _allYears.where((y) => y > startYear!).toList()
              : _allYears;
          // Years available for "От": must be <= endYear-1 (if endYear set)
          final List<int> fromYears = endYear != null
              ? _allYears.where((y) => y < endYear!).toList()
              : _allYears;

          Widget _buildYearDropdown({
            required String label,
            required int? value,
            required List<int> years,
            required void Function(int?) onChanged,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: DropdownButton<int?>(
                    value: value,
                    hint: const Text(
                      '—',
                      style: TextStyle(color: Colors.white54),
                    ),
                    dropdownColor: const Color(0xFF2A2A2A),
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    iconEnabledColor: Colors.white54,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          '—',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                      ...years.map(
                        (y) =>
                            DropdownMenuItem<int?>(value: y, child: Text('$y')),
                      ),
                    ],
                    onChanged: onChanged,
                  ),
                ),
              ],
            );
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF222222),
            title: const Text(
              'Фильтр по году',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Выбрать период',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: isRange,
                    activeColor: Colors.red,
                    onChanged: (val) {
                      setDialogState(() {
                        isRange = val;
                        if (val) {
                          exactYear = null;
                        } else {
                          startYear = null;
                          endYear = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (!isRange)
                    _buildYearDropdown(
                      label: 'Год',
                      value: exactYear,
                      years: _allYears,
                      onChanged: (val) => setDialogState(() => exactYear = val),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _buildYearDropdown(
                            label: 'От',
                            value: startYear,
                            years: fromYears,
                            onChanged: (val) {
                              setDialogState(() {
                                startYear = val;
                                // If endYear is now invalid, clear it
                                if (val != null &&
                                    endYear != null &&
                                    endYear! <= val) {
                                  endYear = null;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildYearDropdown(
                            label: 'До',
                            value: endYear,
                            years: toYears,
                            onChanged: (val) {
                              setDialogState(() {
                                endYear = val;
                                // If startYear is now invalid, clear it
                                if (val != null &&
                                    startYear != null &&
                                    startYear! >= val) {
                                  startYear = null;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // Диалог только возвращает выбор. Фильтр применяется после того,
            // как showDialog завершится — см. ниже.
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  const _YearFilterResult(null, null, null),
                ),
                child: const Text(
                  'Сбросить',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  isRange
                      ? _YearFilterResult(null, startYear, endYear)
                      : _YearFilterResult(exactYear, null, null),
                ),
                child: const Text(
                  'Применить',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Раньше setYearFilter вызывался прямо в onPressed, до Navigator.pop:
    // перезагрузка списка (очистка + запрос + постройка сотни карточек)
    // приходилась ровно на анимацию закрытия диалога и рвала её. Future от
    // showDialog завершается уже после того, как анимация отыграла.
    if (!mounted || result == null) return;
    _resetScroll();
    provider.setYearFilter(result.exact, result.start, result.end);
  }

  Future<void> _showGenreFilterDialog(
    BuildContext context,
    MovieProvider provider,
  ) async {
    List<String> selectedGenres = List.from(provider.filterGenres);
    bool exclude = provider.filterExcludeGenres;

    final result = await showDialog<_GenreFilterResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF222222),
            title: const Text(
              'Фильтр по жанрам',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text(
                      exclude ? 'Исключить выбранные' : 'Содержат выбранные',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    value: exclude,
                    activeColor: Colors.red,
                    onChanged: (val) => setDialogState(() => exclude = val),
                  ),
                  const Divider(color: Colors.grey),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _allGenres.length,
                      itemBuilder: (context, index) {
                        final genre = _allGenres[index];
                        return CheckboxListTile(
                          title: Text(
                            genre,
                            style: const TextStyle(color: Colors.white),
                          ),
                          value: selectedGenres.contains(genre),
                          activeColor: Colors.red,
                          checkColor: Colors.white,
                          onChanged: (bool? checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selectedGenres.add(genre);
                              } else {
                                selectedGenres.remove(genre);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  const _GenreFilterResult(<String>[], false),
                ),
                child: const Text(
                  'Сбросить',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  _GenreFilterResult(selectedGenres, exclude),
                ),
                child: const Text(
                  'Применить',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Применяем после закрытия диалога — см. комментарий в _showYearFilterDialog.
    if (!mounted || result == null) return;
    _resetScroll();
    provider.setGenreFilter(result.genres, result.exclude);
  }

  Widget _buildSidebar(BuildContext context, bool isTvLayout) {
    return Container(
      width: 220,
      color: Colors.black87,
      // Selector, а не Consumer: сайдбару нужна только активная категория.
      // С Consumer он пересобирался на каждую подгруженную страницу и на
      // каждое изменение избранного.
      child: Selector<MovieProvider, String>(
        selector: (_, provider) => provider.currentCategory,
        builder: (context, activeCategory, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.all(isTvLayout ? 16.0 : 24.0),
                child: Text(
                  'TV Media',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isTvLayout ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: isTvLayout ? 10 : 30),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMenuButton(
                        context,
                        'Сейчас смотрят',
                        'now_playing',
                        activeCategory,
                      ),
                      _buildMenuButton(
                        context,
                        'Фильмы',
                        'movies',
                        activeCategory,
                      ),
                      _buildMenuButton(
                        context,
                        'Мультфильмы',
                        'cartoons',
                        activeCategory,
                      ),
                      _buildMenuButton(
                        context,
                        'Сериалы',
                        'series',
                        activeCategory,
                      ),
                      _buildMenuButton(
                        context,
                        'Избранное',
                        'favorites',
                        activeCategory,
                      ),
                      const SizedBox(height: 20),
                      _MenuButton(
                        title: 'Поиск',
                        isActive: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SearchScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuButton(
                        title: 'Обновить БД',
                        isActive: false,
                        onTap: _performStartupUpdate,
                      ),
                    ],
                  ),
                ),
              ),
              if (_appVersion.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _appVersion,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, bool isTvLayout) {
    return Consumer<MovieProvider>(
      builder: (context, provider, child) {
        // Раньше здесь стоял ранний return со спиннером — он подменял собой всю
        // колонку, поэтому при каждой смене категории панель фильтров исчезала
        // и появлялась заново. Панель остаётся на месте, меняется только
        // содержимое области контента.
        return Column(
          children: [
            Container(
              height: isTvLayout ? 48 : 60,
              color: Colors.black45,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Чекбокс для торрентов — фокус идёт прямо на Checkbox
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: provider.filterOnlyTorrents,
                        onChanged: (_) => _toggleTorrentFilter(provider),
                        activeColor: Colors.red,
                        focusColor: Colors.white30,
                      ),
                      GestureDetector(
                        onTap: () => _toggleTorrentFilter(provider),
                        child: Text(
                          'Только с торрентами',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isTvLayout ? 14 : 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Кнопка фильтра по году
                  _FilterButton(
                    title: () {
                      if (provider.filterYearExact != null) {
                        return 'Год: ${provider.filterYearExact}';
                      }
                      if (provider.filterYearStart != null &&
                          provider.filterYearEnd != null) {
                        return 'с ${provider.filterYearStart} по ${provider.filterYearEnd}';
                      }
                      if (provider.filterYearStart != null) {
                        return 'с ${provider.filterYearStart}';
                      }
                      if (provider.filterYearEnd != null) {
                        return 'по ${provider.filterYearEnd}';
                      }
                      return 'Год: Все';
                    }(),
                    isActive:
                        provider.filterYearExact != null ||
                        provider.filterYearStart != null ||
                        provider.filterYearEnd != null,
                    isTvLayout: isTvLayout,
                    onTap: () => _showYearFilterDialog(context, provider),
                  ),
                  const SizedBox(width: 8),
                  // Кнопка фильтра по жанру
                  _FilterButton(
                    title:
                        'Жанры: ' +
                        (provider.filterGenres.isEmpty
                            ? 'Все'
                            : (provider.filterExcludeGenres
                                  ? 'Исключая (${provider.filterGenres.length})'
                                  : 'Включая (${provider.filterGenres.length})')),
                    isActive: provider.filterGenres.isNotEmpty,
                    isTvLayout: isTvLayout,
                    onTap: () => _showGenreFilterDialog(context, provider),
                  ),
                ],
              ),
            ),

            Expanded(child: _buildGrid(context, provider)),

            // Индикатор подгрузки вынесен из сетки. Пока он был отдельной
            // ячейкой (itemCount + 1), появление и исчезновение сдвигало все
            // карточки и меняло номер последнего ряда — сфокусированная
            // карточка внезапно становилась «крайней» и дёргала скролл.
            // Высота полосы постоянна, поэтому геометрия сетки не меняется.
            SizedBox(
              height: 2,
              child: provider.isLoading && provider.movies.isNotEmpty
                  ? const LinearProgressIndicator(
                      minHeight: 2,
                      color: Colors.red,
                      backgroundColor: Colors.transparent,
                    )
                  : null,
            ),
            if (isTvLayout)
              Container(height: 4, color: const Color(0xFF141414)),
          ],
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context, MovieProvider provider) {
    if (provider.movies.isEmpty) {
      if (provider.isLoading) return const _DelayedLoader();
      return const Center(
        child: Text(
          'Нет контента.',
          style: TextStyle(fontSize: 18, color: Colors.white54),
        ),
      );
    }

    final double maxExtent = MediaQuery.of(context).size.width < 600
        ? 180
        : 150;

    // Ни LayoutBuilder, ни ручного подсчёта колонок здесь больше нет.
    // Прежняя формула `(maxWidth + 10) ~/ (maxExtent + 10)` не совпадала с
    // тем, что реально делает SliverGridDelegateWithMaxCrossAxisExtent
    // (`ceil(crossAxisExtent / (maxExtent + spacing))`, причём от ширины уже
    // за вычетом padding). При сайдбаре 220 на экране 960 это давало 4 колонки
    // вместо 5 — то есть «первый» и «последний» ряд вычислялись не для тех
    // карточек, и доводка скролла срабатывала в неожиданных местах.
    return GridView.builder(
      controller: _scrollController,
      // Высота ячейки ≈ maxExtent / 0.67. Прежние 500 давали всего два ряда
      // упреждения — при удержании кнопки пульта сетка уезжала быстрее, чем
      // успевали декодироваться постеры.
      cacheExtent: 1200,
      padding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: 40.0,
      ),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxExtent,
        childAspectRatio: 0.67,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: provider.movies.length,
      itemBuilder: (context, index) {
        final movie = provider.movies[index];
        return MovieCard(key: ValueKey(movie.id), movie: movie);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktopOrTv = MediaQuery.of(context).size.width >= 600;
    final bool isTvLayout = MediaQuery.of(context).size.height < 600;

    // Selector вместо Consumer: пересобирать сайдбар и всё тело экрана на
    // каждый тик прогресса скачивания БД (а их сотни) незачем.
    return Selector<MovieProvider, bool>(
      selector: (_, provider) => provider.isUpdatingDb,
      builder: (context, isUpdatingDb, child) {
        if (isUpdatingDb) {
          return const _DbUpdateScreen();
        }

        return Scaffold(
          backgroundColor: const Color(0xFF141414),
          appBar: !isDesktopOrTv
              ? AppBar(
                  backgroundColor: Colors.black87,
                  title: const Text(
                    'TV Media',
                    style: TextStyle(color: Colors.white),
                  ),
                  iconTheme: const IconThemeData(color: Colors.white),
                )
              : null,
          drawer: !isDesktopOrTv
              ? Drawer(
                  backgroundColor: Colors.black87,
                  child: _buildSidebar(context, isTvLayout),
                )
              : null,
          body: isDesktopOrTv
              ? Row(
                  children: [
                    _buildSidebar(context, isTvLayout),
                    Expanded(child: _buildMainContent(context, isTvLayout)),
                  ],
                )
              : _buildMainContent(context, isTvLayout),
        );
      },
    );
  }
}

/// Экран прогресса скачивания БД. Вынесен отдельно, чтобы Consumer слушал
/// только статус и прогресс, не задевая остальное дерево.
class _YearFilterResult {
  final int? exact;
  final int? start;
  final int? end;

  const _YearFilterResult(this.exact, this.start, this.end);
}

class _GenreFilterResult {
  final List<String> genres;
  final bool exclude;

  const _GenreFilterResult(this.genres, this.exclude);
}

/// Спиннер, который появляется только если загрузка затянулась.
///
/// Запрос к локальной SQLite обычно укладывается в десятки миллисекунд, и
/// безусловный индикатор успевал лишь мигнуть — при каждом применении фильтра
/// экран вспыхивал спиннером на пару кадров. Виджет живёт ровно столько,
/// сколько длится загрузка (при isLoading == false он удаляется из дерева),
/// поэтому таймер каждый раз начинается заново.
class _DelayedLoader extends StatefulWidget {
  const _DelayedLoader();

  @override
  State<_DelayedLoader> createState() => _DelayedLoaderState();
}

class _DelayedLoaderState extends State<_DelayedLoader> {
  static const Duration _delay = Duration(milliseconds: 250);

  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.expand();
    return const Center(child: CircularProgressIndicator(color: Colors.red));
  }
}

class _DbUpdateScreen extends StatelessWidget {
  const _DbUpdateScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Center(
        child: Consumer<MovieProvider>(
          builder: (context, provider, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.red),
                const SizedBox(height: 24),
                Text(
                  provider.updateStatus,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                if (provider.updateProgress != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 300,
                    child: LinearProgressIndicator(
                      value: provider.updateProgress,
                      color: Colors.red,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _MenuButton({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isTvLayout = MediaQuery.of(context).size.height < 600;
    final double vPadding = isTvLayout ? 12.0 : 16.0;
    final double hPadding = isTvLayout ? 16.0 : 24.0;
    final double fontSize = isTvLayout ? 14.0 : 16.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            vertical: vPadding,
            horizontal: hPadding,
          ),
          decoration: BoxDecoration(
            color: widget.isActive
                ? Colors.red.withValues(alpha: 0.8)
                : (_isFocused ? Colors.white12 : Colors.transparent),
            border: Border(
              left: BorderSide(
                color: widget.isActive ? Colors.white : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: widget.isActive ? FontWeight.bold : FontWeight.w500,
              color: widget.isActive || _isFocused
                  ? Colors.white
                  : Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatefulWidget {
  final String title;
  final bool isActive;
  final bool isTvLayout;
  final VoidCallback onTap;

  const _FilterButton({
    super.key,
    required this.title,
    required this.isActive,
    required this.isTvLayout,
    required this.onTap,
  });

  @override
  State<_FilterButton> createState() => _FilterButtonState();
}

class _FilterButtonState extends State<_FilterButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    // Локальный Material — см. комментарий в MovieCard.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: widget.isTvLayout ? 28 : 36,
          padding: EdgeInsets.symmetric(
            horizontal: widget.isTvLayout ? 12 : 16,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isFocused
                ? Colors.white24
                : (widget.isActive
                      ? Colors.red.withValues(alpha: 0.3)
                      : Colors.transparent),
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : (widget.isActive ? Colors.red : Colors.grey[800]!),
              width: _isFocused ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.isTvLayout ? 12 : 14,
              fontWeight: widget.isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
